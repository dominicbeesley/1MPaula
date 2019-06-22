
LIBRARY ieee;
USE ieee.std_logic_1164.ALL;

ENTITY ls51 IS
    GENERIC (
        t_rise : TIME := 12 ns;
        t_fall : TIME := 12 ns
    );
    PORT(
        dA, dB, dC : IN std_logic := '1';
        dD, dE, dF : IN std_logic := '1';
        q : OUT std_logic
    );
END ls51;

ARCHITECTURE behav OF ls51 IS
BEGIN
    PROCESS(dA, dB, dC)
    BEGIN
        IF (dA = '1' and dB = '1' and dC = '1') or (dD = '1' and dE = '1' and dF = '1') THEN
            q <= '0' AFTER t_fall;
        ELSE
            q <= '1' AFTER t_rise;
        END IF;
    END PROCESS;
END behav;