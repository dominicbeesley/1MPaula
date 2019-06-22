----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    11:31:45 05/27/2019 
-- Design Name: 
-- Module Name:    dac_mcp4822 - Behavioral 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 	 4822 12 bit spi DAC - mono
--
-- Dependencies: 
--
-- Revision: 
-- Revision 0.01 - File Created
-- Additional Comments: 
--		- clock in is 128M
--		- data in is signed mono 9 bits
--		- both A/B channels are set				
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity dac_mcp4822 is
generic (
	SIM				: boolean := false	
);
port (

	rst_i				: in std_logic;
	clk_i				: in std_logic;

	dat_i				: in signed(9 downto 0);
	dat_clken_i		: in std_logic;

   dac_cs_n     	: out   std_logic;
   dac_sck      	: out   std_logic;
   dac_sdi      	: out   std_logic;
   dac_ldac_n   	: out   std_logic

	);
end dac_mcp4822;

architecture Behavioral of dac_mcp4822 is
	type state_t is (s_idle, s_csA, s_dataA, s_csA_off, s_csB, s_dataB, s_cs_Boff, s_ldac, s_done);

	signal r_state 		: state_t;
	signal r_data  		: signed(9 downto 0);
	signal r_shift 		: std_logic_vector(14 downto 0);
	signal r_shift_dn		: std_logic_vector(15 downto 0);		
	signal r_data_pend	: std_logic;

	signal r_clk16 		: std_logic; -- divide clock down to 16MHz
	signal r_clkdiv		: unsigned(2 downto 0) := (others => '0');

begin

	p_clkdiv: process(clk_i, rst_i)
	begin
		if rst_i = '1' then
			r_clkdiv <= (others => '0');
		elsif rising_edge(clk_i) then
			r_clkdiv <= r_clkdiv + 1;
		end if;
	end process;

	dac_sck <= r_clkdiv(2); -- 16 mhz spi clock


	p_pend:process (clk_i, rst_i)	
	begin
		if rst_i = '1' then
			r_data_pend <= '0';
		elsif rising_edge(clk_i) then
			if dat_clken_i = '1' then
				r_data_pend <= '1';
			elsif r_state = s_idle then
				r_data_pend <= '0';
			end if;
		end if;
	end process;


	p_spi: process (clk_i, rst_i)
	begin
		if rst_i ='1' then
			r_state <= s_idle;
			dac_sdi <= '1';
			dac_ldac_n <= '1';
		elsif rising_edge(clk_i) then

			if r_state = s_idle and r_data_pend = '1' then
				r_data <= dat_i;
				r_state <= s_csA;
			elsif r_clkdiv = "111" then
				case r_state is
					when s_csA =>
						dac_sdi <= '0';
						dac_cs_n <= '0';
						r_shift <= "001" & not(r_data(9)) & std_logic_vector(r_data) & "0";
						r_shift_dn <= (0 => '1', others => '0');
						r_state <= s_dataA;
					when s_dataA =>
						dac_sdi <= r_shift(r_shift'high);
						r_shift <= r_shift(r_shift'high-1 downto 0) & "0";
						r_shift_dn <= r_shift_dn(r_shift_dn'high-1 downto 0) & "0";
						if r_shift_dn(r_shift_dn'high) = '1' then
							dac_cs_n <= '1';
							r_state <= s_csB;
						end if;
					when s_csB =>
						dac_sdi <= '1';
						dac_cs_n <= '0';
						r_shift <= "001" & not(r_data(9)) & std_logic_vector(r_data) & "0";
						r_shift_dn <= (0 => '1', others => '0');
						r_state <= s_dataB;
					when s_dataB =>
						dac_sdi <= r_shift(r_shift'high);
						r_shift <= r_shift(r_shift'high-1 downto 0) & "0";
						r_shift_dn <= r_shift_dn(r_shift_dn'high-1 downto 0) & "0";
						if r_shift_dn(r_shift_dn'high) = '1' then
							dac_cs_n <= '1';
							r_state <= s_ldac;
						end if;
					when s_ldac =>
						dac_ldac_n <= '0';
						r_state <= s_done;
					when s_done =>
						dac_ldac_n <= '1';
						r_state <= s_idle;
					when others =>
						r_state <= s_idle;
				end case;
			end if;
		end if;

	end process;


end Behavioral;

