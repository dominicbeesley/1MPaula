----------------------------------------------------------------------------------
-- Company: 			Dossytronics
-- Engineer: 			Dominic Beesley
-- 
-- Create Date:    	3/7/2019 
-- Design Name: 
-- Module Name:    	dmac - sound channel selector and wrapper
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 		
--
-- Dependencies: 
--
-- Revision: 
-- Revision 0.02 - sound mixer fed back to channel for peak detector
-- Additional Comments: 
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.STD_LOGIC_MISC.ALL;


library work;
use work.fishbone.all;
use work.common.all;


entity fb_DMAC_int_sound is
	 generic (
		SIM									: boolean := false;							-- skip some stuff, i.e. slow sdram start up	
		G_SPEED								: fb_cyc_speed_t := MHZ_8;					-- speed to request cycles at
		G_CHANNELS							: natural := 4
	 );
    Port (

		-- fishbone signals		
		fb_syscon_i							: in		fb_syscon_t;

		-- slave interface (control registers)
		fb_sla_m2s_i						: in		fb_mas_o_sla_i_t;
		fb_sla_s2m_o						: out		fb_mas_i_sla_o_t;

		-- master interface (dma)
		fb_mas_m2s_o						: out		fb_mas_o_sla_i_arr(G_CHANNELS-1 downto 0);
		fb_mas_s2m_i						: in		fb_mas_i_sla_o_arr(G_CHANNELS-1 downto 0);

		cpu_halt_o							: out		STD_LOGIC;

		-- sound specific
		snd_clk_i							: in		std_logic;
		snd_dat_o							: out		signed(9 downto 0);
		snd_dat_change_clken_o			: out		std_logic
	 );

	 -- sound
	 constant	A_CHA_SEL		: integer := 15;
	 constant	A_OVR_VOL		: integer := 14;
end fb_DMAC_int_sound;

architecture Behavioral of fb_DMAC_int_sound is

	constant PADBITS						: std_logic_vector(8-CEIL_LOG2(G_CHANNELS-1)-1 downto 0) := (others => '0');

	type		sla_state_t	is (idle, child_act, sel_act);

	type		snd_dat_arr is array(natural range <>) of signed(7 downto 0);

	signal	r_sla_state 				: sla_state_t;

	signal	i_fb_sla_m2s				: fb_mas_o_sla_i_arr(G_CHANNELS-1 downto 0);
	signal	i_fb_sla_s2m				: fb_mas_i_sla_o_arr(G_CHANNELS-1 downto 0);

	signal	r_cha_sel					: unsigned(CEIL_LOG2(G_CHANNELS-1)-1 downto 0);
	signal	r_ovr_vol					: unsigned(5 downto 0);

	signal	i_child_cpu_halt			: std_logic_vector(G_CHANNELS-1 downto 0);
	signal	i_child_snd_dat			: snd_dat_arr(G_CHANNELS-1 downto 0);
	signal	i_child_snd_dat_clken	: std_logic_vector(G_CHANNELS-1 downto 0);
	signal	r_tot_snd_dat				: signed(9 downto 0);

	signal 	i_snd_clken_sndclk		: std_logic;											-- gets set to 1 on each positive edge of the
																											-- sound clock for one fishbone cycle

	signal	i_snd_clk_tgl				: std_logic;

	signal	r_reg_snd_clk				: std_logic_vector(5 downto 0);

	signal clk : std_logic;
	signal rst : std_logic;

begin

	p_snd_tgl:process(snd_clk_i)
	begin

		if rising_edge(snd_clk_i) then
			if i_snd_clk_tgl = '0' then
				i_snd_clk_tgl <= '1';
			else
				i_snd_clk_tgl <= '0';
			end if;
		end if;
	end process;

	p_snd_clk_xdomain:process(clk)
	begin
		if rising_edge(clk) then
			r_reg_snd_clk <= r_reg_snd_clk(r_reg_snd_clk'high-1 downto 0) & i_snd_clk_tgl;

			if r_reg_snd_clk(r_reg_snd_clk'high) /= r_reg_snd_clk(r_reg_snd_clk'high-1) then
				i_snd_clken_sndclk <= '1';
			else
				i_snd_clken_sndclk <= '0';
			end if;
		end if;
	end process;

--	snd_clken_sndclk_o <= i_snd_clken_sndclk;
---- generate a 3.5ish Mhz clock en from sound clock in 
--	-- the fbsyscon clock domain
--	e_flanc_snd2fb : entity work.flancter
--	generic map (
--		REGISTER_OUT => TRUE
--	)
--	port map (
--		rst_i_async	=> fb_syscon_i.rst,
--		
--		set_i_ck		=> snd_clk_i,
--		set_i			=> '1',
--		
--		rst_i_ck		=> fb_syscon_i.clk,
--		rst_i			=> '1',
--		
--		flag_out		=> i_snd_clken_sndclk
--	);

	-- this may seem unnecessary but ISIM mucks up the state machines
	-- if the clock signal comes from a record.
	clk <= fb_syscon_i.clk;
	rst <= fb_syscon_i.rst;


	p_snd_add:process(clk)
	variable v_snd_tot : signed(CEIL_LOG2(G_CHANNELS-1)+7 downto 0);
	begin
		if rising_edge(clk) then
			v_snd_tot := (others => '0');
			for I in G_CHANNELS-1 downto 0 loop
				v_snd_tot := v_snd_tot + i_child_snd_dat(I);
			end loop;
			r_tot_snd_dat <= resize(v_snd_tot, 10);

			snd_dat_change_clken_o <= '0';
			for C in G_CHANNELS-1 downto 0 loop
				if i_child_snd_dat_clken(C) = '1' then
					snd_dat_change_clken_o <= '1';
				end if;
			end loop;
		end if;
	end process;

	snd_dat_o <= r_tot_snd_dat;

	cpu_halt_o <= or_reduce(i_child_cpu_halt);


	p_sla_state:process(clk, rst, fb_sla_m2s_i)
	variable v_rs:natural range 0 to 15;
	begin
		v_rs := to_integer(unsigned(fb_sla_m2s_i.A(3 downto 0)));
		if rst = '1' then
			r_sla_state <= idle;
			r_cha_sel <= (others => '0');
			r_ovr_vol <= (others => '1');
		else
			if rising_edge(clk) then

				case r_sla_state is
					when idle =>
						if fb_sla_m2s_i.cyc = '1' and fb_sla_m2s_i.A_stb = '1' then
							if v_rs = A_CHA_SEL or v_rs = A_OVR_VOL then
								r_sla_state <= sel_act;
							else
								r_sla_state <= child_act;
							end if;
						end if;
					when sel_act =>
						if fb_sla_m2s_i.we = '1' and fb_sla_m2s_i.D_wr_stb = '1' then
							if v_rs = A_CHA_SEL then
								r_cha_sel <= unsigned(fb_sla_m2s_i.D_wr(CEIL_LOG2(G_CHANNELS-1)-1 downto 0));
							elsif v_rs = A_OVR_VOL then
								r_ovr_vol <= unsigned(fb_sla_m2s_i.D_wr(7 downto 2));
							end if;
						end if;
						if fb_sla_m2s_i.cyc = '0' then
							r_sla_state <= idle;
						end if;
					when child_act =>
						if fb_sla_m2s_i.cyc = '0' then
							r_sla_state <= idle;
						end if;
					when others => null;
				end case;
			end if;
		end if;
	end process;

	g_cha: for I in 0 to G_CHANNELS-1 generate

		e_cha_1: entity work.fb_DMAC_int_sound_cha
		generic map (
		SIM									=> SIM,
		G_SPEED								=> G_SPEED
		)
		port map (

		-- fishbone signals		
		fb_syscon_i							=> fb_syscon_i,

		-- slave interface (control registers)
		fb_sla_m2s_i						=> i_fb_sla_m2s(I),
		fb_sla_s2m_o						=> i_fb_sla_s2m(I),

		-- master interface (dma)
		fb_mas_m2s_o						=> fb_mas_m2s_o(I),
		fb_mas_s2m_i						=> fb_mas_s2m_i(I),

		cpu_halt_o							=> i_child_cpu_halt(I),

		snd_clken_sndclk_i				=> i_snd_clken_sndclk,
		snd_dat_o							=> i_child_snd_dat(I),
		snd_dat_change_clken				=> i_child_snd_dat_clken(I)

		);

	end generate;

		
	p_sla_cha_sel_o:process(fb_syscon_i, r_sla_state, r_cha_sel, i_fb_sla_s2m)	
	begin		
		fb_sla_s2m_o <= (
			D_rd => (others => '-'),
			rdy => '0',
			ack => '0',
			nul => '0'
			);
		if r_sla_state = child_act then
			for I in 0 to G_CHANNELS-1 loop
				if r_cha_sel = I then
					fb_sla_s2m_o <= i_fb_sla_s2m(I);
				end if;
			end loop;
		elsif r_sla_state = sel_act then
			fb_sla_s2m_o <= (
				D_rd => PADBITS & std_logic_vector(r_cha_sel),
				rdy => '1',
				ack => fb_syscon_i.cpu_clks(FB_CPUCLKINDEX(G_SPEED)).cpu_clken,
				nul => '0'
				);
		end if;
	end process;
					
	p_sla_cha_sel_i:process(r_cha_sel, fb_sla_m2s_i)
	begin
		for I in 0 to G_CHANNELS-1 loop
			if r_cha_sel = I then
				-- this assumes that the child channels will
				-- ignore selects to register F!
				i_fb_sla_m2s(I) <= fb_sla_m2s_i;
			else
				i_fb_sla_m2s(I) <= (
						cyc => '0',
						cyc_speed => G_SPEED,
						we => '0',
						A => (others => '-'),
						A_stb => '0',
						D_wr => (others => '-'),
						D_wr_stb => '0'
					);
			end if;
		end loop;		
	end process;

					
end Behavioral;
