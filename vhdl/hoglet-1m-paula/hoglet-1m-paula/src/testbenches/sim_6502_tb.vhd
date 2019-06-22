--------------------------------------------------------------------------------
-- Company: 
-- Engineer:
--
-- Create Date:   19:42:18 05/18/2019
-- Design Name:   
-- Module Name:   D:/Users/Dominic/Documents/fpga/blitter/hoglet-1m-paula/hoglet-1m-paula/hoglet-1m-paula/src/testbenches/sim_6502_tb.vhd
-- Project Name:  hoglet-1m-paula
-- Target Device:  
-- Tool versions:  
-- Description:   
-- 
-- VHDL Test Bench Created by ISE for module: top_paula_1m
-- 
-- Dependencies:
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
--  This test bench emulates a cut-down BBC micro with a single 16k MOS ROM
--  and 32k RAM, hardware at FC00-FEFF does nothing special other than return 
--  'X', one special register at FEFF is used to terminate the simulation
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
 
ENTITY sim_6502_tb IS
END sim_6502_tb;
architecture Behavioral of sim_6502_tb is
   
    
	signal	sim_ENDSIM			: 	std_logic 		:= '0';
	
	signal	EXT_CLK_50M			: 	std_logic;


	signal	sim_dump_ram		:	std_logic;
	signal	sim_reg_halt 		:  std_logic;
	
	signal	SYS_phi0				:  std_logic;
	signal	SYS_phi1				:  std_logic;
	signal	SYS_phi2				:  std_logic;
	signal	SYS_nRESET			:	std_logic;

	signal	SYS_A					:	std_logic_vector(15 downto 0);
	signal	SYS_D					:	std_logic_vector(7 downto 0);

	signal	i_SYS_TB_nPGFC		: std_logic;
	signal	i_SYS_TB_nPGFD		: std_logic;

   signal  i_SYS_TB_n1MHZ     : std_logic;

	signal	i_SYS_TB_nPGFE		: std_logic;
	signal	i_SYS_TB_RAM_nCS	: std_logic;
	signal	i_SYS_TB_RAM_RnW	: std_logic;
	signal	i_SYS_TB_MOSROM_nCS	: std_logic;
	signal	i_SYS_TB_RAM_A		: std_logic_vector(18 downto 0);
	signal	i_SYS_TB_ROM_A		: std_logic_vector(15 downto 0);

	signal	SYS_RnW				: std_logic;


	signal	SYS_nNMI				: std_logic;
	signal	SYS_nIRQ				: std_logic;

   signal  CLK_16             : std_logic;

	signal	bbc_1MHzE			: std_logic;
	signal	bbc_slow				: std_logic;

	signal	bbc_slow_dl			: std_logic;

	
  -- 1MHZ bus signals (buffered)

  signal bus1m_D : std_logic_vector(7 downto 0);
  signal bus1m_A : std_logic_vector(7 downto 0);


  -- hoglet buffer bus
   signal i_buf_u3_in : std_logic_vector(7 downto 0);
   signal i_buf_u3_out : std_logic_vector(7 downto 0);

   --Inputs
   signal i_hog_clk50 : std_logic := '0';
   signal i_hog_clke : std_logic := '0';
   signal i_hog_rnw : std_logic := '0';
   signal i_hog_rst_n : std_logic := '0';
   signal i_hog_pgfc_n : std_logic := '0';
   signal i_hog_pgfd_n : std_logic := '0';
   signal i_hog_bus_addr : std_logic_vector(7 downto 0) := (others => '0');
   signal i_hog_sw1 : std_logic := '0';
   signal i_hog_sw2 : std_logic := '0';

	--BiDirs
   signal i_hog_bus_data : std_logic_vector(7 downto 0);
   signal i_hog_ram_data : std_logic_vector(7 downto 0);

 	--Outputs
   signal i_hog_bus_data_dir : std_logic;
   signal i_hog_bus_data_oel : std_logic;
   signal i_hog_nmi : std_logic;
   signal i_hog_irq : std_logic;
   signal i_hog_dac_cs_n : std_logic;
   signal i_hog_dac_sck : std_logic;
   signal i_hog_dac_sdi : std_logic;
   signal i_hog_dac_ldac_n : std_logic;
   signal i_hog_ram_addr : std_logic_vector(18 downto 0);
   signal i_hog_ram_cel : std_logic;
   signal i_hog_ram_oel : std_logic;
   signal i_hog_ram_wel : std_logic;
   signal i_hog_pmod0 : std_logic_vector(7 downto 0);
   signal i_hog_pmod1 : std_logic_vector(7 downto 0);
   signal i_hog_pmod2 : std_logic_vector(7 downto 0);
   signal i_hog_led : std_logic;

 
begin
 
   -- make 1MHz bus signals

   i_SYS_TB_n1MHZ <= i_SYS_TB_nPGFC and i_SYS_TB_nPGFD;

   e_buf_1m_D:entity work.LS74245
   Port map (
      A           => bus1m_D,
      B           => SYS_D,
      dirA2BnB2A  => SYS_RnW,
      nOE         => i_SYS_TB_n1MHZ
   );

   bus1m_D <= (others => 'H'); -- bus terminator resistors


   e_buf_1m_A:entity work.LS74244
   port map (
      D           => SYS_A(7 downto 0),
      Q           => bus1m_A,
      nOE_A       => '0',
      nOE_B       => '0'
   );

   -- buffers on hoglet board

   e_hog_u1: entity work.LS74245
   generic map (
      tprop       => 4 ns,
      toe         => 4 ns,
      ttr         => 4 ns 
   )
   port map (
      A           => i_hog_bus_addr,
      B           => bus1m_A,
      dirA2BnB2A  => '0',
      nOE         => '0'
   );

   e_hog_u2: entity work.LS74245
   generic map (
      tprop       => 4 ns,
      toe         => 4 ns,
      ttr         => 4 ns 
   )
   port map (
      A           => i_hog_bus_data,
      B           => bus1m_D,
      dirA2BnB2A  => i_hog_bus_data_dir,
      nOE         => i_hog_bus_data_oel
   );

   i_buf_u3_in(0) <=  SYS_RnW;
   i_buf_u3_in(1) <=  bbc_1MHzE;
   i_buf_u3_in(2) <=  '0';
   i_buf_u3_in(3) <=  '0';
   i_buf_u3_in(4) <=  i_SYS_TB_nPGFC;
   i_buf_u3_in(5) <=  i_SYS_TB_nPGFD;
   i_buf_u3_in(6) <=  SYS_nRESET;
   i_buf_u3_in(7) <=  '0';

   e_hog_u3: entity work.LS74245
   generic map (
      tprop       => 4 ns,
      toe         => 4 ns,
      ttr         => 4 ns 
   )
   port map (
      A           => i_buf_u3_out,
      B           => i_buf_u3_in,
      dirA2BnB2A  => '0',
      nOE         => '0'
   );

   i_hog_rnw <= i_buf_u3_out(0);
   i_hog_clke <= i_buf_u3_out(1);
   i_hog_pgfc_n <= i_buf_u3_out(4);
   i_hog_pgfd_n <= i_buf_u3_out(5);
   i_hog_rst_n <= i_buf_u3_out(6);

	-- Instantiate the Unit Under Test (UUT)
   uut: entity work.top_paula_1m 
   GENERIC MAP (
   	SIM => true
   	)
   PORT MAP (
          clk50       =>  i_hog_clk50,
          clke        =>  i_hog_clke,
          rnw         =>  i_hog_rnw,
          rst_n       =>  i_hog_rst_n,
          pgfc_n      =>  i_hog_pgfc_n,
          pgfd_n      =>  i_hog_pgfd_n,
          bus_addr    =>  i_hog_bus_addr,
          bus_data    =>  i_hog_bus_data,
          bus_data_dir=>  i_hog_bus_data_dir,
          bus_data_oel=>  i_hog_bus_data_oel,
          nmi         =>  i_hog_nmi,
          irq         =>  i_hog_irq,
          dac_cs_n    =>  i_hog_dac_cs_n,
          dac_sck     =>  i_hog_dac_sck,
          dac_sdi     =>  i_hog_dac_sdi,
          dac_ldac_n  =>  i_hog_dac_ldac_n,
          ram_addr    =>  i_hog_ram_addr,
          ram_data    =>  i_hog_ram_data,
          ram_cel     =>  i_hog_ram_cel,
          ram_oel     =>  i_hog_ram_oel,
          ram_wel     =>  i_hog_ram_wel,
          pmod0       =>  i_hog_pmod0,
          pmod1       =>  i_hog_pmod1,
          --mod2       =>  i_hog_pmod2,
          sw1         =>  i_hog_sw1,
          sw2         =>  i_hog_sw2,
          led         =>  i_hog_led
        );

   i_hog_clk50 <= EXT_CLK_50M;

   SYS_nNMI <= not i_hog_nmi;
   SYS_nIRQ <= not i_hog_irq;


	
	i_SYS_TB_nPGFE <= 	'0' when SYS_A(15 downto 8) = x"FE" else
								'1';

	i_SYS_TB_nPGFD <= 	'0' when SYS_A(15 downto 8) = x"FD" else
								'1';

	i_SYS_TB_nPGFC <= 	'0' when SYS_A(15 downto 8) = x"FC" else
								'1';

	i_SYS_TB_RAM_nCS <= 	'0' when SYS_A(15) = '0' and SYS_phi2 = '1' else
								'1' after 30 ns;
								
	i_SYS_TB_RAM_RnW <= 	'0' when SYS_RnW = '0' and SYS_phi2 = '1' else
								'1';

	i_SYS_TB_MOSROM_nCS <= 	'0' when SYS_A(15 downto 14) = "11" and i_SYS_TB_nPGFE = '1' and i_SYS_TB_nPGFD = '1' and i_SYS_TB_nPGFC = '1' else
								'1' after 30 ns;


	e_slow_cyc_dec:entity work.bbc_slow_cyc
	port map (
		SYS_A_i => SYS_A,
		SLOW_o => bbc_slow
		);
	
	bbc_slow_dl <= bbc_slow after 10 ns;

-- doesn't work in ISIM
--	p_hold:process(SYS_D(0))
--	variable prev: std_logic_vector(7 downto 0) := (others => 'U');
--	begin
--		if SYS_D'event then
--			FOR I in 0 to 7 LOOP
--				if prev(I) = '0' then
--					if SYS_D(I) = 'Z' or SYS_D(I) = 'W' or SYS_D(I) = 'H' then
--						SYS_D_bushold(I) <= 'L';
--					end if;
--				elsif prev(I) = '1' then
--					if SYS_D(I) = 'Z' or SYS_D(I) = 'W' or SYS_D(I) = 'L' then
--						SYS_D_bushold(I) <= 'H';
--					end if;
--				else
--					SYS_D_bushold(I) <= 'H';
--				end if;
--			END LOOP;
--			prev := SYS_D;
--		end if;
--	end process;

--	SYS_D <= SYS_D_bushold;

	e_cpu: entity work.real_6502_tb 
	--NMOS
	GENERIC MAP (
			dly_phi0a => 5 ns,
			dly_phi0b => 5 ns,
			dly_phi0c => 5 ns,
			dly_phi0d => 5 ns,
			dly_addr  => 140 ns, 
			dly_dwrite=> 100 ns,	-- dwrite must be > dhold
			dly_dhold => 100 ns
		)
	--CMOS - not really, just a bit quicker...
	--GENERIC MAP (
	--	dly_phi0a => 1 ns,
	--	dly_phi0b => 1 ns,
	--	dly_phi0c => 1 ns,
	--	dly_phi0d => 1 ns,
	--	dly_addr  => 10 ns, -- faster than spec!
	--	dly_dwrite=> 40 ns,	-- dwrite must be > dhold
	--	dly_dhold => 30 ns
	--)
	PORT MAP (
		A => SYS_A(15 downto 0),
		D => SYS_D,
		nRESET => SYS_nRESET,
		RDY => '1',
		nIRQ => SYS_nIRQ,
		nNMI => SYS_nNMI,
		nSO => '1',
		RnW => SYS_RnW,
		SYNC => open,
		PHI0 => SYS_PHI0,
		PHI1 => SYS_PHI1,
		PHI2 => SYS_PHI2
		);


	e_board_ram512: entity work.ram_tb 
	generic map (
		size 			=> 512*1024,
		dump_filename => "d:\\temp\\ram_dump_hog512.bin",
		toh		=> 1 ns,
		tohz		=> 1 ns,
		thz		=> 3 ns,
		tolz		=> 3 ns,
		tlz		=> 3 ns,
		toe		=> 3 ns,
		tco		=> 10 ns,
		taa		=> 10 ns,		
		twed		=> 1 ns
	)
	port map (
		A				=> i_hog_ram_addr,
		D				=> i_hog_ram_data,
		nCS			=> i_hog_ram_cel,
		nOE			=> i_hog_ram_oel,
		nWE			=> i_hog_ram_wel,
		
		tst_dump		=> sim_dump_ram

	);


	i_SYS_TB_RAM_A <= "0000" & SYS_A(14 downto 0);
	e_sys_ram_32: entity work.ram_tb 
	generic map (
		size 			=> 32*1024,
		dump_filename => "d:\\temp\\ram_dump_blit_dip40_poc-sysram.bin",
		tco => 150 ns,
		taa => 150 ns
	)
	port map (
		A				=> i_SYS_TB_RAM_A,
		D				=> SYS_D,
		nCS			=> i_SYS_TB_RAM_nCS,
		nOE			=> '0',
		nWE			=> i_SYS_TB_RAM_RnW,
		
		tst_dump		=> sim_dump_ram

	);

	
	i_SYS_TB_ROM_A <= "00" & SYS_A(13 downto 0);
	w_sys_rom_16: entity work.rom_tb
	generic map (
		romfile 		=> "D:\Users\Dominic\Documents\fpga\blitter\6502-blit-vhdl\hoglet-1m-paula\hoglet-1m-paula\test_asm\test1m_paula.rom",
		size 			=> 16*1024
	)
	port map (
		A 				=> i_SYS_TB_ROM_A,
		D 				=> SYS_D,
		nCS 			=> i_SYS_TB_MOSROM_nCS,
		nOE 			=> '0'
	);

	p_reg_halt: process(SYS_nRESET, i_SYS_TB_nPGFE, SYS_A, SYS_D, SYS_phi2)
	begin
		if (SYS_nRESET = '0') then
			sim_reg_halt <= '0';
		elsif falling_edge(SYS_phi2) and SYS_RnW = '0' and i_SYS_TB_nPGFE = '0' and unsigned(SYS_A(7 downto 0)) = 16#FF# then
			sim_reg_halt <= SYS_D(7);
		end if;
	end process;
	
	p_clk_16:process -- deliberately 1/4 ns fast!
	begin
    if sim_ENDSIM = '0' then
		  CLK_16 <= '1';
		  wait for 31.2 ns;
		  CLK_16 <= '0';
		  wait for 31.25 ns;
    else 
      wait;
    end if;
	end process;

	e_bbc_clk_gen:entity work.bbc_clk_gen 
	port map (
		clk_16_i        => CLK_16,
		clk_8_o         => open,
		clk_4_o         => open,
		clk_2_o         => open,
		clk_1_o         => open,
		
		bbc_SLOW_i      => bbc_slow_dl,
		bbc_phi1_i      => SYS_phi1,
		bbc_1MHzE_o     => bbc_1MHzE,
		bbc_ROMSEL_clk_o=> open,
		bbc_phi0_o      => SYS_PHI0
	);

	main_clkc50: process
	begin
		if sim_ENDSIM='0' then
			EXT_CLK_50M <= '0';
			wait for 10 ns;
			EXT_CLK_50M <= '1';
			wait for 10 ns;
		else
			wait;
		end if;
	end process;

	
	stim: process
	variable usct : integer := 0;
	
	begin
			
			sim_dump_ram <= '0';
			SYS_nRESET <= '1';
			wait for 101 ns;						

			SYS_nRESET <= '0';

			wait for 20 us;
			SYS_nRESET <= '1';

			while usct < 200000 and sim_reg_halt /= '1' loop
				wait for 10 us;
				usct := usct + 1;
			end loop;
			
			
			sim_dump_ram <= '1';
			sim_ENDSIM <= '1';

			wait for 10 us;

			wait;
	end process;


end;
