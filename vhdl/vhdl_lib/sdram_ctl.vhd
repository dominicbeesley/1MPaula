LIBRARY ieee;

USE ieee.std_logic_1164.all; 
use ieee.numeric_std.all;

LIBRARY work;

-- (c) Dominic Beesley 2014
-- timings assume ISSI 1S42S16160G -7 at 100Mhz

entity SDRAM_CTL is
	generic (
		reset_count : natural := 20000;
		SIM : boolean := FALSE
	);
	port
	(
		-- SDRAM Chip signals
		DRAM_DQ 		: inout std_logic_vector(15 downto 0);
		DRAM_ADDR 	: out std_logic_vector(12 downto 0);
		DRAM_DQM		: out std_logic_vector(1 downto 0);
		DRAM_WE_N	: out std_logic;
		DRAM_CAS_N	: out std_logic;
		DRAM_RAS_N	: out std_logic;
		DRAM_CS_N	: out std_logic;
		DRAM_BA		: out std_logic_vector(1 downto 0);		

		-- Bus signals
		bus_D_o		: out	std_logic_vector(7 downto 0) := (others => '0');
		bus_D_i		: in  std_logic_vector(7 downto 0);
		bus_A_i		: in	std_logic_vector(23 downto 0);
		bus_WE_i		: in 	std_logic;
		bus_ck		: in  std_logic;
		bus_cke		: in 	std_logic;
		bus_ref		: in  std_logic; -- when 1 indicates that nothing is requested - do a refresh
		
		-- Other clocks
		-- passed straight out to DRAM_CLK
		ck_mem		: in	std_logic;
	
		-- System reset;
		rst_i			: in	std_logic;
		rst_o			: out std_logic;
		
		tst_start	: out std_logic;	-- test signal, high during row0 mem cycle (i.e. read/write not refresh)
		tst_act		: out std_logic	-- test signal, indicates that a read/write/refresh operation has been initiated
	);
end SDRAM_ctl;

architecture arch of SDRAM_ctl is
	--- SDRAM COMMANDS
	--- CS_N, RAS_N, CAS_N, WE_N 
	--																		CRCW
	--																		SAAE
	--																		 SS
   constant cmd_nop   : std_logic_vector(3 downto 0) := "0111";
   constant cmd_read  : std_logic_vector(3 downto 0) := "0101";   -- Must be sure A10 is low.
   constant cmd_write : std_logic_vector(3 downto 0) := "0100";
   constant cmd_act   : std_logic_vector(3 downto 0) := "0011";
   constant cmd_pre   : std_logic_vector(3 downto 0) := "0010";  	-- Must set A10 to '1'.
   constant cmd_ref   : std_logic_vector(3 downto 0) := "0001";
   constant cmd_mrs   : std_logic_vector(3 downto 0) := "0000"; 	-- Mode register set

	
	type rec_i_bus_cmd is
	   record		
	      data_i	: std_logic_vector(7 downto 0);
			addr_col : std_logic_vector(8 downto 0);
			addr_row : std_logic_vector(12 downto 0);
			addr_ba  : std_logic_vector(1 downto 0);	
			we_i		: std_logic;
			ref		: std_logic;
		end record;
	signal i_bus_cmd : rec_i_bus_cmd;
	signal i_bus_cmd_ack : std_logic; -- set during mem cycle to ack a bus command
	signal i_bus_cmd_act : std_logic; -- set to indicate a new bus command ready in i_bus_cmd

	type ctl_state is (
		state_pre_reset, 																		-- power up state, the reset has not yet been kicked off
		state_reset, 																			-- reset is in progress, counter controls states within reset
		state_idle, 																			-- waiting for a bus command from the cpu
		state_act_row0, state_act_row1, state_act_row2, 							-- row select during read/write op
		state_re0, state_re1, state_re2, state_re3, 									-- read operation, data read in during re3
		state_we0, state_we1, state_we2, 												-- write operation
		state_rf0, state_rf1, state_rf2, state_rf3, state_rf4, state_rf5		-- refresh
		);
	type state is 
		record
			state   : ctl_state;
			cmd	  : std_logic_vector (3 downto 0);
			address : std_logic_vector(12 downto 0);
			bank    : std_logic_vector(1 downto 0); 
			dq_m    : std_logic_vector(1 downto 0);	
			init_counter : integer range 0 to 150 + reset_count;
		end record;
	signal st_n : state;
	signal st_p : state := (
		state => state_pre_reset,
		cmd => cmd_nop,
		address => (others => '0'),
		bank => (others => '0'),
		dq_m => (others => '0'),
		init_counter => 150 + reset_count
	);
begin
	
	tst_act <= i_bus_cmd_act;
	
	-- pass thru mem clk
   DRAM_CS_N      <= st_p.cmd(3);
   DRAM_RAS_N     <= st_p.cmd(2);
   DRAM_CAS_N     <= st_p.cmd(1);
   DRAM_WE_N      <= st_p.cmd(0);
   DRAM_ADDR      <= st_p.address;
   DRAM_BA        <= st_p.bank;
   DRAM_DQM       <= st_p.dq_m;
		
	rdy_f : entity work.flancter 
	generic map (
		REGISTER_OUT => TRUE
	)	
	port map (
		rst_i_async	=> rst_i,
		set_i_ck		=> bus_ck,
		set_i			=> bus_cke,
		rst_i_ck		=> ck_mem,
		rst_i			=> i_bus_cmd_ack,
		flag_out		=> i_bus_cmd_act
	);	
	
	bus_latch: process (bus_D_i, bus_A_i, bus_WE_i, bus_ck, bus_cke, bus_ref, rst_i, i_bus_cmd_act) is
	begin		
		if rising_edge(bus_ck) and bus_cke = '1' then --and i_bus_cmd_act = '0' then
			i_bus_cmd.data_i <= bus_D_i;
			i_bus_cmd.addr_col <= bus_A_i(8 downto 0);
			i_bus_cmd.addr_row <= bus_A_i(21 downto 9);
			i_bus_cmd.addr_ba  <= bus_A_i(23 downto 22);
			i_bus_cmd.we_i <= bus_WE_i;
			i_bus_cmd.ref <= bus_ref;
		end if;
	end process;
	
	
	seq: process (rst_i, ck_mem, st_p, DRAM_DQ)
	begin
		if rst_i = '1' then
			st_p.state <= state_reset;
			st_p.init_counter <= 150 + reset_count;
			i_bus_cmd_ack <= '0';	
			DRAM_DQ <= (others => 'Z');
		elsif falling_edge(ck_mem) then
			DRAM_DQ <= (others => 'Z');
			st_p <= st_n;	
			i_bus_cmd_ack <= '0';
			if SIM then
				if st_p.state = state_re2 then
						bus_D_o <= DRAM_DQ(7 downto 0);								
				end if;
			else
				if st_p.state = state_re3 then
						bus_D_o <= DRAM_DQ(7 downto 0);								
				end if;
			end if;
			
			if st_n.state = state_we0 or (st_n.state = state_act_row2 and i_bus_cmd.we_i = '1') then
				DRAM_DQ(7 downto 0) <= i_bus_cmd.data_i;
				DRAM_DQ(15 downto 8) <= (others => '0');
			end if;
			
			if st_n.state = state_rf0 then
				i_bus_cmd_ack <= '1';
			elsif st_n.state = state_act_row0 then
				tst_start <= '1';
				i_bus_cmd_ack <= '1';
			else

				tst_start <= '0';
			end if;
		end if;
	end process;
	
	tst_act <= i_bus_cmd_act;
		
	com: process (i_bus_cmd, st_p, DRAM_DQ, i_bus_cmd_act) 
	begin
	
		st_n <= st_p;
		rst_o <= '0';
			
		case st_p.state is
			when state_reset =>		
				st_n.init_counter <= st_p.init_counter - 1;
				rst_o <= '1';
				-- much of the reset state is cribbed from Hamsterworks			
				st_n.state <= state_reset;
				st_n.address <= (others => '0');
				st_n.bank <= (others => '0');
				st_n.cmd <= cmd_nop;
				st_n.dq_m <= "11";
				
				-- special cycles within the reset
				if st_p.init_counter = 130 then
					-- T-130, precharge all banks
					st_n.cmd <= cmd_pre;
					st_n.address(10) <= '1';
				elsif st_p.init_counter < 128 and (st_p.init_counter mod 16 = 15) then
					-- T-127, 111, 95, 79, 63, 47, 31, 15 all start a refresh cycle
					st_n.cmd <= cmd_ref;
				elsif st_p.init_counter = 3 then
					st_n.cmd <= cmd_mrs;
					               -- Mode register is as follows:
                              -- resvd   wr_b   OpMd   CAS=3   Seq   bust=1
               st_n.address   <= "000" & "0" & "00" & "011" & "0" & "000";
                              -- resvd
               st_n.bank      <= "00";
				elsif st_p.init_counter = 1 then
					st_n.state <= state_idle;
				end if;
			when state_idle =>
				st_n.state <= state_idle;
				st_n.cmd <= cmd_nop;
				if i_bus_cmd_act = '1' then
					if i_bus_cmd.ref = '1' then
						st_n.state <= state_rf0;
						st_n.cmd <= cmd_ref;
					else
						st_n.state <= state_act_row0;
						st_n.cmd <= cmd_act;
						st_n.address <= i_bus_cmd.addr_row;
						st_n.bank <= i_bus_cmd.addr_ba;
					end if;
				end if;
			-- bank / row select ... proceed to read/write
			when state_act_row0 =>
				st_n.state <= state_act_row1;
				st_n.cmd <= cmd_nop;
			when state_act_row1 =>
				st_n.state <= state_act_row2;
				st_n.cmd <= cmd_nop;
			when state_act_row2 =>
				if i_bus_cmd.we_i = '1' then
					st_n.state <= state_we0;
					st_n.cmd <= cmd_write;
				else
					st_n.state <= state_re0;
					st_n.cmd <= cmd_read;					
				end if;
				--               A10 = 1 : auto precharge
				st_n.address <= "0010" & i_bus_cmd.addr_col;
				st_n.bank <= i_bus_cmd.addr_ba;
				st_n.dq_m <= (others => '0');
			-- read 
			when state_re0 =>
				st_n.cmd <= cmd_nop;
				st_n.state <= state_re1;
			when state_re1 =>
				st_n.cmd <= cmd_nop;
				st_n.state <= state_re2;
			when state_re2 =>
				st_n.cmd <= cmd_nop;
				st_n.state <= state_re3;		
			when state_re3 =>
				st_n.cmd <= cmd_nop;
				st_n.state <= state_idle;	
			-- write
			when state_we0 =>
				st_n.cmd <= cmd_nop;
				st_n.state <= state_we1;
			when state_we1 =>
				st_n.cmd <= cmd_nop;
				st_n.state <= state_we2;
			when state_we2 =>
				st_n.cmd <= cmd_nop;
				st_n.state <= state_idle;	
			-- refresh
			when state_rf0 =>
				st_n.cmd <= cmd_nop;
				st_n.state <= state_rf1;
			when state_rf1 =>
				st_n.cmd <= cmd_nop;
				st_n.state <= state_rf2;
			when state_rf2 =>
				st_n.cmd <= cmd_nop;
				st_n.state <= state_rf3;
			when state_rf4 =>
				st_n.cmd <= cmd_nop;
				st_n.state <= state_rf4;
			when state_rf5 =>
				st_n.cmd <= cmd_nop;
				st_n.state <= state_idle;
			when others =>
				st_n.state <= state_idle;
				st_n.cmd <= cmd_nop;							
		end case;				
				
	end process;
		
end;
