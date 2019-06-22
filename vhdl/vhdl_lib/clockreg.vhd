-- Company: 			Dossytronics
-- Engineer: 			Dominic Beesley
-- 
-- Create Date:    	2/5/2019
-- Design Name: 
-- Module Name:    	register signals into a new clock domain
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 		simple register based meta stability fixer
-- Dependencies: 
--
-- Revision: 
-- Additional Comments: 
--
----------------------------------------------------------------------------------


LIBRARY ieee;

USE ieee.std_logic_1164.all; 
use ieee.numeric_std.all;

LIBRARY work;

-- (c) Dominic Beesley 2019

entity clockreg is
	generic (
		G_DEPTH : positive := 1;
		G_WIDTH : positive := 1
	);
	port (
		clk_i	: in	std_logic;
		d_i	: in	std_logic_vector(G_WIDTH-1 downto 0);
		q_o	: out	std_logic_vector(G_WIDTH-1 downto 0)
	);
end;

architecture arch of clockreg is
type reg_arr is array(G_DEPTH-1 downto 0) of std_logic_vector(G_WIDTH-1 downto 0);
signal r : reg_arr;
begin
	
	q_o <= r(0);

	p:procesS(clk_i)
	begin
		if rising_edge(clk_i) then
			r(G_DEPTH-1) <= d_i;
			if G_DEPTH > 1 then
				for I in G_DEPTH-1 downto 1 loop
					r(I - 1) <= r(I);				
				end loop;
			end if;
		end if;
	end process;

end;