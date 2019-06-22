LIBRARY ieee;
USE ieee.std_logic_1164.all; 
use ieee.numeric_std.all;

LIBRARY work;

entity RAM_WRAP is
	generic (
		SIM : BOOLEAN := FALSE
	);
	port
	(
			rst_a : in std_logic;
			rst_i	: in std_logic;
			clk_i : in std_logic;
			
			adr_i : in std_logic_vector (23 downto 0);
			dat_i : in std_logic_vector (7 downto 0);
			dat_o : out std_logic_vector (7 downto 0);
			we_n  : in std_logic;								-- active low, write ram at first rising edge
			oe_n	: in std_logic;								-- active low,	read ram at first falling edge
						
			SDRAM_DQ 		: inout std_logic_vector(15 downto 0);
			SDRAM_ADDR 		: out std_logic_vector(12 downto 0);
			SDRAM_DQM		: out std_logic_vector(1 downto 0);
			SDRAM_CLK		: out std_logic;
			SDRAM_CKE		: out std_logic;
			SDRAM_WE_N		: out std_logic;
			SDRAM_CAS_N		: out std_logic;
			SDRAM_RAS_N		: out std_logic;
			SDRAM_CS_N		: out std_logic;
			SDRAM_BA			: out std_logic_vector(1 downto 0);		
			clk_sdram		: in std_logic;
			
			sdram_reset		: out std_logic;								-- this stays set until end of SRAM reset sequence
			
			tst_start		: out std_logic;
			tst_act			: out std_logic
						
	);
end RAM_WRAP;

architecture arch of RAM_WRAP is
	signal	i_power_reset4	: std_logic				:= '1';			-- start power on reset sequence	
	signal	i_power_reset3	: std_logic				:= '1';			-- start power on reset sequence	
	signal	i_power_reset2	: std_logic				:= '1';			-- start power on reset sequence	
	signal	i_power_reset1	: std_logic				:= '1';			-- start power on reset sequence	
	
	signal	i_exec_wr 		: std_logic;
	signal 	i_exec_rd		: std_logic;
	
	signal	i_ram_q			: std_logic_vector(7 downto 0);
	signal	i_dat_i_pre		: std_logic_vector(7 downto 0);
	signal	i_adr_i_pre		: std_logic_vector(23 downto 0);
	
	signal	i_bus_ref		: std_logic;
	signal	i_oe				: std_logic;
	
begin

	SDRAM_CLK <= clk_sdram;
	SDRAM_CKE <= '1';
		
	p_reset: process(rst_a, i_power_reset1, i_power_reset2, i_power_reset3, clk_i)
	begin
		if (rst_a = '1') then
			i_power_reset1 <= '1';
			i_power_reset2 <= '1';
			i_power_reset3 <= '1';
			i_power_reset4 <= '1';
		elsif rising_edge(clk_i) then
			i_power_reset1 <= i_power_reset2;
			i_power_reset2 <= i_power_reset3;
			i_power_reset3 <= i_power_reset4;
			i_power_reset4 <= '0';
		end if;
	end process;
	
	i_exec_wr	<= not(we_n);
	i_exec_rd  	<= not(oe_n);
	dat_o <= i_ram_q;
		
--	p_delay_write_date:process
--	begin
--		wait until rising_edge(clk_i);
		i_dat_i_pre <= dat_i;
		i_adr_i_pre <= adr_i;
--	end process;
		
	i_bus_ref <= not(i_exec_rd or i_exec_wr);	
	
	-- if SIM then generate a sram_ctl that short-cuts the reset timer to save simulation time
	g: if SIM generate
		e_sdram: entity work.SDRAM_CTL 
		generic map (
			reset_count => 100,
			SIM => SIM
		)
		PORT MAP(
			DRAM_DQ 		=> SDRAM_DQ,
			DRAM_ADDR 	=> SDRAM_ADDR,
			DRAM_DQM		=> SDRAM_DQM,
			DRAM_WE_N	=> SDRAM_WE_N,
			DRAM_CAS_N	=> SDRAM_CAS_N,
			DRAM_RAS_N	=> SDRAM_RAS_N,
			DRAM_CS_N	=> SDRAM_CS_N,
			DRAM_BA		=> SDRAM_BA,

			bus_D_o		=> i_ram_q,
			bus_D_i		=> i_dat_i_pre,
			bus_A_i		=> i_adr_i_pre,
			bus_WE_i		=> i_exec_wr,
			bus_ck		=> clk_i,
			bus_cke		=> '1',
			bus_ref		=> i_bus_ref,		
			ck_mem		=> clk_sdram,	
			rst_i			=> i_power_reset1,
			rst_o			=> sdram_reset,
			
			tst_start	=> tst_start,
			tst_act		=> tst_act
		);	
	end generate g;
	g0: if not SIM generate
		e_sdram: entity work.SDRAM_CTL 
		generic map (
			SIM => SIM
		)
		PORT MAP(
			DRAM_DQ 		=> SDRAM_DQ,
			DRAM_ADDR 	=> SDRAM_ADDR,
			DRAM_DQM		=> SDRAM_DQM,
			DRAM_WE_N	=> SDRAM_WE_N,
			DRAM_CAS_N	=> SDRAM_CAS_N,
			DRAM_RAS_N	=> SDRAM_RAS_N,
			DRAM_CS_N	=> SDRAM_CS_N,
			DRAM_BA		=> SDRAM_BA,

			bus_D_o		=> i_ram_q,
			bus_D_i		=> i_dat_i_pre,
			bus_A_i		=> i_adr_i_pre,
			bus_WE_i		=> i_exec_wr,
			bus_ck		=> clk_i,
			bus_cke		=> '1',
			bus_ref		=> i_bus_ref,		
			ck_mem		=> clk_sdram,	
			rst_i			=> i_power_reset1,
			rst_o			=> sdram_reset,
			
			tst_start	=> tst_start,
			tst_act		=> tst_act
		);
	end generate g0;
	
end architecture arch;