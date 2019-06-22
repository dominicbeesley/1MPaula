-- Company: 			Dossytronics
-- Engineer: 			Dominic Beesley
-- 
-- Create Date:    	2/5/2019
-- Design Name: 
-- Module Name:    	detect a bbc slow cycle
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 		Combinatorial check for slow addresses
-- Dependencies: 
--
-- Revision: 
-- Additional Comments: 
--
----------------------------------------------------------------------------------



library IEEE;
use IEEE.std_logic_1164.all;

entity bbc_slow_cyc is
port (
		sys_A_i 				: in	std_logic_vector(15 downto 0);
		slow_o 				: out	std_logic
);
end bbc_slow_cyc;

architecture rtl of bbc_slow_cyc is

begin

	slow_o <= '1' when (
		sys_A_i(15 downto 8) = x"FC" or
		sys_A_i(15 downto 8) = x"FD" or
		(	sys_A_i(15 downto 8) = x"FE" and (
				sys_A_i(7 downto 4) = x"0" or -- CRTC/ACIA
				sys_A_i(7 downto 4) = x"1" or -- SERPROC/STATID -- TODO:CHECK
				sys_A_i(7 downto 4) = x"4" or -- SYS VIA
				sys_A_i(7 downto 4) = x"5" or -- SYS VIA
				sys_A_i(7 downto 4) = x"6" or -- USR VIA
				sys_A_i(7 downto 4) = x"7" or -- USR VIA
				sys_A_i(7 downto 4) = x"C" or -- ADC
				sys_A_i(7 downto 4) = x"D"	   -- ADC
			)
		)) else 
	'0';

end rtl;