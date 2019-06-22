----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    19:26:29 05/18/2019 
-- Design Name: 
-- Module Name:    top_paula_1m - Behavioral 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 
--
-- Dependencies: 
--
-- Revision: 
-- Revision 0.01 - File Created
-- Additional Comments: 
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.STD_LOGIC_MISC.ALL;

library work;
use work.fishbone.all;

entity top_paula_1m is
	Generic (
		SIM			 						: boolean := false;
		G_SND_CHANNELS						: natural := 4;
		G_MASTER_COUNT						: natural := 5;
		G_SLAVE_COUNT						: natural := 3
		);
   Port (
      -- System oscillator
      clk50        : in    std_logic;
      -- BBC 1MHZ Bus
      clke         : in    std_logic;
      rnw          : in    std_logic;
      rst_n        : in    std_logic;
      pgfc_n       : in    std_logic;
      pgfd_n       : in    std_logic;
      bus_addr     : in    std_logic_vector (7 downto 0);
      bus_data     : inout std_logic_vector (7 downto 0);
      bus_data_dir : out   std_logic;
      bus_data_oel : out   std_logic;
      nmi          : out   std_logic;
      irq          : out   std_logic;
      -- SPI DAC
      dac_cs_n     : out   std_logic;
      dac_sck      : out   std_logic;
      dac_sdi      : out   std_logic;
      dac_ldac_n   : out   std_logic;
      -- RAM
      ram_addr     : out   std_logic_vector(18 downto 0);
      ram_data     : inout std_logic_vector(7 downto 0);
      ram_cel      : out   std_logic;
      ram_oel      : out   std_logic;
      ram_wel      : out   std_logic;
      -- Misc
      pmod0        : out   std_logic_vector(7 downto 0);
      pmod1        : out   std_logic_vector(7 downto 0);
      --pmod2        : out   std_logic_vector(7 downto 0);
      sw1          : in    std_logic;
      sw2          : in    std_logic;
      led          : out   std_logic
   );
end top_paula_1m;

architecture Behavioral of top_paula_1m is
	constant C_CLOCKSPEED : natural := 128;					-- pll is set for 100MHz

--========================================
--FISHBONE globals
--========================================
	signal	i_fb_syscon					: fb_syscon_t;


	-- cpu wrapper
	signal i_m2s_bus1m					: fb_mas_o_sla_i_t;
	signal i_s2m_bus1m					: fb_mas_i_sla_o_t;

	-- jim control registers wrapper
	signal i_m2s_jimctl					: fb_mas_o_sla_i_t;
	signal i_s2m_jimctl					: fb_mas_i_sla_o_t;

	-- blitter board RAM memory wrapper
	signal i_m2s_mem				: fb_mas_o_sla_i_t;
	signal i_s2m_mem				: fb_mas_i_sla_o_t;

	-- sound master
	signal i_m2s_snd_mas			: fb_mas_o_sla_i_arr(G_SND_CHANNELS-1 downto 0);
	signal i_s2m_snd_mas			: fb_mas_i_sla_o_arr(G_SND_CHANNELS-1 downto 0);
	-- sound slave interface control registers
	signal i_m2s_snd_sla			: fb_mas_o_sla_i_t;
	signal i_s2m_snd_sla			: fb_mas_i_sla_o_t;

-----------------------------------------------------------------------------
-- memory map and select 	
-----------------------------------------------------------------------------

	-- the addresses to be mapped
	signal i_map_addr_to_map			: fb_std_logic_2d(G_MASTER_COUNT-1 downto 0, 23 downto 0);	
	-- indicates the address should be mapped this cycle
	signal i_map_addr_clken				: std_logic_vector(G_MASTER_COUNT-1 downto 0);			
	-- clken for address mapping clear - once per cycle
	signal i_map_addr_clr_clken		:	std_logic_vector(G_MASTER_COUNT-1 downto 0);			

	-- possibly translated address
	signal r_map_addr_mapped			: fb_std_logic_2d(G_MASTER_COUNT-1 downto 0, 23 downto 0);					
	-- one hots with a single bit set
	-- for the selected slave
	signal r_map_slave_sel_oh			: fb_std_logic_2d(G_MASTER_COUNT-1 downto 0, G_SLAVE_COUNT-1 downto 0);


-----------------------------------------------------------------------------
-- MEMORY signals
-----------------------------------------------------------------------------

	signal i_JIM_page			: std_logic_vector(15 downto 0); 			-- the actual mapping is done in the cpu component address
																							-- translator (and is not available to the rest of the 
																							-- chipset)
	signal i_JIM_en			: std_logic;							 			-- jim enable signal - only set when FCFF is set to match
																							-- our devno


	signal i_snd_dat_change_clken : std_logic;
	signal i_snd_dat_o				: signed(9 downto 0);
	signal r_snd_per_tgl				: std_logic;


--========================================
--CLOCKS
--========================================
	signal	i_clk_lock 					: std_logic;							-- pll lock 
	signal	i_clk_snd					: std_logic;							-- sound 3.5ish MHz
	signal	i_clk_fish_100M			: std_logic;							-- main bus clock 100M


--========================================
--DEBUG / UI
--========================================
	signal	i_flasher					: std_logic_vector(3 downto 0);	-- for flashing status lights 1..4 Hz


	constant SLAVE_NO_JIMCTL 	: natural := 0;
	constant SLAVE_NO_CHIPRAM	: natural := 1;
	constant SLAVE_NO_SOUND		: natural := 2;

--========================================
--ISIM bodge signals
--========================================
-- ISIM doesn't like clocks in records

	signal	fb_clk						: std_logic;
	signal	fb_rst						: std_logic;

begin

	led <= '0' 			 when i_fb_syscon.rst_state = reset else
			i_flasher(3) when i_fb_syscon.rst_state = powerup else
			i_flasher(2) when i_fb_syscon.rst_state = resetfull else
			i_flasher(0) when i_fb_syscon.rst_state = lockloss else
			'1'			 when i_fb_syscon.rst_state = run else
			i_flasher(1);

	pmod0 <= (
		 	1 => r_snd_per_tgl
		,  others => '0');
	pmod1 <= (others => '0');


	p_snd_pre:process(fb_clk, i_snd_dat_change_clken)
	begin
		if rising_edge(fb_clk) and i_snd_dat_change_clken = '1' then
			if r_snd_per_tgl = '0' then
				r_snd_per_tgl <= '1';
			else
				r_snd_per_tgl <= '0';
			end if;
		end if;
	end process;

	fb_clk <= i_fb_syscon.clk;
	fb_rst <= i_fb_syscon.rst;

	-- memory layout mappings

	p_map_addresses:process(fb_clk, fb_rst)
	variable v_addr: std_logic_vector(23 downto 0);
	begin
		if fb_rst = '1' then
			for M in G_MASTER_COUNT-1 downto 0 loop
				for B in 23 downto 0 loop
					r_map_addr_mapped(M, B) <= '1';	
				end loop;
				for S in G_SLAVE_COUNT-1 downto 0 loop
					r_map_slave_sel_oh(M, S) <= '0';
				end loop;
			end loop;
		elsif rising_edge(fb_clk) then
			for I in G_MASTER_COUNT-1 downto 0 loop

--				v_addr := fb_2d_get_slice(i_map_addr_to_map, I);
				-- shitty shitty ISIM doesn't work!
				for B in 23 downto 0 loop
					v_addr(B) := i_map_addr_to_map(I, B);
				end loop;

				if i_map_addr_clken(I) = '1' then
					-- default no slave selected
					for S in G_SLAVE_COUNT-1 downto 0 loop
						r_map_slave_sel_oh(I, S) <= '0';
					end loop;

					for B in 23 downto 0 loop
						r_map_addr_mapped(I, B) <= v_addr(B);
					end loop;

					if (v_addr = x"FFFCFF" or v_addr = x"FFFCFE" or v_addr = x"FFFCFD") then
						-- jim control register
						r_map_slave_sel_oh(I, SLAVE_NO_JIMCTL) <= '1';
					elsif v_addr(23 downto 4) = x"FEFC8" then
						-- FF FC8x SOUND
						r_map_slave_sel_oh(I, SLAVE_NO_SOUND) <= '1';
					elsif v_addr(23) = '0' then
						r_map_slave_sel_oh(I, SLAVE_NO_CHIPRAM) <= '1';
					end if;
				elsif i_map_addr_clr_clken(I) = '1' then
					for S in G_SLAVE_COUNT-1 downto 0 loop
						r_map_slave_sel_oh(I, S) <= '0';
					end loop;					
				end if;
			end loop;
		end if;
	end process;


	e_fb_intcon: entity work.fb_intcon
	generic map (
		G_MASTER_COUNT => G_MASTER_COUNT,
		G_SLAVE_COUNT => G_SLAVE_COUNT
		)
	port map (
		fb_syscon_i 		=> i_fb_syscon,

		-- slave ports connect to masters
		fb_mas_m2s_i(4)	=> i_m2s_snd_mas(3),
		fb_mas_m2s_i(3)	=> i_m2s_snd_mas(2),
		fb_mas_m2s_i(2)	=> i_m2s_snd_mas(1),
		fb_mas_m2s_i(1)	=> i_m2s_snd_mas(0),
		fb_mas_m2s_i(0)	=> i_m2s_bus1m,

		fb_mas_s2m_o(4)   => i_s2m_snd_mas(3),
		fb_mas_s2m_o(3)   => i_s2m_snd_mas(2),
		fb_mas_s2m_o(2)   => i_s2m_snd_mas(1),
		fb_mas_s2m_o(1)   => i_s2m_snd_mas(0),
		fb_mas_s2m_o(0)	=> i_s2m_bus1m,

		-- master ports connect to slaves
		fb_sla_m2s_o(0)	=> i_m2s_jimctl,
		fb_sla_m2s_o(1)	=> i_m2s_mem,
		fb_sla_m2s_o(2)   => i_m2s_snd_sla,

		fb_sla_s2m_i(0)	=>	i_s2m_jimctl,
		fb_sla_s2m_i(1)	=>	i_s2m_mem,
		fb_sla_s2m_i(2)   => i_s2m_snd_sla,

		-- the addresses to be mapped
		map_addr_to_map_o		=> i_map_addr_to_map,
		-- clken for address mapping - once per cycle
		map_addr_clken_o		=> i_map_addr_clken,	
		-- clken clear for address mapping - once per cycle
		map_addr_clr_clken_o	=> i_map_addr_clr_clken,
		-- possibly translated address
		map_addr_mapped_i		=> r_map_addr_mapped,
		-- one hots with a single bit set
		-- for the selected slave
		map_slave_sel_oh_i	=> r_map_slave_sel_oh

	);

	e_jimctl:entity work.fb_jimctl 
	generic map (
		SIM									=> SIM
	)
	port map (

		-- jim control						
		JIM_page_o							=> i_JIM_page,
		JIM_en_o								=> i_JIM_en,

		-- fishbone signals

		fb_syscon_i							=> i_fb_syscon,
		fb_m2s_i								=> i_m2s_jimctl,
		fb_s2m_o								=> i_s2m_jimctl
	);


	e_fb_mem: entity work.fb_mem
	port map (
			-- 2M RAM/256K ROM bus
		MEM_A_o								=> ram_addr,
		MEM_D_io								=> ram_data,
		MEM_nOE_o							=> ram_oel,
		MEM_nWE_o							=> ram_wel,
		MEM_nCE_o							=> ram_cel,

		-- fishbone signals

		fb_syscon_i							=> i_fb_syscon,
		fb_m2s_i								=> i_m2s_mem,
		fb_s2m_o								=> i_s2m_mem
	);


	e_gen_clocks: entity work.clocks_pll
	generic map (
		SIM => SIM,
		CLOCKSPEED => C_CLOCKSPEED
	)
	port map (
		EXT_nRESET_i						=> rst_n,
		EXT_CLK_50M_i						=> clk50,

		clk_fish_o							=> i_clk_fish_100M,
		clk_snd_o							=> i_clk_snd,

		clk_lock_o							=> i_clk_lock,

		flasher_o							=> i_flasher

	);	


	e_fbsyscon: entity work.fb_syscon
		generic map (
		SIM => SIM,
		CLOCKSPEED => C_CLOCKSPEED,
		BUS_1M => true,
		PHI02PHASE => 0,
		CLK_E_LOCK_RANGE => 8
	)
	port map (
		fb_syscon_o							=> i_fb_syscon,

		EXT_nRESET_i						=> rst_n,

		clk_fish_i							=> i_clk_fish_100M,
		clk_lock_i							=> i_clk_lock,

		SYS_CLK_E							=> clke,
		sys_slow_cyc_i						=> '0'

	);	

	nmi <= '0';
	irq <= '0';

	e_bus_1m:entity work.fb_1mhz 
	generic map (
		SIM => SIM
	)
	port map (

		-- 1MHz bus

		BUS1M_D			=> bus_data,
		BUS1M_D_nOE		=> bus_data_oel,
		BUS1M_D_DIR		=> bus_data_dir,
		BUS1M_A			=> bus_addr,
		BUS1M_nPGFC		=> pgfc_n,
		BUS1M_nPGFD		=> pgfd_n,
		BUS1M_RnW		=> rnw,


		-- fishbone signals
		fb_syscon_i		=> i_fb_syscon,
		fb_m2s_o			=> i_m2s_bus1m,
		fb_s2m_i			=> i_s2m_bus1m,

		jim_page			=> i_JIM_page,
		jim_en			=> i_JIM_en

	);

	e_fb_snd:entity work.fb_DMAC_int_sound
	 generic map (
		SIM									=> SIM,
		G_SPEED								=> MHZ_8,
		G_CHANNELS							=> G_SND_CHANNELS
	 )
    Port map (

		-- fishbone signals		
		fb_syscon_i							=> i_fb_syscon,

		-- slave interface (control registers)
		fb_sla_m2s_i						=> i_m2s_snd_sla,
		fb_sla_s2m_o						=> i_s2m_snd_sla,

		-- master interface (dma)
		fb_mas_m2s_o						=> i_m2s_snd_mas,
		fb_mas_s2m_i						=> i_s2m_snd_mas,

		snd_clk_i							=> i_clk_snd,
		snd_dat_o							=> i_snd_dat_o,
		snd_dat_change_clken_o			=> i_snd_dat_change_clken,

		cpu_halt_o							=> open

	 );


    e_dac_spi:entity work.dac_mcp4822
	generic map (
		SIM				=> SIM
	)
	port map (	
		rst_i				=> i_fb_syscon.rst,
		clk_i				=> i_fb_syscon.clk,
	
		dat_i				=> i_snd_dat_o,
		dat_clken_i		=> i_snd_dat_change_clken,
	
	   dac_cs_n     	=> dac_cs_n,
	   dac_sck      	=> dac_sck,
	   dac_sdi      	=> dac_sdi,
	   dac_ldac_n   	=> dac_ldac_n
	);


end Behavioral;

