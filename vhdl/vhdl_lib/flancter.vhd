-- flancter http://ebook.pldworld.com/_Semiconductors/Xilinx/DataSource%20CD-ROM/Rev.6%20(Q1-2002)/xcell_archives/xl37/xcell37_54.pdf
-- XCell Journal 37, Q3 2000

LIBRARY ieee;

USE ieee.std_logic_1164.all; 
use ieee.numeric_std.all;

LIBRARY work;

-- (c) Dominic Beesley 2014

entity flancter is
	generic (
		REGISTER_OUT: BOOLEAN := FALSE
	);
	port (
		rst_i_async	: in std_logic;
		
		set_i_ck		: in std_logic;
		set_i			: in std_logic;
		
		rst_i_ck		: in std_logic;
		rst_i			: in std_logic;
		
		flag_out		: out std_logic
	);
end;

architecture arch of flancter is
	signal rst_flop : std_logic;
	signal set_flop : std_logic;
begin
	
	s: process (rst_i_async, set_i_ck)
	begin
		if rst_i_async = '1' then
			set_flop <= '0';
		elsif rising_edge(set_i_ck) then
			if set_i = '1' then
				set_flop <= not rst_flop;
			end if;
		end if;
	end process;

	r: process (rst_i_async, rst_i_ck)
	begin
		if rst_i_async = '1' then
			rst_flop <= '0';
		elsif rising_edge(rst_i_ck) then
			if rst_i = '1' then
				rst_flop <= set_flop;
			end if;
		end if;
	end process;

	reg_on: if REGISTER_OUT generate
		p_reg:process 
		begin
			wait until rising_edge(rst_i_ck);
			flag_out <= set_flop xor rst_flop;
		end process;
	end generate;
	
	reg_off: if not REGISTER_OUT generate
		flag_out <= set_flop xor rst_flop;
	end generate;
	
end;