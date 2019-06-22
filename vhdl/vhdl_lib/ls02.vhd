
LIBRARY ieee;
USE ieee.std_logic_1164.ALL;

ENTITY ls02 IS
    GENERIC (
        t_rise : TIME := 10 ns;
        t_fall : TIME := 10 ns
    );
    PORT(
        dA, dB : IN std_logic;
        q : OUT std_logic
    );
END ls02;

ARCHITECTURE behav OF ls02 IS
BEGIN
    PROCESS(dA, dB)
    BEGIN
        IF dA = '1' or dB = '1' THEN
            q <= '0' AFTER t_fall;
        ELSE
            q <= '1' AFTER t_rise;
        END IF;
    END PROCESS;
END behav;