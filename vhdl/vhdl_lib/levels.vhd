----------------------------------------------------------------------------------
-- Company: 			Dossytronics
-- Engineer: 			Dominic Beesley
-- 
-- Create Date:    	13/7/2017 
-- Design Name: 
-- Module Name:    	74CBXX16211 behavioral 
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

entity LEVELS is
	Generic (
		tprop			: time	:= 1 ns;
		toe			: time	:= 4 ns
	);
	Port (
		A				: inout	STD_LOGIC_VECTOR(7 downto 0);
		B				: inout	STD_LOGIC_VECTOR(7 downto 0)
	);
end LEVELS;

architecture Behavioral of LEVELS is
		
begin

		p_a2b: process (A)
		begin
			for i in A'low to A'high loop
				if A(i) = '0' then
					B(i) <= '0';
				elsif A(i) = '1' then
					B(i) <= '1';
				else
					B(i) <= 'H';
				end if;
			end loop;
		end process;

		p_b2a: process (B)
		begin
			for i in B'low to B'high loop
				if B(i) = '0' then
					A(i) <= '0';
				elsif B(i) = '1' then
					A(i) <= '1';
				else
					A(i) <= 'H';
				end if;
			end loop;
		end process;
	
	
end Behavioral;

