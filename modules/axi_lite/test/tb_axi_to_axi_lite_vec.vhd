-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the hdl-modules project, a collection of reusable, high-quality,
-- peer-reviewed VHDL building blocks.
-- https://hdl-modules.com
-- https://github.com/hdl-modules/hdl-modules
-- -------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

library vunit_lib;
use vunit_lib.com_pkg.net;
use vunit_lib.run_pkg.all;

library axi;
use axi.axi_pkg.all;

library common;
use common.addr_pkg.all;

library reg_file;
use reg_file.reg_file_pkg.all;
use reg_file.reg_operations_pkg.all;

library bfm;

use work.axi_lite_pkg.all;


entity tb_axi_to_axi_lite_vec is
  generic (
    pipeline_axi_lite : boolean;
    pipeline_slaves : boolean;
    runner_cfg : string
  );
end entity;

architecture tb of tb_axi_to_axi_lite_vec is

  constant base_addresses : addr_vec_t(0 to 6 - 1) := (
    0 => x"0000_0000",
    1 => x"0000_1000",
    2 => x"0000_2000",
    3 => x"0000_3000",
    4 => x"0000_4000",
    5 => x"0000_5000"
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
  constant clocks_are_the_same : boolean_vector(base_addresses'range) :=
    (0 => true, 1 => true, 2 => false, 3 => false, 4 => false, 5 => false);

  signal clk_axi : std_ulogic := '0';
  signal clk_axi_lite_vec : std_ulogic_vector(base_addresses'range) := (others => '0');

  signal axi_m2s : axi_m2s_t;
  signal axi_s2m : axi_s2m_t;

  signal axi_lite_m2s_vec : axi_lite_m2s_vec_t(base_addresses'range);
  signal axi_lite_s2m_vec : axi_lite_s2m_vec_t(base_addresses'range);

begin

  clk_axi <= not clk_axi after clk_axi_period / 2;
  clk_axi_lite_vec(0) <= not clk_axi_lite_vec(0) after clk_axi_period / 2;
  clk_axi_lite_vec(1) <= not clk_axi_lite_vec(1) after clk_axi_period / 2;
  clk_axi_lite_vec(2) <= not clk_axi_lite_vec(2) after clk_axi_lite_slow_period / 2;
  clk_axi_lite_vec(3) <= not clk_axi_lite_vec(3) after clk_axi_lite_slow_period / 2;
  clk_axi_lite_vec(4) <= not clk_axi_lite_vec(4) after clk_axi_lite_fast_period / 2;
  clk_axi_lite_vec(5) <= not clk_axi_lite_vec(5) after clk_axi_lite_fast_period / 2;

  test_runner_watchdog(runner, 100 us);


  ------------------------------------------------------------------------------
  main : process
    constant beef : std_ulogic_vector(32 - 1 downto 0) := x"beef_beef";
    constant dead : std_ulogic_vector(32 - 1 downto 0) := x"dead_dead";
  begin
    test_runner_setup(runner, runner_cfg);

    for slave_under_test_idx in base_addresses'range loop
      for slave_idx in base_addresses'range loop
        -- Write init value to all
        write_reg(net, 0, beef, base_addresses(slave_idx));
        check_reg_equal(net, 0, beef, base_addresses(slave_idx));
      end loop;

      -- Write special value to one of them
      write_reg(net, 0, dead, base_addresses(slave_under_test_idx));

      for slave_idx in base_addresses'range loop
        if slave_idx = slave_under_test_idx then
          -- Check special value
          check_reg_equal(net, 0, dead, base_addresses(slave_idx));
        else
          -- The others should still have old value
          check_reg_equal(net, 0, beef, base_addresses(slave_idx));
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
  register_maps : for slave in base_addresses'range generate
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
      base_addresses => base_addresses,
      clocks_are_the_same => clocks_are_the_same,
      pipeline_axi_lite => pipeline_axi_lite,
      pipeline_slaves => pipeline_slaves
    )
    port map (
      clk_axi => clk_axi,
      axi_m2s => axi_m2s,
      axi_s2m => axi_s2m,
      --
      clk_axi_lite_vec => clk_axi_lite_vec,
      axi_lite_m2s_vec => axi_lite_m2s_vec,
      axi_lite_s2m_vec => axi_lite_s2m_vec
    );

end architecture;
