-- Company: 			Dossytronics
-- Engineer: 			Dominic Beesley
-- 
-- Create Date:    	16/04/2019
-- Design Name: 
-- Module Name:    	common.vhd
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 		blitter utility package
-- Dependencies: 
--
-- Revision: 
-- Additional Comments: 
--
----------------------------------------------------------------------------------
package common is
  function ceil_log2(i : natural) return natural;
end package;

library ieee;
use ieee.math_real.all;

package body common is
  function ceil_log2(i : natural) return natural is
  begin
    return integer(ceil(log2(real(i))));  -- Example using real calculation
  end function;
end package body;