-- Company: 			Dossytronics
-- Engineer: 			Dominic Beesley
-- 
-- Create Date:    	16/04/2019
-- Design Name: 
-- Module Name:    	fishbone bus - busmaster test
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 		A simple master that reads from incrementing addresses
--							with a preset delay between accesses
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
use work.mk2blit_pack.all;

entity fb_mastest is
	generic (
		SIM									: boolean := false;							-- skip some stuff, i.e. slow sdram start up
		CPUSPEED								: fb_cyc_speed_t := MHZ_16;
		ADDR_BASE							: std_logic_vector(23 downto 0) := x"FF0000";
		ADDR_INC								: std_logic_vector(23 downto 0) := x"000001";
		PAUSE									: natural := 500;
		BURST									: natural := 3
	);
	port(
		-- fishbone signals
		fb_syscon							: in	fb_syscon_t;
		fb_m2s_o								: out fb_mas_o_sla_i_t;
		fb_s2m_i								: in	fb_mas_i_sla_o_t
	);
end fb_mastest;

architecture rtl of fb_mastest is

	type state_t is (
		idle,
		s_waitack
		);

	signal r_state				: state_t;
	signal r_cyc				: std_logic;
	signal r_addr				: std_logic_vector(23 downto 0);
	signal i_addr_next		: std_logic_vector(23 downto 0);
	signal r_pause_ctr		: natural range 0 to PAUSE;
	signal r_burst_ctr		: natural range 0 to BURST;
begin

	i_addr_next <= std_logic_vector(unsigned(r_addr) + unsigned(ADDR_INC));

	p_state:process(fb_syscon)
	begin
		if fb_syscon.rst = '1' then
			r_cyc <= '0';
			r_addr <= ADDR_BASE;
			r_pause_ctr <= PAUSE;
			r_burst_ctr <= BURST;
			r_state <= idle;
		else
			if rising_edge(fb_syscon.clk) then
				case r_state is
					when s_waitack =>
						-- normal cycle, wait for ack from / rdy from slave
						if fb_s2m_i.ack = '1' then
							if r_burst_ctr = 0 then
								r_state <= idle;
								r_cyc <= '0';
								r_pause_ctr <= PAUSE;
							else
								r_burst_ctr <= r_burst_ctr - 1;
							end if;
							r_addr <= i_addr_next;
						end if;
					when idle =>
						if r_pause_ctr = 0 then
							r_burst_ctr <= burst;
							r_state <= s_waitack;
							r_cyc <= '1';
						else
							r_pause_ctr <= r_pause_ctr - 1;
						end if;
					when others =>
						r_state <= r_state;

				end case;
			end if;
		end if;
	end process;

  	fb_m2s_o.cyc <= r_cyc;
  	fb_m2s_o.we <= '0';
  	fb_m2s_o.A <= r_addr;
  	fb_m2s_o.A_stb <= r_cyc;
  	fb_m2s_o.D_wr <= (others => '0');
  	fb_m2s_o.D_wr_stb <= '0';
  	fb_m2s_o.cyc_speed <= CPUSPEED;



end rtl;
