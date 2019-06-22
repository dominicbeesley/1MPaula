----------------------------------------------------------------------------------
-- Company: 			Dossytronics
-- Engineer: 			Dominic Beesley
-- 
-- Create Date:    	12/7/2017 
-- Design Name: 
-- Module Name:    	ROM_TB 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 		Behavioral only model of 27512 with data for testbench
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

entity ROM_tb is
	Generic (
		delay_addr_to_data	: time := 200 ns;
		delay_enable_to_loZ	: time := 75 ns;
		delay_enable_to_hiZ	: time := 55 ns;
		romfile					: string;
		size						: natural	:= 4096
	);
	port (
		A				: in		std_logic_vector(15 downto 0);
		D				: inout	std_logic_vector(7 downto 0);
		nCS			: in		std_logic;
		nOE			: in		std_logic
	);
		
end ROM_tb;

architecture Behavioral of ROM_tb is
	signal	i_A_DLY			: std_logic_vector(15 downto 0);
	signal	i_nCS_OE_dly	: std_logic;
	signal	i_nOE_dly		: std_logic;
	signal	i_D				: std_logic_vector(7 downto 0);
	
	type		ramtype			is array(0 to size) of std_logic_vector(7 downto 0);
	signal	data				: ramtype;
begin

	p_init:process
		type char_file_t is file of character;
		file char_file : char_file_t;
		variable char_v : character;
		subtype byte_t is natural range 0 to 255;
		variable byte_v : byte_t;
		variable i : integer;
	begin
		i := 0;
		file_open(char_file, romfile );
		while not endfile(char_file) and i < size loop
			read(char_file, char_v);
			byte_v := character'pos(char_v);
			data(i) <= std_logic_vector(to_unsigned(byte_v, 8));
			i := i + 1;
--			report "Char: " & " #" & integer'image(byte_v);
		end loop;
		file_close(char_file);
		
		wait;
	end process;
	
	p_add2d: process(i_A_DLY)
	begin
		i_D <= data(to_integer(unsigned(i_A_DLY)) mod size);
	end process;
	
	D <= (others => 'Z') when i_nCS_OE_dly = '1' or i_nOE_dly = '1' else
			i_D;
			
	i_A_DLY <= A after delay_addr_to_data;
	i_nCS_OE_dly <= '1' after delay_enable_to_hiZ when nCS = '1' else '0' after delay_addr_to_data;
	i_nOE_dly <= '1' after delay_enable_to_hiZ when nOE = '1' else '0' after delay_enable_to_loZ;
		
end Behavioral;

