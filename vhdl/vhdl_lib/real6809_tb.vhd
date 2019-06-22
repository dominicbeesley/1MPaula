----------------------------------------------------------------------------------
-- Company: 			Dossytronics
-- Engineer: 			Dominic Beesley
-- 
-- Create Date:    	23/3/2018
-- Design Name: 
-- Module Name:    	simulation file for a "real" 6502
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 		uses T65 core
--
-- Dependencies: 
--
-- Revision: 
-- Revision 0.01 - File Created
-- Additional Comments: 
-- simulate phi0, phi1, phi2 timings and 6502A pinout at 2MHz
----------------------------------------------------------------------------------
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY real_6809_tb IS
	GENERIC (
			dly_addr  : time := 70 ns; -- faster than spec!
			dly_dout  : time := 70 ns; -- data delay from Q rise
			dly_dhold : time := 20 ns
		);
	PORT (
		A					: OUT 		STD_LOGIC_VECTOR(15 downto 0);
		D					: INOUT 	STD_LOGIC_VECTOR(7 downto 0);
		nRESET				: IN		STD_LOGIC;
		TSC					: IN		STD_LOGIC;
		nHALT				: IN		STD_LOGIC;
		nIRQ				: IN		STD_LOGIC;
		nNMI				: IN		STD_LOGIC;
		nFIRQ				: IN		STD_LOGIC;
		AVMA				: OUT		STD_LOGIC;
		RnW					: OUT		STD_LOGIC;
		LIC					: OUT		STD_LOGIC;

		CLK_E				: IN		STD_LOGIC;
		CLK_Q				: IN		STD_LOGIC;
		BA					: OUT		STD_LOGIC;
		BS					: OUT		STD_LOGIC;
		BUSY				: OUT		STD_LOGIC
		);
END real_6809_tb;

ARCHITECTURE Behavioral OF real_6809_tb IS

	SIGNAL	i_cpu_clk		: STD_LOGIC;

	SIGNAL  i_RnW			: STD_LOGIC;
	SIGNAL	i_cpu_A			: STD_LOGIC_VECTOR(15 downto 0);
	SIGNAL  i_LIC			: STD_LOGIC;
	SIGNAL	i_BA			: STD_LOGIC;
	SIGNAL	i_BS			: STD_LOGIC;

	SIGNAL	i_cpu_D_out		: STD_LOGIC_VECTOR(7 downto 0);
	SIGNAL	i_cpu_D_in		: STD_LOGIC_VECTOR(7 downto 0);
	SIGNAL	i_RnW_hold		: STD_LOGIC;

	SIGNAL	i_irq			: STD_LOGIC;
	SIGNAL	i_firq			: STD_LOGIC;
	SIGNAL	i_nmi			: STD_LOGIC;
	SIGNAL	i_vma			: STD_LOGIC;
	SIGNAL	i_halt			: STD_LOGIC;

	SIGNAL  i_data_write	: STD_LOGIC;
	SIGNAL	i_RESET			: STD_LOGIC;
BEGIN

	p_data_Write:process
	BEGIN
		wait until CLK_Q = '1';
		i_data_write <= '1';
		wait until CLK_E = '0';
		wait for dly_dhold;
		i_data_write <= '0';

	END PROCESS;

	i_irq <= not(nIRQ);
	i_firq <= not(nFIRQ);
	i_nmi <= not(nNMI);
	i_halt <= not(nHALT);
	i_reset <= not(nRESET);

	i_cpu_clk <= not(CLK_E);

	i_RnW_hold <= i_RnW AFTER dly_addr;
	RnW <= i_RnW_hold;
	A <= i_cpu_A AFTER dly_addr;
	LIC <= i_LIC AFTER dly_addr;
	BA <= i_BA AFTER dly_addr;
	BS <= i_BS AFTER dly_addr;

	AVMA <= i_VMA;
	BUSY <= 'X';	-- dunno what to do with this so make it X for now?

	D <= i_cpu_D_out AFTER dly_dhold when i_data_write = '1' and i_RnW_hold = '0' else
		 (others => 'Z');

	i_cpu_D_in <= D;

	e_cpu: entity work.cpu09 port map (
		clk			=> i_cpu_clk,
		rst			=> i_RESET,
		vma			=> i_vma,
		lic_out		=> i_lic,
		ifetch		=> open,
		opfetch		=> open,
		ba			=> i_ba,
		bs			=> i_bs,
		addr		=> i_cpu_A,
		rw			=> i_RnW,
		data_out	=> i_cpu_D_out,
		data_in		=> i_cpu_D_in,
		irq			=> i_irq,
		firq		=> i_firq,
		nmi			=> i_nmi,
		halt		=> i_halt,
		hold		=> '0'
	);

END Behavioral;
