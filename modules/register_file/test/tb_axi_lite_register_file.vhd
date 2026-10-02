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
use vunit_lib.check_pkg.all;
use vunit_lib.com_pkg.net;
use vunit_lib.run_pkg.all;

library osvvm;
use osvvm.RandomPkg.RandomPType;

library bfm;
use bfm.axi_lite_bfm_pkg.all;

library common;
use common.types_pkg.all;

library axi_lite;
use axi_lite.axi_lite_pkg.all;

use work.register_file_pkg.all;


entity tb_axi_lite_register_file is
  generic (
    runner_cfg : string
  );
end entity;

architecture tb of tb_axi_lite_register_file is

  -- Generic constants.
  shared variable rnd : RandomPType;

  impure function initialize_and_get_regs return register_definition_vec_t is
    impure function initialize_and_get_num_registers return positive is
    begin
      -- This is the first function that is called, so we initialize the random number
      -- generator here.
      rnd.InitSeed(get_string_seed(runner_cfg));

      -- We do some 'num_bits_needed' calculations in the DUT, so it is important that we test
      -- just below and above a power-of-two boundary.
      return rnd.Uniform(12, 34);
    end function;
    constant num_registers : positive := initialize_and_get_num_registers;

    variable result : register_definition_vec_t(0 to num_registers - 1);

    procedure set(index: natural; mode : register_mode_t) is
      variable max_utilized_width, utilized_width : natural := 32;
    begin
      if mode = wmasked then
        max_utilized_width := masked_register_value_width;
      end if;

      if index = 3 or index = 4 then
        -- Hard coded for the 'reset_write' test.
        utilized_width := result(2).utilized_width;
      elsif index = 5 or index = 6 then
        -- Hard coded for the 'reset_read' test.
        utilized_width := result(4).utilized_width;
      else
        -- Fully random.
        utilized_width := rnd.RandInt(max_utilized_width);
      end if;

      result(index) := (index=>index, mode=>mode, utilized_width=>utilized_width);
    end procedure;
  begin
    for index in 0 to num_registers - 1 loop
      -- A few indexes are hardcoded in some tests below.
      if index < 2 then
        set(index=>index, mode=>r);
      elsif index < 4 then
        set(index=>index, mode=>w);
      elsif index < 6 then
        set(index=>index, mode=>r_w);
      elsif index < 8 then
        set(index=>index, mode=>wpulse);
      elsif index < 10 then
        set(index=>index, mode=>wmasked);
      else
        set(
          index=>index,
          mode=>register_mode_t'val(rnd.RandInt(register_mode_t'pos(register_mode_t'high)))
        );
      end if;
    end loop;

    return result;
  end function;
  constant regs : register_definition_vec_t := initialize_and_get_regs;

  impure function get_random_register_value(
    reg : register_definition_t; set_masked_mask : boolean := true
  ) return register_t is
    variable result : register_t := (others => '0');
  begin
    for bit_index in 0 to reg.utilized_width - 1 loop
      result(bit_index) := to_sl(rnd.RandBool);
    end loop;

    if reg.mode = wmasked and set_masked_mask then
      for payload_index in masked_payload_range loop
        result(masked_mask_index(payload_index=>payload_index)) := to_sl(rnd.RandBool);
      end loop;
    end if;

    return result;
  end function;

  impure function get_default_values return register_vec_t is
    variable result : register_vec_t(regs'range) := (others => (others => '0'));
  begin
    for index in regs'range loop
      result(index) := get_random_register_value(regs(index), set_masked_mask=>false);
    end loop;

    return result;
  end function;
  constant default_values : register_vec_t := get_default_values;

  -- DUT connections.
  constant clk_period : time := 10 ns;
  signal clk, reset : std_ulogic := '0';

  signal axi_lite_m2s : axi_lite_m2s_t := axi_lite_m2s_init;
  signal axi_lite_s2m : axi_lite_s2m_t := axi_lite_s2m_init;

  signal regs_down, regs_up : register_vec_t(regs'range) := default_values;
  signal reg_was_read, reg_was_written : std_ulogic_vector(regs'range);

  -- Testbench stuff.
  constant reg_was_accessed_zero : std_ulogic_vector(reg_was_written'range) := (others => '0');

  signal regs_down_non_default_count : natural := 0;

begin

  test_runner_watchdog(runner, 100 us);
  clk <= not clk after clk_period / 2;


  ------------------------------------------------------------------------------
  main : process
    variable fabric_values, bus_values : register_vec_t(0 to regs'length - 1) := (
      others => (others => '0')
    );

    procedure reg_stimuli(reg : register_definition_t) is
    begin
      if is_write_mode(reg.mode) then
        write_bfm(net=>net, index=>reg.index, data=>bus_values(reg.index));
      end if;

      if is_application_gives_value_mode(reg.mode) then
        regs_up(reg.index) <= fabric_values(reg.index);
      end if;
    end procedure;

    procedure reg_data_check(reg : register_definition_t) is
      variable reg_was_accessed_expected : std_ulogic_vector(reg_was_written'range) := (
        others => '0'
      );
      variable mask_index : masked_mask_range := masked_mask_range'low;
      variable expected_payload : std_ulogic := '0';
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

        if reg.mode = wmasked then
          for payload_index in masked_payload_range loop
            mask_index := masked_mask_index(payload_index=>payload_index);
            expected_payload := bus_values(reg.index)(payload_index)
              when bus_values(reg.index)(mask_index)
              else default_values(reg.index)(payload_index);

            check_equal(
              regs_down(reg.index)(payload_index),
              expected_payload,
              (
                "reg.index = " & to_string(reg.index)
                & ", payload_index = " & to_string(payload_index)
                & ", mask_index = " & to_string(mask_index)
                & ", mask = " & to_string(bus_values(reg.index)(mask_index))
              )
            );
          end loop;
          for mask_check_index in masked_mask_range loop
            check_equal(
              regs_down(reg.index)(mask_check_index),
              '0',
              (
                "reg.index = " & to_string(reg.index)
                & ", mask_check_index = " & to_string(mask_check_index)
              )
            );
          end loop;

        else
          -- Regular write mode, e.g. 'w'.
          check_equal(
            regs_down(reg.index), bus_values(reg.index), "index = " & to_string(reg.index)
          );
        end if;
      end if;

      if is_write_pulse_mode(reg.mode) then
        wait until rising_edge(clk);
        -- The value that fabric gets should be default all cycles except the one where the
        -- write happens
        check_equal(regs_down(reg.index), default_values(reg.index));
      end if;

      if is_read_mode(reg.mode) then
        if is_application_gives_value_mode(reg.mode) then
          check_bfm(net=>net, index=>reg.index, data=>fabric_values(reg.index));
        else
          check_bfm(net=>net, index=>reg.index, data=>bus_values(reg.index));
        end if;

        wait until reg_was_read /= reg_was_accessed_zero and rising_edge(clk);
        check_equal(reg_was_read, reg_was_accessed_expected);
      end if;
    end procedure;

    variable register_value : register_t := (others => '0');

  begin
    test_runner_setup(runner, runner_cfg);

    for list_index in regs'range loop
      report (
        to_string(list_index)
        & ": " & to_string(regs(list_index).mode)
        & " "
        & to_string(regs(list_index).utilized_width)
      );

      fabric_values(list_index) := get_random_register_value(regs(list_index));
      bus_values(list_index) := get_random_register_value(regs(list_index));
    end loop;
    regs_up <= fabric_values;

    if run("test_default_register_values") then
      wait for 10 * clk_period;

      check_equal(regs_down_non_default_count, 0);

    elsif run("test_random_write_then_read") then
      for list_index in regs'range loop
        reg_stimuli(regs(list_index));
        reg_data_check(regs(list_index));
      end loop;

    elsif run("test_wmasked_hard_coded") then
      -- Complement to the general tests above.
      assert regs(8).mode = wmasked;
      check_equal(regs_down(8), default_values(8));

      -- Width is randomized for the general tests.
      -- Easiest to just skip this test when not possible to run.
      -- Will run most of the time except for a few corner cases.
      if regs(8).utilized_width > 2 then
        register_value(2) := '1';
        register_value(18) := '1';
        write_await_bfm(net=>net, index=>8, data=>register_value);
        check_equal(regs_down(8)(2), '1');

        register_value(2) := '0';
        register_value(18) := '0';
        write_await_bfm(net=>net, index=>8, data=>register_value);
        -- Should not have changed the value.
        check_equal(regs_down(8)(2), '1');
      end if;

    elsif run("test_read_back_to_back") then
      for index in regs'range loop
        if regs(index).mode = r or regs(index).mode = r_wpulse then
          check_bfm(net=>net, index=>index, data=>fabric_values(index));
        elsif regs(index).mode = r_w then
          check_bfm(net=>net, index=>index, data=>default_values(index));
        end if;
      end loop;

    elsif run("test_write_back_to_back") then
      for index in regs'range loop
        if is_write_mode(regs(index).mode) then
          write_bfm(net=>net, index=>index, data=>bus_values(index));
        end if;
      end loop;

    elsif run("test_read_outside_of_utilized_width_is_zero") then
      assert regs(0).mode = r;

      -- Width is randomized for the general tests.
      -- Easiest to just skip this test when not possible to run.
      -- Will run most of the time except for a few corner cases.
      if regs(0).utilized_width < 32 then
        regs_up(0) <= (31 => '1', others => '0');
        check_bfm(net=>net, index=>0, data=>(others => '0'));
      end if;

    elsif run("test_write_outside_of_utilized_width_is_zero") then
      assert regs(2).mode = w;

      -- Width is randomized for the general tests.
      -- Easiest to just skip this test when not possible to run.
      -- Will run most of the time except for a few corner cases.
      if regs(2).utilized_width < 32 then
        write_await_bfm(net=>net, index=>2, data=>(31 => '1', others => '0'));
        check_equal(regs_down(2), 0);
      end if;

    elsif run("test_read_from_non_existent_register") then
      check_bfm(
        net=>net, index=>regs'high + 1, data=>fabric_values(0), response=>axi_lite_resp_slverr
      );
      check_bfm(net=>net, index=>0, data=>fabric_values(0));

    elsif run("test_write_to_non_existent_register") then
      write_bfm(
        net=>net, index=>regs'length, data=>bus_values(regs'high), response=>axi_lite_resp_slverr
      );
      write_bfm(net=>net, index=>3, data=>bus_values(regs'high));

    elsif run("test_read_from_w_mode_register") then
      assert regs(2).mode = w;
      check_bfm(net=>net, index=>2, data=>default_values(2), response=>axi_lite_resp_slverr);
      check_bfm(net=>net, index=>0, data=>fabric_values(0));

    elsif run("test_read_from_wpulse_mode_register") then
      assert regs(6).mode = wpulse;
      check_bfm(net=>net, index=>6, data=>default_values(6), response=>axi_lite_resp_slverr);
      check_bfm(net=>net, index=>0, data=>fabric_values(0));

    elsif run("test_read_from_wmasked_mode_register") then
      assert regs(8).mode = wmasked;
      check_bfm(net=>net, index=>8, data=>default_values(8), response=>axi_lite_resp_slverr);
      check_bfm(net=>net, index=>0, data=>fabric_values(0));

    elsif run("test_write_to_r_mode_register") then
      assert regs(0).mode = r;
      write_bfm(net=>net, index=>0, data=>default_values(0), response=>axi_lite_resp_slverr);
      write_bfm(net=>net, index=>2, data=>default_values(2));

    elsif run("test_reset_read") then
      for index in 4 to 5 loop
        assert regs(index).mode = r_w;
        check_await_bfm(net=>net, index=>index, data=>default_values(index));

        for wait_cycles in 0 to 20 loop
          write_await_bfm(net=>net, index=>index, data=>bus_values(index + 1));
          check_await_bfm(net=>net, index=>index, data=>bus_values(index + 1));

          check_bfm(net=>net, index=>index, data=>bus_values(index + 1));
          for wait_cycle_idx in 1 to wait_cycles loop
            wait until rising_edge(clk);
          end loop;
          reset <= '1';

          for reset_cycle in 0 to 10 loop
            wait until rising_edge(clk);
          end loop;

          reset <= '0';
          wait until rising_edge(clk);
          check_await_bfm(net=>net, index=>index, data=>default_values(index));
        end loop;
      end loop;

    elsif run("test_reset_write") then
      for index in 2 to 3 loop
        assert regs(index).mode = w;

        for wait_cycles in 0 to 20 loop
          check_equal(regs_down(index), default_values(index));

          write_await_bfm(net=>net, index=>index, data=>default_values(index + 1));
          check_equal(regs_down(index), default_values(index + 1));

          write_bfm(net=>net, index=>index, data=>default_values(index + 1));
          for wait_cycle_idx in 1 to wait_cycles loop
            wait until rising_edge(clk);
          end loop;
          reset <= '1';

          for reset_cycle in 0 to 10 loop
            wait until rising_edge(clk);
          end loop;

          reset <= '0';
          wait until rising_edge(clk);
          check_equal(
            regs_down(index),
            default_values(index),
            "index=" & to_string(index) & " wait_cycles=" & to_string(wait_cycles)
          );
        end loop;
      end loop;

    end if;

    wait_until_bfm_idle(net=>net);

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
  axi_lite_master_bfm_inst : entity bfm.axi_lite_master_bfm
    generic map (
      drive_invalid_value => '0'
    )
    port map (
      clk => clk,
      reset => reset,
      --
      axi_lite_m2s => axi_lite_m2s,
      axi_lite_s2m => axi_lite_s2m
    );


  ------------------------------------------------------------------------------
  dut : entity work.axi_lite_register_file
    generic map (
      registers => regs,
      default_values => default_values
    )
    port map (
      clk => clk,
      reset => reset,
      --
      axi_lite_m2s => axi_lite_m2s,
      axi_lite_s2m => axi_lite_s2m,
      --
      regs_up => regs_up,
      regs_down => regs_down,
      --
      reg_was_read => reg_was_read,
      reg_was_written => reg_was_written
    );

end architecture;
