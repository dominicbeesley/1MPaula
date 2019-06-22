



library IEEE;
use IEEE.std_logic_1164.all;

entity bbc_clk_gen is
port (
    clk_16_i        : in    std_logic;
    clk_8_o         : out   std_logic;
    clk_4_o         : out   std_logic;
    clk_2_o         : out   std_logic;
    clk_1_o         : out   std_logic;
    
    bbc_SLOW_i      : in    std_logic;      -- slow address detected i.e. pin 8 of IC23
    bbc_phi1_i      : in    std_logic;

    bbc_1MHzE_o     : out   std_logic;
    bbc_ROMSEL_clk_o: out   std_logic;
    bbc_phi0_o      : out   std_logic
);
end bbc_clk_gen;

architecture rtl of bbc_clk_gen is
    signal r_clk_8      : std_logic := '0';
    signal r_clk_4      : std_logic := '0';
    signal r_clk_2      : std_logic := '0';
    signal r_clk_1      : std_logic := '0';
    signal i_bbc_1MHzE  : std_logic := '0';
    signal i_bbc_n1MHzE : std_logic := '0';
    signal i_IC30B_Q	: std_logic := '0';
    signal i_nSLOW      : std_logic := '0';
    signal i_IC31B_nQ   : std_logic := '0';
    signal i_IC34A_nQ   : std_logic := '0';
    signal i_IC29C_Q    : std_logic := '0';
    signal i_IC30A_Q    : std_logic := '0';
    signal i_phi0       : std_logic := '0';
    signal i_IC28A_Q      : std_logic;
begin

    p_clk_8:process(clk_16_i)
    begin
        if falling_edge(clk_16_i) then
            r_clk_8 <= not r_clk_8;
        end if;
    end process;

    p_clk_4:process(r_clk_8)
    begin
        if falling_edge(r_clk_8) then
            r_clk_4 <= not r_clk_4;
        end if;
    end process;

    p_clk_2:process(r_clk_4)
    begin
        if falling_edge(r_clk_4) then
            r_clk_2 <= not r_clk_2;
        end if;
    end process;

    p_clk_1:process(r_clk_2)
    begin
        if falling_edge(r_clk_2) then
            r_clk_1 <= not r_clk_1;
        end if;
    end process;
    
    clk_8_o <= r_clk_8;
    clk_4_o <= r_clk_4;
    clk_2_o <= r_clk_2;
    clk_1_o <= r_clk_1;
    
    e_IC34B:entity work.ls74
    port map (
        d => i_bbc_n1MHzE,
        pre => '1',
        clr => '1',
        clk => r_clk_2,
        q => i_bbc_1MHzE,
        nq=> i_bbc_n1MHzE
    );
    
    bbc_1MHzE_o <= i_bbc_1MHzE;

    e_IC30B:entity work.ls74
    port map (
        d => r_clk_2,
        pre => '1',
        clr => '1',
        clk => r_clk_8,
        q => i_IC30B_Q
    );

    e_IC33A:entity work.ls04
    port map (
        d => bbc_SLOW_i,
        q => i_nSLOW
        );

    e_IC31B:entity work.ls74
    port map (
        d => i_nSLOW,
        pre => i_IC34A_nQ,
        clr => '1',
        clk => i_bbc_1MHzE,
        nq => i_IC31B_nQ        
        );

    e_IC29C:entity work.ls32
    port map (
        dA => i_nSLOW,
        dB => i_IC31B_nQ,
        q => i_IC29C_Q
        );

    e_IC34A:entity work.ls74
    port map (
        d => i_IC29C_Q,
        pre => '1',
        clr => '1',
        clk => i_IC30A_Q,
        nq => i_IC34A_nQ                
        );

    e_IC30A:entity work.ls74
    port map (
        d => i_IC30B_Q,
        pre => '1',
        clr => i_IC28A_Q,
        clk => r_clk_8,
        q => i_IC30A_Q,
        nq => bbc_ROMSEL_clk_o               
        );

    e_IC29D:entity work.ls32
    port map (
        dA => i_IC34A_nQ,
        dB => i_IC30A_Q,
        q => i_phi0
        );

    bbc_phi0_o <= i_phi0;

    e_IC28:entity work.ls51
    port map (
        dA => i_bbc_1MHzE,
        dB => bbc_SLOW_i,
        dC => bbc_phi1_i,
        dD => '0',
        dE => '0',
        dF => '0',
        Q => i_IC28A_Q
        );

    
end rtl;

