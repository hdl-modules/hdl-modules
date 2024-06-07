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


entity tb_resync_slv_level_coherent is
  generic (
    output_clock_is_faster : boolean;
    runner_cfg : string
  );
end entity;

architecture tb of tb_resync_slv_level_coherent is

  constant clock_period_fast : time := 2 ns;
  constant clock_period_medium : time := clock_period_fast * 20 + 1 ns;
  constant clock_period_slow : time := clock_period_medium * 20 + 1 ns;

  function clk_out_period return time is
  begin
    if output_clock_is_faster then
      return clock_period_fast;
    else
      return clock_period_slow;
    end if;
  end function;

  signal clk_in, clk_out : std_ulogic := '0';

  constant data_init : u_unsigned(16 - 1 downto 0) := x"5A5A";
  signal data_in, data_out : u_unsigned(data_init'range) := data_init;

  signal num_stimuli_sent, num_result_checked : natural := 0;

  signal sum_cycles_since_last_change : natural := 0;
  signal min_cycles_since_last_change, max_cycles_since_last_change : positive := 1;
  signal min_value_diff, max_value_diff : positive := 1;

begin

  clk_out <= not clk_out after clk_out_period / 2;
  clk_in <= not clk_in after clock_period_medium / 2;

  test_runner_watchdog(runner, 10 ms);


  ------------------------------------------------------------------------------
  main : process
  begin
    test_runner_setup(runner, runner_cfg);

    -- Default value
    check_equal(data_out, data_init);

    wait until num_stimuli_sent > 100 and rising_edge(clk_in);
    wait until num_result_checked > 100 and rising_edge(clk_out);

    report "min_value_diff: " & to_string(min_value_diff);
    report "max_value_diff: " & to_string(max_value_diff);
    report "min_cycles_since_last_change: " & to_string(min_cycles_since_last_change);
    report "max_cycles_since_last_change: " & to_string(max_cycles_since_last_change);

    report "sum_cycles_since_last_change: " & to_string(sum_cycles_since_last_change);
    report "num_result_checked: " & to_string(num_result_checked);

    test_runner_cleanup(runner);
  end process;


  ------------------------------------------------------------------------------
  stimuli : process
  begin
    wait until rising_edge(clk_in);

    data_in <= data_in + 1;
    num_stimuli_sent <= num_stimuli_sent + 1;
  end process;


  ------------------------------------------------------------------------------
  check_result_block : block
    signal data_out_p1 : u_unsigned(16 - 1 downto 0) := data_init;
    signal cycles_since_last_change : natural := 0;
  begin

    ------------------------------------------------------------------------------
    check_result : process
      variable value_diff : positive := 1;
    begin
      wait until rising_edge(clk_out);

      if data_out /= data_out_p1 then
        assert data_out > data_out_p1 report "data should be increasing";

        value_diff := to_integer(data_out - data_out_p1);

        min_value_diff <= minimum(min_value_diff, value_diff);
        max_value_diff <= maximum(max_value_diff, value_diff);

        min_cycles_since_last_change <= minimum(
          min_cycles_since_last_change, cycles_since_last_change
        );
        max_cycles_since_last_change <= maximum(
          max_cycles_since_last_change, cycles_since_last_change
        );

        cycles_since_last_change <= 1;

        num_result_checked <= num_result_checked + 1;

      else
        cycles_since_last_change <= cycles_since_last_change + 1;
      end if;
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
