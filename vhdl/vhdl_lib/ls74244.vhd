----------------------------------------------------------------------------------
-- Company: 			Dossytronics
-- Engineer: 			Dominic Beesley
-- 
-- Create Date:    	19/5/2019
-- Design Name: 
-- Module Name:    	74xx244 behavioral 
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

entity LS74244 is
	Generic (
		tprop			: time	:= 12 ns;
		toe			: time	:= 43 ns
	);
	Port (
		D				: in		STD_LOGIC_VECTOR(7 downto 0);
		Q				: out		STD_LOGIC_VECTOR(7 downto 0);
		nOE_A			: in		STD_LOGIC;
		nOE_B			: in		STD_LOGIC
	);
end LS74244;

architecture Behavioral of LS74244 is
	signal nOE_A_dly : std_logic;
	signal nOE_B_dly : std_logic;
begin

	nOE_A_dly <= nOE_A after toe;
	nOE_B_dly <= nOE_B after toe;

	Q <= to_stdlogicvector(to_bitvector(D)) after tprop when nOE_A_dly = '0' and  nOE_B_dly = '0' else (others => 'Z') after tprop;
	
	
end Behavioral;

