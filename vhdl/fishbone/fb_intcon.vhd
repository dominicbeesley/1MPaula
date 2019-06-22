library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.fishbone.all;

entity fb_intcon is
	generic (
		G_MASTER_COUNT		: POSITIVE;
		G_SLAVE_COUNT		: POSITIVE
	);
	port (

		fb_syscon_i				: in	fb_syscon_t;

		-- slave port connect to masters
		fb_mas_m2s_i			: in	fb_mas_o_sla_i_arr(G_MASTER_COUNT-1 downto 0);
		fb_mas_s2m_o			: out	fb_mas_i_sla_o_arr(G_MASTER_COUNT-1 downto 0);

		-- master port connecto to slaves
		fb_sla_m2s_o			: out fb_mas_o_sla_i_arr(G_SLAVE_COUNT-1 downto 0);
		fb_sla_s2m_i			: in 	fb_mas_i_sla_o_arr(G_SLAVE_COUNT-1 downto 0);


		-- the addresses to be mapped
		map_addr_to_map_o		: out	fb_std_logic_2d(G_MASTER_COUNT-1 downto 0, 23 downto 0);	
		-- clken for address mapping - once per cycle
		map_addr_clken_o		: out	std_logic_vector(G_MASTER_COUNT-1 downto 0);			
		-- clken for address mapping clear - once per cycle
		map_addr_clr_clken_o	: out	std_logic_vector(G_MASTER_COUNT-1 downto 0);			
		-- possibly translated address
		map_addr_mapped_i		: in	fb_std_logic_2d(G_MASTER_COUNT-1 downto 0, 23 downto 0);					
		-- one hots with a single bit set
		-- for the selected slave
		map_slave_sel_oh_i	: in	fb_std_logic_2d(G_MASTER_COUNT-1 downto 0, G_SLAVE_COUNT-1 downto 0)


	);
end fb_intcon;


architecture rtl of fb_intcon is

	function ALLZERO(a:std_logic_vector) return boolean is
	variable ret:boolean;
	begin
		ret := true;
		for I in a'range loop
			if a(I) /= '0' then
				ret := false;
			end if;
		end loop;
		return ret;
	end function;

	function ANY(a:std_logic_vector) return boolean is
	variable ret:boolean;
	begin
		ret := false;
		for I in a'range loop
			if a(I) = '1' then
				ret := true;
			end if;
		end loop;
		return ret;
	end function;


	type		state_t is (idle, addrmatch, slaveprior, contend, sel, act, fin);

	type		state_arr is array(G_MASTER_COUNT-1 downto 0) of state_t;


	-- note for the signals marked one-hot they may all be 0 hot i.e. either one bit in the bitmask
	-- will be selected or none

	signal	r_state						: state_arr;												-- state machine state for each master
	signal	r_slave_busy				: std_logic_vector(G_SLAVE_COUNT-1 downto 0);	-- slave is marked busy until ack once selected

	signal	r_marr_oh_slave_sel2		: fb_std_logic_2d(G_MASTER_COUNT-1 downto 0, G_SLAVE_COUNT-1 downto 0);
																												-- for each master a one-hot of the currently 
																												--  selected slave 

	signal   r_fb_mas_s2m				: fb_mas_i_sla_o_arr(G_MASTER_COUNT-1 downto 0);-- slave signals back to each master
	signal   i_contend_slave			: std_logic_vector(G_MASTER_COUNT-1 downto 0);	-- for each master a the required slace iscontended
																												-- by master(s) with higher priority
	signal 	i_map_addr_to_map			: fb_std_logic_2d(G_MASTER_COUNT-1 downto 0, 23 downto 0);																												

	signal clk : std_logic;
	signal rst : std_logic;

begin

	-- this may seem unnecessary but ISIM mucks up the state machines
	-- if the clock signal comes from a record.
	clk <= fb_syscon_i.clk;
	rst <= fb_syscon_i.rst;

	map_addr_to_map_o <= i_map_addr_to_map;

	p_addrmap:process(fb_mas_m2s_i)
	begin
		for M in G_MASTER_COUNT-1 downto 0 loop
			for B in 23 downto 0 loop
				i_map_addr_to_map(M, B) <= fb_mas_m2s_i(M).A(B);
			end loop;
		end loop;
	end process;

	p_contend_slave:process(map_slave_sel_oh_i)
	variable v_contend_slave: std_logic_vector(G_SLAVE_COUNT-1 downto 0);
	begin

			-- this is shared between all masters
			v_contend_slave := (others => '0');
			i_contend_slave <= (others => '0');
			for M in G_MASTER_COUNT-1 downto 0 loop
				for S in G_SLAVE_COUNT-1 downto 0 loop
					if (map_slave_sel_oh_i(M, S) and v_contend_slave(S)) = '1' then
						i_contend_slave(M) <= '1';
					end if;					
				end loop;
				for S in G_SLAVE_COUNT-1 downto 0 loop
					v_contend_slave(S) := v_contend_slave(S) or map_slave_sel_oh_i(M, S);
				end loop;
			end loop;

	end process;

	-- per master state machine
	p_sel: process(rst, clk)
	variable v_tmp : boolean;
	begin


		if rst = '1' then
			for M in G_MASTER_COUNT-1 downto 0 loop
				-- for each master run this process
				r_state(M) <= idle;
				r_slave_busy <= (others => '0');
				map_addr_clken_o(M) <= '0';
				map_addr_clr_clken_o(M) <= '0';
				for S in G_SLAVE_COUNT-1 downto 0 loop
					r_marr_oh_slave_sel2(M,S) <= '0';
				end loop;
			end loop;
		else
			if rising_edge(clk) then

				for M in G_MASTER_COUNT-1 downto 0 loop
					-- for each master run this process

					map_addr_clken_o(M) <= '0';
					map_addr_clr_clken_o(M) <= '0';
					case r_state(M) is
						when idle =>
							if fb_mas_m2s_i(M).cyc = '1' and fb_mas_m2s_i(M).A_stb = '1' then
								r_state(M) <= addrmatch;
								map_addr_clken_o(M) <= '1';
							end if;
						when addrmatch =>
							r_state(M) <= sel;
						when sel =>
							v_tmp := true;
							for S in G_SLAVE_COUNT-1 downto 0 loop
								r_marr_oh_slave_sel2(M, S) <= map_slave_sel_oh_i(M, S);
								if map_slave_sel_oh_i(M, S) = '1' then
									v_tmp := false;
								end if;
							end loop;
							if v_tmp then
								-- no slave matched do a dummy cyle!
								r_state(M) <= act;
							elsif i_contend_slave(M) = '0' then
								for i in G_SLAVE_COUNT-1 downto 0 loop
									if r_slave_busy(I) = '0' and map_slave_sel_oh_i(M, I) = '1' then
										r_slave_busy(I) <= '1';
										r_state(M) <= act;
									end if;
								end loop;
							end if;
						when act =>
							if fb_mas_m2s_i(M).cyc = '0' then
								r_state(M) <= fin;
								for I in G_SLAVE_COUNT-1 downto 0 loop
									if r_marr_oh_slave_sel2(M, I) = '1' then
										r_slave_busy(I) <= '0';
									end if;
								end loop;
								for I in G_SLAVE_COUNT-1 downto 0 loop
									r_marr_oh_slave_sel2(M, I) <= '0';
								end loop;
							end if;
						when fin =>
							map_addr_clr_clken_o(M) <= '1';
							r_state(M) <= idle;
						when others =>
							map_addr_clr_clken_o(M) <= '1';
							r_state(M) <= idle;
					end case;
				end loop;
			end if;
		end if;
	end process;

	p_mas2slv_crossbar:process(clk)
	begin
		if rising_edge(clk) then
			g_addr: for I in G_SLAVE_COUNT-1 downto 0 loop
				fb_sla_m2s_o(I).cyc_speed <= fb_m2s_unsel.cyc_speed;
				fb_sla_m2s_o(I).cyc <= fb_m2s_unsel.cyc;
				fb_sla_m2s_o(I).we <= fb_m2s_unsel.we;
				fb_sla_m2s_o(I).A <= fb_m2s_unsel.A;
				fb_sla_m2s_o(I).A_stb <= fb_m2s_unsel.A_stb;
				fb_sla_m2s_o(I).D_wr <= fb_m2s_unsel.D_wr;
				fb_sla_m2s_o(I).D_wr_stb <= fb_m2s_unsel.D_wr_stb;
				g_addr_m: for M in G_MASTER_COUNT-1 downto 0 loop
					if r_marr_oh_slave_sel2(M, I) = '1' and r_state(M) = act then
						fb_sla_m2s_o(I).cyc_speed <= fb_mas_m2s_i(M).cyc_speed;
						fb_sla_m2s_o(I).cyc <= fb_mas_m2s_i(M).cyc;
						fb_sla_m2s_o(I).we <= fb_mas_m2s_i(M).we;
						for B in 23 downto 0 loop
							fb_sla_m2s_o(I).A(B) <= map_addr_mapped_i(M, B);
						end loop;																					 	
						fb_sla_m2s_o(I).A_stb <= fb_mas_m2s_i(M).A_stb;
						fb_sla_m2s_o(I).D_wr <= fb_mas_m2s_i(M).D_wr;
						fb_sla_m2s_o(I).D_wr_stb <= fb_mas_m2s_i(M).D_wr_stb;
					end if;
				end loop;
			end loop;
		end if;
	end process;

	fb_mas_s2m_o <= r_fb_mas_s2m;

	p_s2m:process(rst, clk)
	begin

		if rst = '1' then
			g_addr_m_rst: for M in G_MASTER_COUNT-1 downto 0 loop
				r_fb_mas_s2m(M) <=
				(
					D_rd => (others => '1'),
					rdy => '0',
					ack => '0',
					nul => '0'
				);
			end loop;
		elsif rising_edge(clk) then
			g_addr_m: for M in G_MASTER_COUNT-1 downto 0 loop
				-- default / unmatched states
				if (r_state(M) = act) then
					r_fb_mas_s2m(M) <=
					(
						D_rd => (others => '1'),
						rdy => '1',
						nul => '1',
						ack => fb_syscon_i.cpu_clks(FB_CPUCLKINDEX(fb_mas_m2s_i(M).cyc_speed)).cpu_clken
					);
					for I in G_SLAVE_COUNT-1 downto 0 loop
						if r_marr_oh_slave_sel2(M, I) = '1' then
							r_fb_mas_s2m(M) <= fb_sla_s2m_i(I);
						end if;
					end loop;
				else
					r_fb_mas_s2m(M) <=
					(
						D_rd => (others => '1'),
						rdy => '0',
						ack => '0',
						nul => '0'
					);
				end if;
			end loop;
		end if;
	end process;

end rtl;