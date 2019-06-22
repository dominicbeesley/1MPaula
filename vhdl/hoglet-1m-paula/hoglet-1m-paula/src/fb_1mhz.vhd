-- Company: 			Dossytronics
-- Engineer: 			Dominic Beesley
-- 
-- Create Date:    	20/05/2019
-- Design Name: 
-- Module Name:    	fishbone bus - 1MHz bus wrapper component
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 		A fishbone wrapper for the 1MHz bus - acting as a master
-- Dependencies: 
--
-- Revision: 
-- Additional Comments: 
--	The 1MHz bus has no way of signalling that data is not ready so this component
-- just blindly hopes that any request will be fulfilled in time (they should be)
-- and drops the request if it is not rdy/ack'd in time
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.fishbone.all;

entity fb_1mhz is
	generic (
		SIM									: boolean := false							-- skip some stuff, i.e. slow sdram start up
	);
	port(
		-- 1MHz bus
		BUS1M_D									: inout	std_logic_vector(7 downto 0);
		BUS1M_D_nOE								: out		std_logic;
		BUS1M_D_DIR								: out		std_logic;								
		BUS1M_A									: in		std_logic_vector(7 downto 0);
		BUS1M_nPGFC								: in		std_logic;
		BUS1M_nPGFD								: in		std_logic;
		BUS1M_RnW								: in 		std_logic;

		-- fishbone signals
		fb_syscon_i								: in	fb_syscon_t;
		fb_m2s_o									: out fb_mas_o_sla_i_t;
		fb_s2m_i									: in	fb_mas_i_sla_o_t;

		-- signals from other components
		jim_page									: in	std_logic_vector(15 downto 0);
		jim_en									: in 	std_logic

	);
end fb_1mhz;

architecture rtl of fb_1mhz is

	constant DDIR_RD	: std_logic := '1';
	constant DDIR_WR	: std_logic := '0';

	type state1m_t is (
		s_idle,
		s_write,				
		s_read_wait_1m,	
		s_read,		
		s_rd_done,		
		s_rd_holdA,			
		s_rd_holdB,
		s_rd_holdC,
		s_rd_holdD
	);

	signal r_state_1m			: state1m_t;

	type state_mas_t is (
		s_idle,
		s_read,
		s_read_wait_req,
		s_write
		);

	signal r_state_mas		: state_mas_t;

	signal r_phys_A 			: std_logic_vector(23 downto 0);

	signal r_data_rd_req		: std_logic;												-- signal from bus process to master process that data read is requested
	signal r_data_rd_valid	: std_logic;												-- signal from master process that data is ready
	signal r_data_rd_null	: std_logic;												-- signal from master process that no device responded
	signal r_data_rd			: std_logic_vector(7 downto 0);

	signal i_cpu_clk			: fb_cpu_clks_t;

	-- local copies of clock/reset from main bus
	signal clk 					: std_logic;
	signal rst 					: std_logic;
	signal i_sys_clken_E_st : std_logic;

	signal i_BUS1M_D_nOE : std_logic;
	signal i_BUS1M_D_DIR : std_logic;

begin

	BUS1M_D_nOE <= i_BUS1M_D_nOE;
	BUS1M_D_DIR <= i_BUS1M_D_DIR;

	-- this may seem unnecessary but ISIM mucks up the state machines
	-- if the clock signal comes from a record.
	clk <= fb_syscon_i.clk;
	rst <= fb_syscon_i.rst;
	i_sys_clken_E_st <= fb_syscon_i.sys_clken_E_st;

	i_cpu_clk <= fb_syscon_i.cpu_clks(FB_CPUCLKINDEX(MHZ_1));

	BUS1M_D <= 	r_data_rd when i_BUS1M_D_DIR = DDIR_RD else
					(others => 'Z');

	p_mas_state:process(rst, clk)
	begin
		if rst = '1' then
			r_data_rd <= (others => '0');
			r_data_rd_valid <= '0';
			r_data_rd_null <= '0';
			fb_m2s_o.cyc <= '0';
			fb_m2s_o.cyc_speed <= MHZ_8;
			fb_m2s_o.we <= '0';
			fb_m2s_o.A <= (others => '0');
			fb_m2s_o.A_stb <= '0';
			fb_m2s_o.D_wr_stb <= '0';
			r_state_mas <= s_idle;
		else 
			if rising_edge(clk) then
				case r_state_mas is
					when s_idle =>
						r_data_rd_valid <= '0';
						r_data_rd_null <= '0';
						fb_m2s_o.cyc <= '0';
						fb_m2s_o.A_stb <= '0';
						fb_m2s_o.D_wr_stb <= '0';

						if r_data_rd_req = '1' then
							fb_m2s_o.A <= r_phys_A;
							fb_m2s_o.we <= '0';
							fb_m2s_o.cyc <= '1';
							fb_m2s_o.A_stb <= '1';
							fb_m2s_o.cyc_speed <= MHZ_8;										-- faster access than we need but don't block the bus!
							r_state_mas <= s_read;
						elsif r_state_1m = s_write and i_cpu_clk.cpu_clken = '1' then
							fb_m2s_o.A <= r_phys_A;												-- write at end of cycle
							fb_m2s_o.we <= '1';
							fb_m2s_o.cyc <= '1';
							fb_m2s_o.A_stb <= '1';
							fb_m2s_o.cyc_speed <= MHZ_8;										-- faster access than we need but don't block the bus!
							fb_m2s_o.D_wr_stb <= '1';		
							fb_m2s_o.D_wr <= BUS1M_D;
							r_state_mas <= s_write;
						end if;
					when s_read =>
						if fb_s2m_i.ack = '1' then
							if fb_s2m_i.nul = '1' then
								r_data_rd_null <= '1';								
							else
								r_data_rd_valid <= '1';
								r_data_rd <= fb_s2m_i.D_rd;
							end if;
							r_state_mas <= s_read_wait_req;
							fb_m2s_o.cyc <= '0';
							fb_m2s_o.A_stb <= '0';
							fb_m2s_o.D_wr_stb <= '0';
						end if;
					when s_read_wait_req =>
						if r_data_rd_req = '0' then
							r_state_mas <= s_idle;
						end if;
					when s_write =>
						if fb_s2m_i.ack = '1' then
							r_state_mas <= s_idle;
						end if;					
					when others =>
						r_state_mas <= s_idle;
				end case;
			end if;
		end if;
	end process;	

	p_1m_state:process(rst, clk)
	variable v_match:boolean;
	begin
		if rst = '1' then
			r_state_1m <= s_idle;
			i_BUS1M_D_nOE <= '1';
			i_BUS1M_D_DIR <= DDIR_WR;
			r_data_rd_req <= '0';
			r_phys_A <= (others => '0');
		else
			if rising_edge(clk) then
				case r_state_1m is
					when s_idle =>
						i_BUS1M_D_nOE <= '1';											-- release bus
						i_BUS1M_D_DIR <= DDIR_WR;
						r_data_rd_req <= '0';										
						v_match := false;
						if i_sys_clken_E_st ='1' then
							if BUS1M_nPGFC = '0' then
								r_phys_A <= x"FFFC" & BUS1M_A;
								v_match := true;
							elsif BUS1M_nPGFD = '0' and jim_en = '1' then
								r_phys_A <= jim_page & BUS1M_A;
								v_match := true;
							end if;

							if v_match then
								if BUS1M_RnW = '0' then
									r_state_1m <= s_write;
									i_BUS1M_D_DIR <= DDIR_WR;
									i_BUS1M_D_nOE <= '0';
								else
									r_data_rd_req <= '1';
									r_state_1m <= s_read_wait_1m;
									i_BUS1M_D_DIR <= DDIR_RD;							-- don't enable buffer until data ready
								end if;
							end if;
						end if;
					when s_write =>
						--wait for end of cycle
						if i_cpu_clk.cpu_clken = '1' then
							r_state_1m <= s_idle;
						end if;
					when s_read_wait_1m =>
						if i_cpu_clk.cpu_clk_E = '1' then
							r_state_1m <= s_read;
						end if;
					when s_read =>
						--wait for end of cycle						
						if i_cpu_clk.cpu_clken = '1' then
							r_state_1m <= s_rd_holdA;
						elsif r_data_rd_valid = '1' then							-- wait for master process to indicate valid data
							r_data_rd_req <= '0';
							r_state_1m <= s_rd_done;
						elsif r_data_rd_null = '1' then
							r_state_1m <= s_idle;
						end if;
					when s_rd_done =>
						i_BUS1M_D_nOE <= '0';
						if i_cpu_clk.cpu_clken = '1' then
							r_state_1m <= s_rd_holdA;
						end if;
					when s_rd_holdA =>
						r_state_1m <= s_rd_holdB;
					when s_rd_holdB =>
						r_state_1m <= s_rd_holdC;
					when s_rd_holdC =>
						r_state_1m <= s_rd_holdD;
					when s_rd_holdD =>
						r_state_1m <= s_idle;
					when others =>
						null;
				end case;
			end if;
		end if;
	end process;


end rtl;
