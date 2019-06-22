library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;


entity div_clock is
	 generic (
		cycles					: integer
	 )	; 
    Port ( 
		clk_in					: in  STD_LOGIC;
		clk_in_en				: in  STD_LOGIC := '1';
		clk_out_en				: out STD_LOGIC;
		n_reset					: in  STD_LOGIC
			  );
end div_clock;

architecture behavioral of div_clock is 
	signal	counter : integer range 0 to cycles - 1;
begin
	process (clk_in, clk_in_en, n_reset)
	begin
		if n_reset = '0' then
			clk_out_en <= '0';
			counter <= 0;
		elsif (rising_edge(clk_in)) then
			clk_out_en <= '0';
			if (clk_in_en = '1') then
				if (counter = cycles - 1) then
					counter <= 0;
					clk_out_en <= '1';
				else
					counter <= counter + 1;
				end if;
			end if;
		end if;
	end process;
end behavioral;
				