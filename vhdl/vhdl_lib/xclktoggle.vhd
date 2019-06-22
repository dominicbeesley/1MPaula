-- http://sc.morganisms.net/2010/06/rtl-for-passing-pulse-across-clock-domains-in-vhdl/ 

library IEEE;
use IEEE.STD_LOGIC_1164.all;
-- Author:  Mike Morgan
--
-- Theory of operation:  This is a simple circuit to pass a
-- pulse synchronized to a source clock to a destination clock
-- domain using 1 T flip flop (TFF) and 3 D flip flops (DFFs).
--
-- The source pulse must be one source clock in duration and
-- the output pulse will be one destination clock in duration.   

-- This circuit is useful for passing 1 clock duration data
-- enables across clock domains.
--
-- Disclaimer:  This file is released to the public domain for
-- illustration purposes only.  Any use is at risk of the person
-- or company reusing the code.  Validation via simulation and
-- timing analysis based on target library and design parameters
-- is responsibility of company or person using this code.
--
-- Please see footnote 2 at  http://sc.morganisms.net/?p=226
-- regarding constraints on iPulseA timing
--
entity xclktoggle is -- Pulse Across clock domain
port(
  iPulseA  : IN   std_logic; -- 1 clock width pulse from source domain
  iClkA    : IN   std_logic; -- source clock domain
  iRSTAn   : IN   std_logic; -- active low reset
  iClkB    : IN   std_logic; -- destination clock domain
  iRSTBn   : IN   std_logic; -- active low reset
  oPulseB  : OUT  std_logic  -- 1 clock width pulse in destination domain
);
end xclktoggle;

architecture rtl of xclktoggle is
  signal t : std_logic;
  signal d : std_logic_vector(2 downto 0);
begin -- architecture

-- infer a T flip flop in source domain
T_PROCESS : process (iClkA,iRSTAn)
begin
  if(iRSTAn = '0') then
    t <= '0';
  elsif(rising_edge(iClkA)) then
   t <= t XOR iPulseA;
  end if;
end process T_PROCESS;

-- Feed T output to three D flip flops in destination clock
-- domain.  First two flip flops are to filter metastability
-- inherant in clock domain crossing of T, and the final D
-- flip flop is used to turn the output of the T flip flop
-- (now synchronized to the destination domain) into a pulse
-- in the destination clock domain.
D_PROCESS : process (iClkB,iRSTBn)
begin
  if(iRSTBn = '0') then
    d <= (others => '0');
  elsif(rising_edge(iClkB)) then
    d <= d(d'high -1 downto 0) & t;
  end if;
end process D_PROCESS;

-- create pulse every toggle using input and output
-- of last D flip flop.
oPulseB <= d(d'high) XOR d(d'high -1);

end rtl;