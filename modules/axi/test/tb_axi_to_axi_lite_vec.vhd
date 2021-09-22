-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the tsfpga project.
-- https://tsfpga.com
-- https://gitlab.com/tsfpga/tsfpga
-- -------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

library vunit_lib;
context vunit_lib.vunit_context;
context vunit_lib.com_context;
context vunit_lib.vc_context;

library common;
use common.addr_pkg.all;

library reg_file;
use reg_file.reg_file_pkg.all;
use reg_file.reg_operations_pkg.all;

library axi;
use axi.axi_pkg.all;
use axi.axi_lite_pkg.all;

library bfm;


entity tb_axi_to_axi_lite_vec is
  generic (
    pipeline : boolean;
    runner_cfg : string
  );
end entity;

architecture tb of tb_axi_to_axi_lite_vec is

  constant axi_lite_slaves : addr_and_mask_vec_t(0 to 6 - 1) := (
    0 => (addr => x"0000_0000", mask => x"0000_7000"),
    1 => (addr => x"0000_1000", mask => x"0000_7000"),
    2 => (addr => x"0000_2000", mask => x"0000_7000"),
    3 => (addr => x"0000_3000", mask => x"0000_7000"),
    4 => (addr => x"0000_4000", mask => x"0000_7000"),
    5 => (addr => x"0000_5000", mask => x"0000_7000")
  );

  constant reg_map : reg_definition_vec_t(0 to 2 - 1) := (
    (idx => 0, reg_type => r_w),
    (idx => 1, reg_type => r_w)
  );

  constant clk_axi_period : time := 7 ns;
  constant clk_axi_lite_slow_period : time := 3 ns;
  constant clk_axi_lite_fast_period : time := 11 ns;

  -- Two of the slaves have same clock as axi clock. Two have a faster clock
  -- and two have a slower. Corresponds to the clock assignments further below.
  constant clocks_are_the_same : boolean_vector(axi_lite_slaves'range) :=
    (0 => true, 1 => true, 2 => false, 3 => false, 4 => false, 5 => false);

  signal clk_axi : std_logic := '0';
  signal clk_axi_lite_vec : std_logic_vector(axi_lite_slaves'range) := (others => '0');

  signal axi_m2s : axi_m2s_t;
  signal axi_s2m : axi_s2m_t;

  signal axi_lite_m2s_vec : axi_lite_m2s_vec_t(axi_lite_slaves'range);
  signal axi_lite_s2m_vec : axi_lite_s2m_vec_t(axi_lite_slaves'range);

begin

  clk_axi <= not clk_axi after clk_axi_period / 2;
  clk_axi_lite_vec(0) <= not clk_axi_lite_vec(0) after clk_axi_period / 2;
  clk_axi_lite_vec(1) <= not clk_axi_lite_vec(1) after clk_axi_period / 2;
  clk_axi_lite_vec(2) <= not clk_axi_lite_vec(2) after clk_axi_lite_slow_period / 2;
  clk_axi_lite_vec(3) <= not clk_axi_lite_vec(3) after clk_axi_lite_slow_period / 2;
  clk_axi_lite_vec(4) <= not clk_axi_lite_vec(4) after clk_axi_lite_fast_period / 2;
  clk_axi_lite_vec(5) <= not clk_axi_lite_vec(5) after clk_axi_lite_fast_period / 2;

  test_runner_watchdog(runner, 2 ms);


  ------------------------------------------------------------------------------
  main : process
    constant beef : std_logic_vector(32 - 1 downto 0) := x"beef_beef";
    constant dead : std_logic_vector(32 - 1 downto 0) := x"dead_dead";
  begin
    test_runner_setup(runner, runner_cfg);

    for slave_under_test_idx in axi_lite_slaves'range loop
      for slave_idx in axi_lite_slaves'range loop
        -- Write init value to all
        write_reg(net, 0, beef, axi_lite_slaves(slave_idx).addr);
        check_reg_equal(net, 0, beef, axi_lite_slaves(slave_idx).addr);
      end loop;

      -- Write special value to one of them
      write_reg(net, 0, dead, axi_lite_slaves(slave_under_test_idx).addr);

      for slave_idx in axi_lite_slaves'range loop
        if slave_idx = slave_under_test_idx then
          -- Check special value
          check_reg_equal(net, 0, dead, axi_lite_slaves(slave_idx).addr);
        else
          -- The others should still have old value
          check_reg_equal(net, 0, beef, axi_lite_slaves(slave_idx).addr);
        end if;
      end loop;
    end loop;

    test_runner_cleanup(runner);
  end process;


  ------------------------------------------------------------------------------
  axi_master_inst : entity bfm.axi_master
    generic map (
      bus_handle => regs_bus_master
    )
    port map (
      clk => clk_axi,

      axi_read_m2s => axi_m2s.read,
      axi_read_s2m => axi_s2m.read,

      axi_write_m2s => axi_m2s.write,
      axi_write_s2m => axi_s2m.write
    );


  ------------------------------------------------------------------------------
  register_maps : for slave in axi_lite_slaves'range generate
    axi_lite_reg_file_inst : entity reg_file.axi_lite_reg_file
    generic map (
      regs => reg_map
    )
    port map (
      clk => clk_axi_lite_vec(slave),

      axi_lite_m2s => axi_lite_m2s_vec(slave),
      axi_lite_s2m => axi_lite_s2m_vec(slave)
    );
  end generate;


  ------------------------------------------------------------------------------
  dut : entity work.axi_to_axi_lite_vec
  generic map (
    axi_lite_slaves => axi_lite_slaves,
    clocks_are_the_same => clocks_are_the_same,
    pipeline => pipeline,
    data_width => reg_width
  )
  port map (
    clk_axi => clk_axi,
    axi_m2s => axi_m2s,
    axi_s2m => axi_s2m,

    clk_axi_lite_vec => clk_axi_lite_vec,
    axi_lite_m2s_vec => axi_lite_m2s_vec,
    axi_lite_s2m_vec => axi_lite_s2m_vec
  );

end architecture;
