-- Company: 			Dossytronics
-- Engineer: 			Dominic Beesley
-- 
-- Create Date:    	16/04/2019
-- Design Name: 
-- Module Name:    	fishbone bus - syscon 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 		A fishbone syscon provider
-- Dependencies: 
--
-- Revision: 
-- Additional Comments: 
--
----------------------------------------------------------------------------------


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.fishbone.all;

library work;
use work.common.all;

entity fb_syscon is
	generic (
		SIM										: boolean := false;							-- skip some stuff, i.e. slow sdram start up
		CLOCKSPEED								: natural := 128;								-- fast clock speed in mhz		
		CLK_E_LOCK_RANGE						: natural := 4;								-- number of fast cycles for "locked" phase

		PHI02PHASE								: natural := 6;								-- phase between phi0, phi2 must be > CLK_E_LOCK_RANGE
		BUS_1M									: boolean := false							-- true for a 1MHz bus scheme, false for a BBC sys
	);
	port(


		EXT_nRESET_i							: in		std_logic;

		clk_fish_i								: in 		std_logic;							-- main fast fishbone clock in 
		clk_lock_i								: in 		std_logic;							-- pll lock indication

		SYS_CLK_E								: in		std_logic;							-- SYS_CLK_E, phi0 from motherboard used for timing generation or 1MHzE for 1M bus devices
		sys_slow_cyc_i							: in		std_logic;							-- indicates a slow cycle generated from the SYS address

		fb_syscon_o								: out 	fb_syscon_t;						-- fishbon syscon record

		dbg_lock_o								: out		std_logic;
		dbg_fast_o								: out		std_logic;
		dbg_slow_o								: out		std_logic

	);
end fb_syscon;


architecture rtl of fb_syscon is


	function phaselen(bus_1m:boolean) return integer is
	begin
		if bus_1m then
			return 1;
		else
			return 0;
		end if;
	end phaselen;

	-- phi2 dll and sub-clock gen

	-- this counter contains enough cycles for 1us worth of fast ticks
	signal 	r_clock_ctr						: unsigned(ceil_log2((CLOCKSPEED)-1)-1 downto 0) := (others => '0');
	-- this view of the counter contains enough cycles for either 1000ns or 500ns worth of ticks depending on whether this is a
	-- a 1M or 2M system

	signal	ir_clock_ctr_E_cycle			: unsigned(r_clock_ctr'high-1+phaselen(BUS_1M) downto 0) := (others => '0');

	signal	i_long_1M_cyc					: std_logic := '0';							-- for SYS devices only
	signal	r_2Mcycle						: std_logic_vector(1 downto 0) 	:= (others => '0');
																											-- counts number of 2m cycles since last 
																									-- fast cycles per 1m cycle
	signal	r_CLK_E_dly						: std_logic_vector(PHI02PHASE+1 downto 0) := (others => '0');
																										-- delay line for phi0
	signal	r_CLK_E_toggle					: std_logic := '0';							-- toggles when a phi2 negative edge detected, 
																										-- used when counting 2M cycles in a stretched
																										-- 1M cycle
																										-- phi0 for cycle stretching
	signal	r_dll_lock						: std_logic := '0';

	signal	i_fb_syscon						: fb_syscon_t;

	signal	i_dll_slow						: std_logic;		-- set when phase detector detects slow clock
	signal	i_dll_fast						: std_logic;		-- set when phase detector detects fast clock

	-- external cpu clock gen clockens
	signal	i_clken_Q_up					: std_logic_vector(i_fb_syscon.cpu_clks'range);
	signal	i_clken_Q_dn					: std_logic_vector(i_fb_syscon.cpu_clks'range);
	signal	i_clken_E_up					: std_logic_vector(i_fb_syscon.cpu_clks'range);
	signal	i_clken_E_dn					: std_logic_vector(i_fb_syscon.cpu_clks'range);

	signal	r_rst_state						: fb_rst_state_t := powerup;

	constant RST_COUNT_FULL					: natural := 2**(ceil_log2(CLOCKSPEED * 3 * 1000000)-1)-1; -- full reset 3 seconds (ish)
	constant RST_PUP_MAX						: natural := CLOCKSPEED * 10;				-- quickly force a full  reset at powerup
	constant RST_RUN							: natural := CLOCKSPEED * 50;				-- for reset noise/debounce 50 us
	constant RST_CTR_LEN						: natural := ceil_log2(RST_COUNT_FULL);


	signal	r_rst_counter					: unsigned(RST_CTR_LEN-1 downto 0) := (others => '0');


	signal	i_r_in							: std_logic_vector(0 downto 0);
	signal	i_r_out							: std_logic_vector(0 downto 0);

	signal	rr_EXT_nRESET					: std_logic; -- metastabilised


begin

	-- clock sizing assertions
	-- must give enough even resolution for a 16 MHz clock i.e. be divisible by 32
	assert CLOCKSPEED mod 32 = 0 report "main fishbone clock must be a multiple of 32 MHz" severity error;

	ir_clock_ctr_E_cycle <= r_clock_ctr(r_clock_ctr'high-1+phaselen(BUS_1M) downto 0);

	fb_syscon_o <= i_fb_syscon;

	i_fb_syscon.clk <= clk_fish_i;
	i_fb_syscon.rst <= '0' when r_rst_state = run else '1';
	i_fb_syscon.rst_state <= r_rst_state;


	e_regsigs:entity work.clockreg
	generic map (
		G_DEPTH => 2,
		G_WIDTH => 1
	)
	port map (
		clk_i	=> i_fb_syscon.clk,
		d_i	=> i_r_in,
		q_o	=> i_r_out
	);

	i_r_in(0) <= EXT_nRESET_i;
	rr_EXT_nRESET <= i_r_out(0);

dbg_slow_o <= i_dll_slow;
dbg_fast_o <= i_dll_fast;

	p_reset_state:process(clk_fish_i)
	begin
		if rising_edge(clk_fish_i) then

			case r_rst_state is
				when powerup =>
					if r_rst_counter = RST_PUP_MAX then
						r_rst_state <= reset;
						r_rst_counter <= (others => '0');
					else
						r_rst_counter <= r_rst_counter + 1;
					end if;
				when reset =>
					if rr_EXT_nRESET = '0' then
						r_rst_counter <= r_rst_counter + 1;
						if r_rst_counter = to_unsigned(RST_COUNT_FULL, RST_CTR_LEN) then
							r_rst_state <= resetfull;
							r_rst_counter <= (others => '0');
						end if;
					else
						r_rst_counter <= (others => '0');
						r_rst_state <= prerun;
					end if;
				when resetfull =>
					if rr_EXT_nRESET = '1' then
						r_rst_counter <= (others => '0');
						r_rst_state <= prerun;
					end if;
				when prerun =>
					r_rst_counter <= r_rst_counter + 1;
					if rr_EXT_nRESET = '0' then
						r_rst_counter <= (others => '0');
						r_rst_state <= reset;
					elsif r_rst_counter = to_unsigned(RST_RUN, RST_CTR_LEN) then
						r_rst_counter <= (others => '0');
						r_rst_state <= run;
					end if;
				when run =>
					if clk_lock_i = '0' or r_dll_lock = '0' then
						r_rst_state <= lockloss;
					elsif rr_EXT_nRESET = '0' then
						r_rst_counter <= (others => '0');
						r_rst_state <= reset;
					end if;
				when lockloss =>
					if rr_EXT_nRESET = '0' then
						r_rst_counter <= (others => '0');
						r_rst_state <= reset;
					end if;
				when others => 
					r_rst_state <= lockloss;
			end case;
		end if;
	end process;



	-- align the internal clocks/clockens/cpu clocks with the board phi2
	-- the clock is inspected at the transition of the input phase clock
	-- and the LSB 4 bits used to form a signed (-7 to +7)
	-- if <-1 then running two slow - skip "0"
	-- if >1 then too fast - double "0"
	-- otherwise ok
	-- if <-4 or >=4 then lock is lost
	-- counter == 0 must not be used to generate pulses or clocks as it 
	-- may be missing!
	p_dll_phi2: process(clk_fish_i)
	variable v_clk_E_half : natural;
	variable v_clk_E_full : natural;
	begin

		if BUS_1M then
			v_clk_E_full := CLOCKSPEED;
			v_clk_E_half := CLOCKSPEED / 2;
		else
			v_clk_E_full := CLOCKSPEED / 2;
			v_clk_E_half := CLOCKSPEED / 4;
		end if;

		if rising_edge(clk_fish_i) then

			-- check clock phase against E (plus any phase) when it falls
			if r_CLK_E_dly(r_CLK_E_dly'high-1) = '0' and r_CLK_E_dly(r_CLK_E_dly'high) = '1' then			
				-- dll, just after phi2 (cycle 3) adjust by +/- one cycle to match incoming phi2
				r_dll_lock <= '1';
				dbg_lock_o <= '1';
				if (ir_clock_ctr_E_cycle > v_clk_E_half) then
					i_dll_slow <= '1';
					i_dll_fast <= '0';
					if ir_clock_ctr_E_cycle < v_clk_E_full - CLK_E_LOCK_RANGE then
						r_dll_lock <= '0';
						dbg_lock_o <= '0';
					end if;
				elsif (ir_clock_ctr_E_cycle < v_clk_E_half) then
					i_dll_slow <= '0';
					i_dll_fast <= '1';					
					if ir_clock_ctr_E_cycle > CLK_E_LOCK_RANGE then
						r_dll_lock <= '0';
						dbg_lock_o <= '0';
					end if;
				else 
					i_dll_slow <= '0';
					i_dll_fast <= '0';
				end if;

				r_CLK_E_toggle <= not r_CLK_E_toggle;
			end if;

			if r_clock_ctr = CLOCKSPEED - 1 and i_dll_slow = '1' then
				-- if slow and last cycle skip 0
				r_clock_ctr <= (0 => '1', others => '0');
				i_dll_slow <= '0';
			elsif r_clock_ctr = 0 and i_dll_fast = '1' then
				-- don't update clock but negate slow
				i_dll_fast <= '0';
			elsif r_clock_ctr = CLOCKSPEED - 1 then
				r_clock_ctr <= (others => '0');
			else
				r_clock_ctr <= r_clock_ctr + 1;
			end if;

			r_CLK_E_dly	<= r_CLK_E_dly(r_CLK_E_dly'high-1 downto 0) & SYS_CLK_E;
		end if;
	end process;

	--TODO: generic for where to sample long cycle
	p_detect_long_1Mcyc:process(i_fb_syscon)
	begin
		if BUS_1M then
			i_long_1M_cyc <= '0';
		else
			if rising_edge(i_fb_syscon.clk) then
				if ir_clock_ctr_E_cycle = 3 * CLOCKSPEED / 8 and unsigned(r_2Mcycle) = 0 then -- middle of where phi2 would be unless stretched cycle
					if r_CLK_E_dly	(PHI02PHASE-1) = '1' then
						i_long_1M_cyc <= '0'; 
					else
						i_long_1M_cyc <= '1'; 
					end if;
				end if;
			end if;
		end if;
	end process;

	p_fin:process(i_fb_syscon, r_clock_ctr, sys_slow_cyc_i, i_long_1M_cyc)
	variable v_countE	 				: natural; -- the 2M clock in fast cycles
	variable v_count1M	 			: natural; -- the 1M clock in fast cycles
	variable v_cpu_speed				: natural; -- speed in mhz 2/4/8/16
	variable v_count_cpu  			: natural; -- the cpu clock in fast cycles
	variable v_count_cpu_quarter	: natural; -- used to make Q/E clocks
	variable J							: natural;
	variable v_prev_phi0_toggle	: std_logic := '0';
	variable v_n2mcycles_stretch	: natural;
	begin

		v_count1M := CLOCKSPEED; -- clock max per 1M	

		if BUS_1M then
			v_n2mcycles_stretch := 0;
			v_countE := v_count1M; -- clocks per E
		else	
			v_countE := CLOCKSPEED / 2;	-- 2MHz
			if sys_slow_cyc_i = '0' then -- regular 2M cycle
				v_n2mcycles_stretch := 0;
			elsif i_long_1M_cyc = '1' then -- long 1M cycle == 3 * 2M cycle
				v_n2mcycles_stretch := 2;
			else
				v_n2mcycles_stretch := 1;
			end if;
		end if;

		if rising_edge(i_fb_syscon.clk) then

			if BUS_1M then
				if ir_clock_ctr_E_cycle = ((CLOCKSPEED * 250) / 1000) then -- 250 ns in
					i_fb_syscon.sys_clken_E_st <= '1';
				else
					i_fb_syscon.sys_clken_E_st <= '0';
				end if;
			else
				if ir_clock_ctr_E_cycle = ((CLOCKSPEED * 80) / 1000)-1 then -- 80 ns in -- even sooner needed for loaded 1m bus
					i_fb_syscon.sys_clken_E_st <= '1';
				else
					i_fb_syscon.sys_clken_E_st <= '0';
				end if;
			end if;

			if BUS_1M then
				r_2Mcycle <= (others => '0');
			else
				if ir_clock_ctr_E_cycle = (v_countE / 2) -1 then -- middle of 2m cycle, increment counter or reset
					if v_prev_phi0_toggle /= r_CLK_E_toggle then
						v_prev_phi0_toggle := not v_prev_phi0_toggle;
						r_2Mcycle <= (others => '0');
					else
						r_2Mcycle <= std_logic_vector(unsigned(r_2Mcycle) + 1);
					end if;
				end if;
			end if;


			for I in i_fb_syscon.cpu_clks'range loop

				if i_clken_Q_up(I) = '1' then
					i_fb_syscon.cpu_clks(I).cpu_clk_Q <= '1';
				end if;

				if i_clken_E_up(I) = '1' then
					i_fb_syscon.cpu_clks(I).cpu_clk_E <= '1';
				end if;

				if i_clken_Q_dn(I) = '1' then
					i_fb_syscon.cpu_clks(I).cpu_clk_Q <= '0';
				end if;

				if i_clken_E_dn(I) = '1' then
					i_fb_syscon.cpu_clks(I).cpu_clk_E <= '0';
				end if;


				v_cpu_speed := 2**I; -- 1..16 MHz
				v_count_cpu := CLOCKSPEED / v_cpu_speed;
				v_count_cpu_quarter := (CLOCKSPEED / 4) / v_cpu_speed;

				-- clken for a soft cpu at end of each period, also used for acks				
				i_fb_syscon.cpu_clks(I).cpu_clken <= '0';
				J := 0;
				while J < v_count1M loop
					J := J + v_count_cpu;
					if r_clock_ctr = J - 1 then
						i_fb_syscon.cpu_clks(I).cpu_clken <= '1';
					end if;
				end loop;

				i_clken_Q_up(I) <= '0';
				i_clken_Q_dn(I) <= '0';
				i_clken_E_up(I) <= '0';
				i_clken_E_dn(I) <= '0';

				-- cpu_clk_E/Q
				J := 0;
				while J < v_count1M loop
					J := J + v_count_cpu_quarter;
					if r_clock_ctr = J - 1 then
						i_clken_Q_up(I) <= '1';
					end if;
					J := J + v_count_cpu_quarter;
					if r_clock_ctr = J - 1 then
						i_clken_E_up(I) <= '1';
					end if;
					J := J + v_count_cpu_quarter;
					if r_clock_ctr = J - 1 then
						i_clken_Q_dn(I) <= '1';
					end if;
					J := J + v_count_cpu_quarter;
					if r_clock_ctr = J - 1 then
						i_clken_E_dn(I) <= '1';
					end if;
				end loop;


				if I = 0 then
					-- 1MHz always ready
					i_fb_syscon.cpu_clks(I).cpu_sys_rdy <= '1';
				elsif (ir_clock_ctr_E_cycle = (v_countE - v_count_cpu_quarter * 2) - 1) 
					and unsigned(r_2Mcycle) = v_n2mcycles_stretch then
					-- rdy signal - half one cpu clock before phi2 until quarter after
					i_fb_syscon.cpu_clks(I).cpu_sys_rdy <= '1';
				end if;


				if I /= 0 and ir_clock_ctr_E_cycle = v_count_cpu_quarter / 2 then
					i_fb_syscon.cpu_clks(I).cpu_sys_rdy <= '0';
				end if;

			end loop;


		end if;
	end process;

end rtl;




