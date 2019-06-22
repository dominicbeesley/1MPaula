-- Company: 			Dossytronics
-- Engineer: 			Dominic Beesley
-- 
-- Create Date:    	16/04/2019
-- Design Name: 
-- Module Name:    	fishbone bus
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 		A bus (loosely based on Wishbone) to allow communication 
--							between various devices of differing speeds
-- Dependencies: 
--
-- Revision: 
-- Additional Comments: 
--
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


package fishbone is

	type fb_std_logic_2d is array(natural range <>, natural range <>) of std_logic;

	function fb_2d_get_slice(
		x : fb_std_logic_2d;
		i : natural
	) return std_logic_vector;

	procedure fb_2d_set_slice(
		signal x: inout fb_std_logic_2d; 
		constant i: in natural;
		signal v: in std_logic_vector
	);

	procedure fb_2d_copy_slice(
		signal dest: inout fb_std_logic_2d;
		constant destslice: in natural;
		signal src: in fb_std_logic_2d;
		constant srcslice: in natural
	);

	type fb_rst_state_t is (
		-- the board is being powered up
		powerup, 
		-- a normal break/reset
		reset, 
		-- the user has held the reset in for 3s
		resetfull, 
		-- deadzone before starting processors on blitter board to avoid glitchy/bouncy resets to aid debuggin
		-- not used on all devices
		prerun, 
		-- normal - no reset in progress
		run, 
		-- the clock generators / plls lost lock 
		lockloss
		);

	-- note this could be defined as a type but had problems
	-- with Quartus making lots of horrible extra muxes, not
	-- worked out why yet
	subtype fb_cyc_speed_t is std_logic_vector(2 downto 0);
	constant MHZ_1 	: fb_cyc_speed_t := "000";
	constant MHZ_2 	: fb_cyc_speed_t := "001";
	constant MHZ_4 	: fb_cyc_speed_t := "010";
	constant MHZ_8 	: fb_cyc_speed_t := "011";
	constant MHZ_16 	: fb_cyc_speed_t := "100";

	-- convert a speed to an index in the cpu_clks array
	function FB_CPUCLKINDEX(X:fb_cyc_speed_t) return natural;

	type fb_cpu_clks_t is record
		cpu_clk_E			: std_logic;							-- phi2 / E clk for cpu
		cpu_clk_Q			: std_logic;							-- phi2 / Q clk for cpu
		cpu_sys_rdy			: std_logic;							-- rdy signal for cpu (stretched for 1M cycles and sized for single cpu cycle at end of phi2/E)
		cpu_clken			: std_logic;							-- clken / ack every 2M cycle (not stretched for 1M cycles)
	end record fb_cpu_clks_t;

	type fb_cpu_clks_arr is array(4 downto 0) of fb_cpu_clks_t;

	type fb_syscon_t is record
		clk					: std_logic;							-- "fast" clock
		rst					: std_logic;							-- bus reset
		rst_state			: fb_rst_state_t;						-- power up etc

		cpu_clks				: fb_cpu_clks_arr;					-- master clocks

		sys_clken_E_st 	: std_logic;							-- single clock near start of phi2/1M cycle, used by fb_SYS/fb_BUS1M state machines to sample bus for new address
	end record fb_syscon_t;


	-- signals from masters to slaves
	type fb_mas_o_sla_i_t is record				
		cyc_speed 			: 	fb_cyc_speed_t;					-- indicates to slave the speed of the master
																			-- the ready signal from slow devices will be sized to 
																			-- suit this i.e. for SYS access with master at 8MhZ the
																			-- D_i_rdy_i signal will go high during the last 125ns of 
																			-- SYS_phi2 so that the processor will continue synced to 
																			-- the system
		cyc					:  std_logic;							-- stays active throughout cycle
		we						: 	std_logic;							-- write =1, read = 0, qualified by A_o_stb_o
		A						: 	std_logic_vector(23 downto 0);-- physical address
		A_stb					: 	std_logic;							-- address out strobe, qualifies A_o, hold until end of cyc_o
		D_wr					: 	std_logic_vector(7 downto 0);	-- data out from master to slave
		D_wr_stb				:	std_logic;							-- data out strobe, qualifies D_o, can ack writes as soon
																			-- as this is ready or wait until end of cycle
	end record fb_mas_o_sla_i_t;

	--signals from slaves to masters
	type fb_mas_i_sla_o_t is record

		D_rd					: 	std_logic_vector(7 downto 0);	-- data in during a read
		rdy					:	std_logic;							-- data ready or write done:
																			-- for reads: when high the data *will be* ready by the end of this cyc_speed cycle 
																			-- for write: when high the data has been consumed, continue - it may happen before
																			-- the write actually completes i.e. see example SYS double write below
		ack					: std_logic;							-- cycle complete, master must terminate cycle now, data was supplied or latched
		nul					: std_logic;							-- when set there is no respone i.e. either there is an error or no address matches
																			-- the cycle should be abored immediately (ack will also be set)

	end record fb_mas_i_sla_o_t;

	type fb_mas_o_sla_i_arr is array(natural range <>) of fb_mas_o_sla_i_t;
	type fb_mas_i_sla_o_arr is array(natural range <>) of fb_mas_i_sla_o_t;

--	-- address range spec for the intcon entity when an address range is matched then
--	-- a slave is selected from the list of slaves (via devno) and a slave address
--	-- is constructed as (outbase or (A and mask))
--	type fb_addr_spec_t is record
--		base					: std_logic_vector(23 downto 0);	-- base of the address range
--		mask					: std_logic_vector(23 downto 0);	-- when matching if A and not mask = base then match
--																			-- when constructing an address to pass to the slave
--																			-- it is passed outbase or (A and mask)
--		outbase				: std_logic_vector(23 downto 0); -- base address to pass to slave (allows address remaps)
--		devno					: natural;								-- the slave index to use
--		en						: std_logic;							-- whether to enable this match
--	end record fb_addr_spec_t;
--	type fb_addr_spec_arr is array(natural range <>) of fb_addr_spec_t; 

	-- this constant contains the signal sent back to a master when no slave is selected	
	constant fb_m2s_unsel : fb_mas_o_sla_i_t := (
		cyc_speed => MHZ_16,
		cyc => '0',
		we => '0',
		A => (others => '1'),
		A_stb => '0',
		D_wr => (others => '1'),
		D_wr_stb => '0'
		);


end package;

package body fishbone is


	function fb_2d_get_slice(x:fb_std_logic_2d; i:natural) return std_logic_vector is
	variable ret:std_logic_vector(x'range(2));
	begin
		for j in x'range(2) loop
			ret(j) := x(i,j);
		end loop;
		return ret;
	end fb_2d_get_slice;

	procedure fb_2d_set_slice(
		signal x : inout fb_std_logic_2d; 
		constant i : in natural;
		signal v : in std_logic_vector
		) is
	begin
		for j in v'range loop
			x(i,j) <= v(j);
		end loop;
	end fb_2d_set_slice;

	procedure fb_2d_copy_slice(
		signal dest: inout fb_std_logic_2d;
		constant destslice: in natural;
		signal src: in fb_std_logic_2d;
		constant srcslice: in natural
	) is
	begin
		for j in dest'range(2) loop
			dest(destslice,j) <= src(srcslice,j);
		end loop;
	end fb_2d_copy_slice;



	function FB_CPUCLKINDEX(X:fb_cyc_speed_t) return natural is
	begin
		case X is
			when MHZ_1 => return 0;
			when MHZ_2 => return 1;
			when MHZ_4 => return 2;
			when MHZ_8 => return 3;
			when MHZ_16 => return 4;		
			when others => return 0;
		end case;
	end FB_CPUCLKINDEX;


end fishbone;