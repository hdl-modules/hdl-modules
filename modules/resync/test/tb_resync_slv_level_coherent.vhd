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
use vunit_lib.run_pkg.all;

library common;
use common.time_pkg.to_real_s;


entity tb_resync_slv_level_coherent is
  generic (
    output_clock_is_greatly_faster : boolean := false;
    output_clock_is_mildly_faster : boolean := false;
    clocks_are_same : boolean := false;
    output_clock_is_mildly_slower : boolean := false;
    output_clock_is_greatly_slower : boolean := false;
    runner_cfg : string
  );
end entity;

architecture tb of tb_resync_slv_level_coherent is

  -- Big difference, so that erroneous level resync back or forth could happen.
  constant clock_period_greatly_fast : time := 2 ns;
  constant clock_period_mildly_fast : time := clock_period_greatly_fast * 20;
  constant clock_period_medium : time := clock_period_mildly_fast + 1 ns;
  constant clock_period_mildly_slow : time := clock_period_medium + 1 ns;
  constant clock_period_greatly_slow : time := clock_period_medium * 20 + 1 ns;

  function get_clk_out_period return time is
  begin
    if output_clock_is_greatly_faster then
      return clock_period_greatly_fast;
    end if;

    if output_clock_is_mildly_faster then
      return clock_period_mildly_fast;
    end if;

    if output_clock_is_mildly_slower then
      return clock_period_mildly_slow;
    end if;

    if output_clock_is_greatly_slower then
      return clock_period_greatly_slow;
    end if;

    if clocks_are_same then
      return clock_period_medium;
    end if;

    assert false;
  end function;
  constant clk_in_period : time := clock_period_medium;
  constant clk_out_period : time := get_clk_out_period;

  signal clk_in, clk_out : std_ulogic := '0';

  constant data_init : u_unsigned(16 - 1 downto 0) := x"5A5A";
  signal data_in, data_out : u_unsigned(data_init'range) := data_init;

  signal num_outputs_checked : natural := 0;

  signal sum_cycles_since_last_change : natural := 0;
  signal min_cycles_since_last_change : positive := 2**20;
  signal max_cycles_since_last_change : positive := 1;

  signal sum_value_diff : natural := 0;
  signal min_value_diff : positive := 2 ** 20;
  signal max_value_diff : positive := 1;

begin

  clk_in <= not clk_in after clk_in_period / 2;
  clk_out <= not clk_out after clk_out_period / 2;

  test_runner_watchdog(runner, 10 ms);


  ------------------------------------------------------------------------------
  main : process
    constant num_tests : positive := 100;

    variable average_value_diff, average_cycles_since_last_change : real := 0.0;

    constant expected_time : time := 3 * clk_out_period + 3 * clk_in_period;
    variable got_time : time := 0 fs;
    variable relative_error : real := 0.0;
  begin
    test_runner_setup(runner, runner_cfg);

    -- Default value
    check_equal(data_out, data_init);

    wait until num_outputs_checked = num_tests and rising_edge(clk_out);

    average_value_diff := real(sum_value_diff) / real(num_outputs_checked);

    average_cycles_since_last_change := (
      real(sum_cycles_since_last_change) / real(num_outputs_checked)
    );

    got_time := average_cycles_since_last_change * clk_out_period;

    relative_error := abs(to_real_s(got_time - expected_time)) / to_real_s(expected_time);

    report "min_value_diff: " & to_string(min_value_diff);
    report "max_value_diff: " & to_string(max_value_diff);

    report "sum_value_diff: " & to_string(sum_value_diff);

    report "average_value_diff: " & to_string(average_value_diff);

    report "min_cycles_since_last_change: " & to_string(min_cycles_since_last_change);
    report "max_cycles_since_last_change: " & to_string(max_cycles_since_last_change);

    report "sum_cycles_since_last_change: " & to_string(sum_cycles_since_last_change);
    report "num_result_checked: " & to_string(num_outputs_checked);

    report "average_cycles_since_last_change: " & to_string(average_cycles_since_last_change);

    report "expected_time: " & to_string(expected_time);
    report "got_time: " & to_string(got_time);

    report "relative_error: " & to_string(100.0 * relative_error);
    assert relative_error < 0.16 report "Not expected throughput";

    test_runner_cleanup(runner);
  end process;


  ------------------------------------------------------------------------------
  stimuli : process
  begin
    wait until rising_edge(clk_in);

    data_in <= data_in + 1;
  end process;


  ------------------------------------------------------------------------------
  check_output_block : block
    signal data_out_p1 : u_unsigned(16 - 1 downto 0) := data_init;
    signal cycles_since_last_change : natural := 0;
  begin

    ------------------------------------------------------------------------------
    check_output : process
      variable value_diff : positive := 1;
    begin
      wait until rising_edge(clk_out);

      if data_out /= data_out_p1 then
        assert data_out > data_out_p1 report "data should be increasing";
        assert data_out < data_in report "output should be delayed input";

        value_diff := to_integer(data_out - data_out_p1);

        sum_value_diff <= sum_value_diff + value_diff;
        min_value_diff <= minimum(min_value_diff, value_diff);
        max_value_diff <= maximum(max_value_diff, value_diff);

        sum_cycles_since_last_change <= sum_cycles_since_last_change + cycles_since_last_change;

        min_cycles_since_last_change <= minimum(
          min_cycles_since_last_change, cycles_since_last_change
        );
        max_cycles_since_last_change <= maximum(
          max_cycles_since_last_change, cycles_since_last_change
        );

        cycles_since_last_change <= 1;

        num_outputs_checked <= num_outputs_checked + 1;

      else
        cycles_since_last_change <= cycles_since_last_change + 1;
      end if;

      data_out_p1 <= data_out;
    end process;

  end block;


  ------------------------------------------------------------------------------
  dut : entity work.resync_slv_level_coherent
    generic map (
      width => data_in'length,
      default_value => std_logic_vector(data_init)
    )
    port map (
      clk_in => clk_in,
      data_in => std_logic_vector(data_in),

      clk_out => clk_out,
      unsigned(data_out) => data_out
    );

end architecture;
