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
use ieee.numeric_std.all;

library vunit_lib;
use vunit_lib.bus_master_pkg.all;
use vunit_lib.check_pkg.all;
use vunit_lib.com_pkg.net;
use vunit_lib.run_pkg.all;

library osvvm;
use osvvm.RandomPkg.RandomPType;

library common;
use common.addr_pkg.all;
use common.types_pkg.all;

library trail;
use trail.trail_pkg.all;

use work.reg_file_pkg.all;
use work.reg_operations_pkg.all;


entity tb_trail_reg_file is
  generic (
    seed : natural;
    runner_cfg : string
  );
end entity;

architecture tb of tb_trail_reg_file is

  -- Generic constants.
  constant regs : reg_definition_vec_t(0 to 15 - 1) := (
    (idx => 0, reg_type => r),
    (idx => 1, reg_type => r),
    (idx => 2, reg_type => r),
    (idx => 3, reg_type => w),
    (idx => 4, reg_type => w),
    (idx => 5, reg_type => w),
    (idx => 6, reg_type => r_w),
    (idx => 7, reg_type => r_w),
    (idx => 8, reg_type => r_w),
    (idx => 9, reg_type => wpulse),
    (idx => 10, reg_type => wpulse),
    (idx => 11, reg_type => wpulse),
    (idx => 12, reg_type => r_wpulse),
    (idx => 13, reg_type => r_wpulse),
    (idx => 14, reg_type => r_wpulse)
  );

  constant default_values : reg_vec_t(regs'range) := (
    0 => x"dcd3e0e6",
    1 => x"323e4bfd",
    2 => x"7ddd475b",
    3 => x"0c4c3891",
    4 => x"cb40a113",
    5 => x"f8c6f339",
    6 => x"a17f0a63",
    7 => x"333665c6",
    8 => x"136f6857",
    9 => x"9901a7d0",
    10 => x"45974c0b",
    11 => x"067b0394",
    12 => x"c5b5d0fc",
    13 => x"86130210",
    14 => x"ad1f5653"
  );

  -- DUT connections.
  constant clk_period : time := 10 ns;
  signal clk : std_ulogic := '0';

  signal trail_operation : trail_operation_t := trail_operation_init;
  signal trail_response : trail_response_t := trail_response_init;

  signal regs_up, regs_down : reg_vec_t(regs'range) := (others => (others => '0'));
  signal reg_was_read, reg_was_written : std_ulogic_vector(regs'range);

  -- Testbench stuff.
  constant reg_was_accessed_zero : std_ulogic_vector(reg_was_written'range) := (others => '0');

  signal regs_down_non_default_count : natural := 0;

begin

  test_runner_watchdog(runner, 2 ms);
  clk <= not clk after clk_period / 2;


  ------------------------------------------------------------------------------
  main : process
    variable rnd : RandomPType;

    variable hardware_data, software_data : reg_vec_t(0 to regs'length - 1);

    -- TODO unify with tb_axi_lite_reg_file
    procedure reg_stimuli(reg : reg_definition_t) is
    begin
      if is_write_type(reg.reg_type) then
        write_reg(net=>net, reg_index=>reg.idx, value=>software_data(reg.idx));
      end if;

      if is_fabric_gives_value_type(reg.reg_type) then
        regs_up(reg.idx) <= hardware_data(reg.idx);
      end if;
    end procedure;

    procedure reg_data_check(reg : reg_definition_t) is
      variable reg_was_accessed_expected : std_ulogic_vector(reg_was_written'range) := (
        others => '0'
      );
      variable read_bus_reference : bus_reference_t;
      variable read_bus_data : reg_t;
    begin
      reg_was_accessed_expected(reg.idx) := '1';

      if is_write_type(reg.reg_type) then
        wait_for_write_to_go_through : while true loop
          if is_write_pulse_type(reg.reg_type) then
            -- The value that fabric gets should be default all cycles except the one where the
            -- write happens
            check_equal(regs_down(reg.idx), default_values(reg.idx));
          end if;

          wait until rising_edge(clk);
          if reg_was_written /= reg_was_accessed_zero then
            check_equal(reg_was_written, reg_was_accessed_expected);
            exit wait_for_write_to_go_through;
          end if;
        end loop;

        check_equal(regs_down(reg.idx), software_data(reg.idx));
      end if;

      if is_write_pulse_type(reg.reg_type) then
        wait until rising_edge(clk);
        -- The value that fabric gets should be default all cycles except the one where the
        -- write happens
        check_equal(regs_down(reg.idx), default_values(reg.idx));
      end if;

      if is_read_type(reg.reg_type) then
        -- Initiate a non-blocking read
        read_bus(
          net=>net, bus_handle=>regs_bus_master, address=>4 * reg.idx, reference=>read_bus_reference
        );

        wait until reg_was_read /= reg_was_accessed_zero and rising_edge(clk);
        check_equal(reg_was_read, reg_was_accessed_expected);

        await_read_bus_reply(net=>net, reference=>read_bus_reference, data=>read_bus_data);

        if is_fabric_gives_value_type(reg.reg_type) then
          check_equal(read_bus_data, hardware_data(reg.idx));
        else
          check_equal(read_bus_data, software_data(reg.idx));
        end if;
      end if;
    end procedure;

  begin
    test_runner_setup(runner, runner_cfg);
    rnd.InitSeed(seed);

    if run("test_default_values") then
      wait until regs_down /= default_values or trail_response.enable = '1' for 100 * clk_period;

      assert regs_down = default_values;
      assert not trail_response.enable;

    elsif run("test_random_read_and_write") then
      -- TODO loop?

      for list_idx in regs'range loop
        hardware_data(list_idx) := rnd.RandSLV(hardware_data(0)'length);
        software_data(list_idx) := rnd.RandSLV(software_data(0)'length);
      end loop;

      for list_idx in regs'range loop
        reg_stimuli(regs(list_idx));
        reg_data_check(regs(list_idx));
      end loop;

    end if;

    -- TODO test out of range. With expected resp in axi-lite bus message.

    test_runner_cleanup(runner);
  end process;


  ------------------------------------------------------------------------------
  count_status : process
  begin
    wait until rising_edge(clk);

    regs_down_non_default_count <= (
      regs_down_non_default_count + to_int(regs_down /= default_values)
    );
  end process;


  ------------------------------------------------------------------------------
  trail_bfm_master_inst : entity trail.trail_bfm_master_old
    port map (
      clk => clk,
      --
      trail_operation => trail_operation,
      trail_response => trail_response
    );


  ------------------------------------------------------------------------------
  dut : entity work.trail_reg_file
    generic map (
      regs => regs,
      default_values => default_values
    )
    port map (
      clk => clk,
      --
      trail_operation => trail_operation,
      trail_response => trail_response,
      --
      regs_up => regs_up,
      regs_down => regs_down,
      --
      reg_was_read => reg_was_read,
      reg_was_written => reg_was_written
    );

end architecture;
