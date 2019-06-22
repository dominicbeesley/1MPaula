-- Company: 			Dossytronics
-- Engineer: 			Dominic Beesley
-- 
-- Create Date:    	16/04/2019
-- Design Name: 
-- Module Name:    	fishbone bus - MEM - memory wrapper
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 		A fishbone wrapper for the blitter/cpu board's SRAM
-- Dependencies: 
--
-- Revision: 
-- Additional Comments: 
--
----------------------------------------------------------------------------------


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.fishbone.all;

entity fb_mem is
	generic (
		SIM									: boolean := false							-- skip some stuff, i.e. slow sdram start up
	);
	port(


		-- 512K RAM bus
		MEM_A_o								: out		std_logic_vector(18 downto 0);
		MEM_D_io								: inout	std_logic_vector(7 downto 0);
		MEM_nOE_o							: out		std_logic;
		MEM_nWE_o							: out		std_logic;
		MEM_nCE_o							: out		std_logic;

		-- fishbone signals

		fb_syscon_i							: in		fb_syscon_t;
		fb_m2s_i								: in		fb_mas_o_sla_i_t;
		fb_s2m_o								: out		fb_mas_i_sla_o_t

	);
end fb_mem;

architecture rtl of fb_mem is

	type 	 	state_mem_t is (idle, wait1, wait2, wait3, wait4, wait5, act);

	signal	state			: state_mem_t;

	signal	i_mas_ack	:	std_logic;
	signal	i_mas_rdy	:	std_logic;

	signal	clk			: std_logic;
	signal	rst			: std_logic;

	signal 	i_MEM_nWE		: std_logic;
	signal 	i_MEM_nWE_dl	: std_logic;

	signal	r_d_wr			: std_logic_vector(7 downto 0);

begin

	MEM_nWE_o <= i_MEM_nWE;
	-- this may seem unnecessary but ISIM mucks up the state machines
	-- if the clock signal comes from a record.
	clk <= fb_syscon_i.clk;
	rst <= fb_syscon_i.rst;

	i_mas_ack <= fb_syscon_i.cpu_clks(FB_CPUCLKINDEX(fb_m2s_i.cyc_speed)).cpu_clken and i_mas_rdy;

	fb_s2m_o.rdy <= i_mas_rdy;
	fb_s2m_o.ack <= i_mas_ack when state = act else '0';
	fb_s2m_o.nul <= '0';	

	MEM_D_io <= r_d_wr when i_MEM_nWE = '0' or i_MEM_nWE_dl = '0' else (others => 'Z');

	p_state:process(clk, rst)
	begin

		if rst = '1' then
			state <= idle;
			MEM_A_o <= (others => '0');
			
			MEM_nOE_o <= '1';
			MEM_nCE_o <= '1';
			i_MEM_nWE <= '1';
			i_MEM_nWE_dl <= '1';
			i_mas_rdy <= '0';
		else
			if rising_edge(clk) then

				i_MEM_nWE_dl <= i_MEM_nWE;

				case state is
					when idle =>
						MEM_A_o <= (others => '0');
						MEM_nOE_o <= '1';
						MEM_nCE_o <= '1';
						i_MEM_nWE <= '1';
						i_mas_rdy <= '0';
						if fb_m2s_i.cyc = '1' and fb_m2s_i.A_stb = '1' then
							if fb_m2s_i.we = '1' and fb_m2s_i.D_wr_stb = '1' then
								MEM_A_o <= fb_m2s_i.A(18 downto 0);
								MEM_nCE_o <= '0';
								i_MEM_nWE <= '0';							
								state <= wait1;
								i_mas_rdy <= '1';
							elsif fb_m2s_i.we = '0' and fb_syscon_i.cpu_clks(FB_CPUCLKINDEX(fb_m2s_i.cyc_speed)).cpu_clk_E = '0' then
								MEM_A_o <= fb_m2s_i.A(18 downto 0);
								MEM_nCE_o <= '0';
								MEM_nOE_o <= '0';		
								state <= wait1;
							end if;
						end if;
					when wait1 =>
						r_d_wr <= fb_m2s_i.d_wr;
						state <= wait2;
					when wait2 =>
						state <= wait3;
					when wait3 =>
						state <= wait4;
					when wait4 =>
						state <= wait5;
					when wait5 =>
						state <= act;
						i_mas_rdy <= '1';
						fb_s2m_o.D_rd <= MEM_D_io;
					when act =>
						if fb_m2s_i.cyc = '0' then
							state <= idle;
						end if;
					when others =>
						state <= idle;
				end case;
			end if;
		end if;

	end process;


end rtl;