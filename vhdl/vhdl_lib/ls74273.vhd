----------------------------------------------------------------------------------
-- Company: 			Dossytronics
-- Engineer: 			Dominic Beesley
-- 
-- Create Date:    	23/7/2017 
-- Design Name: 
-- Module Name:    	74xx239 behavioral 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 
--
-- Dependencies: 
--
-- Revision: 
-- Revision 0.01 - File Created
-- Additional Comments: 
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity LS74273 is
	Generic (
		tprop			: time	:= 27 ns		-- 7 ns for F
	);
	Port (
		D				: in		STD_LOGIC_VECTOR(7 downto 0);
		Q				: out		STD_LOGIC_VECTOR(7 downto 0);
		CP				: in		STD_LOGIC;
		MR				: in		STD_LOGIC
	);
end LS74273;

architecture Behavioral of LS74273 is		
begin

		p: process(D, CP, MR)
		begin
			if MR = '0' then
				Q <= (others => '0') after tprop;
			elsif rising_edge(CP) then
				Q <= D after tprop;
			end if;
		end process;
	
end Behavioral;

