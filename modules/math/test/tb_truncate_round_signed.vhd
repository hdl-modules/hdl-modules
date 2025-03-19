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
use vunit_lib.integer_array_pkg.all;
use vunit_lib.queue_pkg.all;
use vunit_lib.run_pkg.all;

library osvvm;
use osvvm.RandomPkg.RandomPType;

library common;
use common.types_pkg.all;

use work.math_pkg.all;


entity tb_truncate_round_signed is
  generic (
    input_width : natural := 0;
    result_width : natural := 0;
    convergent_rounding : boolean;
    seed : natural;
    runner_cfg : string
  );
end entity;

architecture tb of tb_truncate_round_signed is

  -- ---------------------------------------------------------------------------
  -- Generic constants
  shared variable rnd : RandomPType;

  impure function initialize_and_get_input_width return positive is
  begin
    rnd.InitSeed(seed);

    if input_width /= 0 then
      return input_width;
    end if;

    return rnd.Uniform(2, 24);
  end function;
  constant input_width_to_use : positive := initialize_and_get_input_width;

  impure function get_result_width return positive is
  begin
    if result_width /= 0 then
      return result_width;
    end if;

    return maximum(1, rnd.Uniform(input_width_to_use - 4, input_width_to_use));
  end function;
  constant result_width_to_use : positive := get_result_width;

  constant enable_saturation : boolean := true;
  constant enable_addition_register : boolean := rnd.RandBool;
  constant enable_saturation_register : boolean := rnd.RandBool;

  -- ---------------------------------------------------------------------------
  -- DUT connections
  signal clk : std_ulogic := '0';

  signal input_valid : std_ulogic := '0';
  signal input_value : u_signed(input_width_to_use - 1 downto 0) := (others => '0');

  signal result_valid, result_overflow : std_ulogic := '0';
  signal result_value : u_signed(result_width_to_use - 1 downto 0) := (others => '0');

  -- ---------------------------------------------------------------------------
  -- Testbench stuff
  constant input_queue, reference_value_queue, reference_overflow_queue : queue_t := new_queue;

  signal num_result_checked : natural := 0;

begin

  test_runner_watchdog(runner, 1 ms);
  clk <= not clk after 2 ns;


  ------------------------------------------------------------------------------
  main : process

    variable num_result_expected : natural := 0;

    procedure test_value(value_in, value_result : integer; overflow : boolean) is
    begin
      push(input_queue, value_in);
      push(reference_value_queue, value_result);
      push(reference_overflow_queue, overflow);

      input_valid <= '1';
      input_value <= to_signed(value_in, input_value'length);

      num_result_expected := num_result_expected + 1;

      wait until rising_edge(clk);
      input_valid <= '0';
      input_value <= (others => '0');

      for wait_cycle in 1 to rnd.FavorSmall(0, 2) loop
        wait until rising_edge(clk);
      end loop;
    end procedure;

    procedure run_random_test is
      constant num_bits_to_remove : natural := input_width_to_use - result_width_to_use;
      constant divisor : positive := 2 ** num_bits_to_remove;

      constant max_result_value : natural := get_max_signed_integer(num_bits=>result_width_to_use);

      procedure push_reference(value_in : integer) is
        variable quotient, remainder : integer := 0;
      begin
        if num_bits_to_remove = 0 then
          test_value(value_in=>value_in, value_result=>value_in, overflow=>false);
          return;
        end if;

        quotient := div_round_negative(dividend=>value_in, divisor=>divisor);
        remainder := value_in mod divisor;

        if remainder < divisor / 2 then
          test_value(value_in=>value_in, value_result=>quotient, overflow=>false);
          return;
        end if;

        if quotient = max_result_value then
          test_value(value_in=>value_in, value_result=>max_result_value, overflow=>true);
          return;
        end if;

        test_value(value_in=>value_in, value_result=>quotient + 1, overflow=>false);
        return;
      end procedure;

      variable value_in : u_signed(input_width_to_use - 1 downto 0) := (others => '0');
    begin
      for test_idx in 0 to 200 loop
        value_in := rnd.RandSigned(input_width_to_use);
        push_reference(value_in=>to_integer(value_in));
      end loop;
    end procedure;

    procedure run_convergent_test is
      constant input_values : integer_array_t := load_csv(
        output_path(runner_cfg) & "input_values.csv"
      );
      constant result_values : integer_array_t := load_csv(
        output_path(runner_cfg) & "result_values.csv"
      );
    begin
      report "Testing with " & to_string(length(input_values)) & " values";

      for value_index in 0 to length(input_values) - 1 loop
        test_value(
          value_in=>get(arr=>input_values, idx=>value_index),
          value_result=>get(arr=>result_values, idx=>value_index),
          -- Overflow is not tested in this mode.
          -- But the overflow mechanism is exactly the same as in the other mode,
          -- so it should be fine.
          overflow=>false
        );
      end loop;
    end procedure;

  begin
    test_runner_setup(runner, runner_cfg);

    report "input_width_to_use = " & to_string(input_width_to_use);
    report "result_width_to_use = " & to_string(result_width_to_use);
    report "enable_saturation = " & to_string(enable_saturation);
    report "enable_addition_register = " & to_string(enable_addition_register);
    report "enable_saturation_register = " & to_string(enable_saturation_register);

    if run("test_random_data") then
      run_random_test;

    elsif run("test_convergent") then
      run_convergent_test;

    end if;

    wait until num_result_checked = num_result_expected and rising_edge(clk);

    test_runner_cleanup(runner);
  end process;


  ------------------------------------------------------------------------------
  check_data : process
    variable value_in, expected_value : integer := 0;
    variable expected_overflow : boolean := false;
  begin
    wait until result_valid and rising_edge(clk);

    value_in := pop(input_queue);
    expected_value := pop(reference_value_queue);
    expected_overflow := pop(reference_overflow_queue);

    check_equal(result_value, expected_value, "value_in = " & to_string(value_in));
    check_equal(result_overflow, expected_overflow, "value_in = " & to_string(value_in));

    num_result_checked <= num_result_checked + 1;
  end process;


  ------------------------------------------------------------------------------
  dut : entity work.truncate_round_signed
    generic map (
      input_width => input_width_to_use,
      result_width => result_width_to_use,
      convergent_rounding => convergent_rounding,
      enable_addition_register => enable_addition_register,
      enable_saturation => enable_saturation,
      enable_saturation_register => enable_saturation_register
    )
    port map (
      clk => clk,
      --
      input_valid => input_valid,
      input_value => input_value,
      --
      result_valid => result_valid,
      result_value => result_value,
      result_overflow => result_overflow
    );

end architecture;
