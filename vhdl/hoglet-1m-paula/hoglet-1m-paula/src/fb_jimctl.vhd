-- Company: 			Dossytronics
-- Engineer: 			Dominic Beesley
-- 
-- Create Date:    	16/04/2019
-- Design Name: 
-- Module Name:    	fishbone bus - JIM control wrapper
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 		A fishbone wrapper for the JIM paging registers
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

entity fb_jimctl is
	generic (
		SIM									: boolean := false;								-- skip some stuff, i.e. slow sdram start up	
		G_JIM_DEVNO							: std_logic_vector(7 downto 0) := x"D0"	-- jim FCFF enable value
	);
	port(

		-- jim control						
		JIM_page_o							: out		std_logic_vector(15 downto 0);
		JIM_en_o								: out		std_logic;

		-- fishbone signals

		fb_syscon_i							: in		fb_syscon_t;
		fb_m2s_i								: in		fb_mas_o_sla_i_t;
		fb_s2m_o								: out		fb_mas_i_sla_o_t

	);
end fb_jimctl;

architecture rtl of fb_jimctl is

	type 	 	state_mem_t is (idle, act, nul);

	signal	state			: state_mem_t;

	signal	i_mas_ack	:	std_logic;
	signal	r_mas_rdy	:	std_logic;
	signal	r_mas_nul	:	std_logic;

	signal	r_jim_page	: 	std_logic_vector(15 downto 0);
	signal	r_jim_en		:  std_logic;

	signal clk : std_logic;
	signal rst : std_logic;

begin

	-- this may seem unnecessary but ISIM mucks up the state machines
	-- if the clock signal comes from a record.
	clk <= fb_syscon_i.clk;
	rst <= fb_syscon_i.rst;

	i_mas_ack <= fb_syscon_i.cpu_clks(FB_CPUCLKINDEX(fb_m2s_i.cyc_speed)).cpu_clken and r_mas_rdy;

	fb_s2m_o.rdy <= r_mas_rdy;
	fb_s2m_o.ack <= i_mas_ack;
	fb_s2m_o.nul <= r_mas_nul;

	JIM_page_o <= r_jim_page;
	JIM_en_o <= r_jim_en;

	p_state:process(clk, rst)
	begin

		if rst = '1' then
			state <= idle;
			r_jim_page <= (others => '0');
			r_jim_en <= '0';
			r_mas_rdy <= '0';
			r_mas_nul <= '0';
		else
			if rising_edge(clk) then
				case state is
					when idle =>
						r_mas_rdy <= '0';
						r_mas_nul <= '0';
						if (fb_m2s_i.cyc = '1' and fb_m2s_i.A_stb = '1') then
							if fb_m2s_i.we = '1' and fb_m2s_i.D_wr_stb = '1' then
								if fb_m2s_i.A(3 downto 0) = x"F" then
									if fb_m2s_i.D_wr = G_JIM_DEVNO then
										r_jim_en <= '1';
									else
										r_jim_en <= '0';
									end if;
									state <= act;
									r_mas_nul <= '0';
								elsif r_jim_en = '1' and fb_m2s_i.A(3 downto 0) = x"E" then
									r_jim_page(7 downto 0) <= fb_m2s_i.D_wr;
									state <= act;
									r_mas_nul <= '0';
								elsif r_jim_en = '1' and fb_m2s_i.A(3 downto 0) = x"D" then
									r_jim_page(15 downto 8) <= fb_m2s_i.D_wr;
									state <= act;
									r_mas_nul <= '0';
								else
									state <= nul;
									r_mas_nul <= '1';
								end if;									
								r_mas_rdy <= '1';
							elsif fb_m2s_i.we = '0' then
								if r_jim_en = '1' then
									state <= act;
									r_mas_rdy <= '1';
									r_mas_nul <= '0';

									if fb_m2s_i.A(3 downto 0) = x"D" then
										fb_s2m_o.D_rd <= r_jim_page(15 downto 8);
									elsif fb_m2s_i.A(3 downto 0) = x"E" then
										fb_s2m_o.D_rd <= r_jim_page(7 downto 0);
									elsif fb_m2s_i.A(3 downto 0) = x"F" then
						  				fb_s2m_o.D_rd <= G_JIM_DEVNO xor x"FF";
						  			end if;
								else
									state <= nul;
									r_mas_rdy <= '1';
									r_mas_nul <= '1';
								end if;
							end if;
						end if;
					when act|nul =>
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