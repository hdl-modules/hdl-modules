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

use work.register_file_pkg.all;
use work.register_operations_pkg.all;


entity tb_trail_register_file is
  generic (
    runner_cfg : string
  );
end entity;

architecture tb of tb_trail_register_file is

  -- Generic constants.
  constant registers : register_definition_vec_t(0 to 15 - 1) := (
    (index => 0, mode => r, utilized_width=>32),
    (index => 1, mode => r, utilized_width=>32),
    (index => 2, mode => r, utilized_width=>32),
    (index => 3, mode => w, utilized_width=>32),
    (index => 4, mode => w, utilized_width=>32),
    (index => 5, mode => w, utilized_width=>32),
    (index => 6, mode => r_w, utilized_width=>32),
    (index => 7, mode => r_w, utilized_width=>32),
    (index => 8, mode => r_w, utilized_width=>32),
    (index => 9, mode => wpulse, utilized_width=>32),
    (index => 10, mode => wpulse, utilized_width=>32),
    (index => 11, mode => wpulse, utilized_width=>32),
    (index => 12, mode => r_wpulse, utilized_width=>32),
    (index => 13, mode => r_wpulse, utilized_width=>32),
    (index => 14, mode => r_wpulse, utilized_width=>32)
  );

  constant default_values : register_vec_t(registers'range) := (
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

  signal regs_up, regs_down : register_vec_t(registers'range) := (others => (others => '0'));
  signal reg_was_read, reg_was_written : std_ulogic_vector(registers'range);

  -- Testbench stuff.
  constant reg_was_accessed_zero : std_ulogic_vector(reg_was_written'range) := (others => '0');

  signal regs_down_non_default_count : natural := 0;

begin

  test_runner_watchdog(runner, 2 ms);
  clk <= not clk after clk_period / 2;


  ------------------------------------------------------------------------------
  main : process
    variable rnd : RandomPType;

    variable hardware_data, software_data : register_vec_t(0 to registers'length - 1);

    -- TODO unify with tb_axi_lite_reg_file
    procedure reg_stimuli(reg : register_definition_t) is
    begin
      if is_write_mode(reg.mode) then
        write_reg(net=>net, reg_index=>reg.index, value=>software_data(reg.index));
      end if;

      if is_application_gives_value_mode(reg.mode) then
        regs_up(reg.index) <= hardware_data(reg.index);
      end if;
    end procedure;

    procedure reg_data_check(reg : register_definition_t) is
      variable reg_was_accessed_expected : std_ulogic_vector(reg_was_written'range) := (
        others => '0'
      );
      variable read_bus_reference : bus_reference_t;
      variable read_bus_data : register_t := (others => '0');
    begin
      reg_was_accessed_expected(reg.index) := '1';

      if is_write_mode(reg.mode) then
        wait_for_write_to_go_through : while true loop
          if is_write_pulse_mode(reg.mode) then
            -- The value that fabric gets should be default all cycles except the one where the
            -- write happens
            check_equal(regs_down(reg.index), default_values(reg.index));
          end if;

          wait until rising_edge(clk);
          if reg_was_written /= reg_was_accessed_zero then
            check_equal(reg_was_written, reg_was_accessed_expected);
            exit wait_for_write_to_go_through;
          end if;
        end loop;

        check_equal(regs_down(reg.index), software_data(reg.index));
      end if;

      if is_write_pulse_mode(reg.mode) then
        wait until rising_edge(clk);
        -- The value that fabric gets should be default all cycles except the one where the
        -- write happens
        check_equal(regs_down(reg.index), default_values(reg.index));
      end if;

      if is_read_mode(reg.mode) then
        -- Initiate a non-blocking read
        read_bus(
          net=>net,
          bus_handle=>register_bus_master,
          address=>4 * reg.index, reference=>read_bus_reference
        );

        wait until reg_was_read /= reg_was_accessed_zero and rising_edge(clk);
        check_equal(reg_was_read, reg_was_accessed_expected);

        await_read_bus_reply(net=>net, reference=>read_bus_reference, data=>read_bus_data);

        if is_application_gives_value_mode(reg.mode) then
          check_equal(read_bus_data, hardware_data(reg.index));
        else
          check_equal(read_bus_data, software_data(reg.index));
        end if;
      end if;
    end procedure;

  begin
    test_runner_setup(runner, runner_cfg);
    rnd.InitSeed(get_string_seed(runner_cfg));

    if run("test_default_values") then
      wait until regs_down /= default_values or trail_response.enable = '1' for 100 * clk_period;

      assert regs_down = default_values;
      assert not trail_response.enable;

    elsif run("test_random_read_and_write") then
      -- TODO loop?

      for list_idx in registers'range loop
        hardware_data(list_idx) := rnd.RandSLV(hardware_data(0)'length);
        software_data(list_idx) := rnd.RandSLV(software_data(0)'length);
      end loop;

      for list_idx in registers'range loop
        reg_stimuli(registers(list_idx));
        reg_data_check(registers(list_idx));
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
  dut : entity work.trail_register_file
    generic map (
      registers => registers,
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
