
LIBRARY ieee;
USE ieee.std_logic_1164.ALL;

ENTITY ls04 IS
    GENERIC(
        t_rise : TIME := 20 ns;
        t_fall : TIME := 15 ns
    );
    PORT(
        d : IN std_logic;
        q : OUT std_logic
    );
END ls04;

ARCHITECTURE behav OF ls04 IS
BEGIN
    PROCESS(d)
    BEGIN
        IF d = '0' THEN
            q <= '1' AFTER t_rise;
        ELSE
            q <= '0' AFTER t_fall;
        END IF;
    END PROCESS;
END behav;