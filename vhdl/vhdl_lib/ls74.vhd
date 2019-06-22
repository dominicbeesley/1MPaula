
LIBRARY ieee;
USE ieee.std_logic_1164.ALL;

ENTITY ls74 IS
    GENERIC (
        t_rise : TIME := 13 ns;
        t_fall : TIME := 25 ns;
        t_setup : TIME := 20 ns;
        t_width : TIME := 25 ns
    );
    PORT(
        d, clr, pre, clk : IN std_logic;
        q : OUT std_logic;
        nq: OUT std_logic
    );
END ls74;

ARCHITECTURE behav OF ls74 IS
BEGIN
    PROCESS(clk, clr, pre)
    BEGIN
        IF clr = '0' THEN
            q <= '0' AFTER t_fall;
            nQ <= '1' AFTER t_rise;
        ELSIF pre = '0' THEN
            q <= '1' AFTER t_rise;
            nQ <= '0' AFTER t_fall;
        ELSIF clk'EVENT AND clk = '1' THEN
            IF d = '1' THEN
                q <= '1' AFTER t_rise;
                nQ <= '0' AFTER t_fall;
            ELSE
                q <= '0' AFTER t_fall;
                nQ <= '1' AFTER t_rise;
            END IF;
        END IF;
    END PROCESS;

    -- process to check data setup time
    PROCESS(clk)
    BEGIN
        IF clk'EVENT AND clk = '1' THEN
            ASSERT d'LAST_EVENT > t_setup
            REPORT "D changed within setup time"
            SEVERITY ERROR;
        END IF;
    END PROCESS;
    
    -- process to check clock high pulse width
    PROCESS(clk)
    VARIABLE last_clk : TIME := 0 ns;
    BEGIN
        IF clk'EVENT AND clk = '0' THEN
            ASSERT NOW - last_clk > t_width
            REPORT "Clock pulse width too short"
            SEVERITY ERROR;
        ELSE
            last_clk := NOW;
        END IF;
    END PROCESS;
END behav;