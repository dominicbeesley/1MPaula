
LIBRARY ieee;
USE ieee.std_logic_1164.ALL;

ENTITY ls32 IS
    GENERIC(
        t_rise : TIME := 10 ns;
        t_fall : TIME := 10 ns
    );
    PORT(
        dA, dB : IN std_logic;
        q : OUT std_logic
    );
END ls32;

ARCHITECTURE behav OF ls32 IS
BEGIN
    PROCESS(dA, dB)
    BEGIN
        IF dA = '1' or dB = '1' THEN
            q <= '1' AFTER t_rise;
        ELSE
            q <= '0' AFTER t_fall;
        END IF;
    END PROCESS;
END behav;