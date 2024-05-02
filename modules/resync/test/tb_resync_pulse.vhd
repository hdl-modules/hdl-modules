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
use common.types_pkg.all;


entity tb_resync_pulse is
  generic (
    enable_feedback : boolean;
    output_clock_is_faster : boolean := false;
    output_clock_is_slower : boolean := false;
    clocks_are_same : boolean := false;
    input_pulse_overload : boolean := false;
    active_level : boolean;
    runner_cfg : string
  );
end entity;

architecture tb of tb_resync_pulse is

  constant active_level_sl : std_ulogic := to_sl(active_level);

  constant clock_period_fast : time := 2 ns;
  constant clock_period_medium : time := 9 ns;
  constant clock_period_slow : time := 41 ns;

  constant sleep_between_pulses : time := 10 * clock_period_slow;

  signal clk_in, clk_out : std_ulogic := '0';
  signal pulse_in, pulse_out : std_ulogic := not active_level_sl;
  signal overload_has_occurred : std_ulogic := '0';

  signal num_pulses_out : natural := 0;

begin

  test_runner_watchdog(runner, 10 ms);
  clk_in <= not clk_in after clock_period_medium / 2;


  clock_out_gen : if output_clock_is_faster generate
    clk_out <= not clk_out after clock_period_fast / 2;

  elsif output_clock_is_slower generate
    clk_out <= not clk_out after clock_period_slow / 2;

  elsif clocks_are_same generate
    clk_out <= transport clk_in after clock_period_medium / 5;

  else generate
    assert false report "Invalid clock configuration";

  end generate;


  ------------------------------------------------------------------------------
  main : process

    constant num_input_pulses : positive := 100;

    procedure test_pulse is
    begin
      wait until rising_edge(clk_in);
      pulse_in <= active_level_sl;

      wait until rising_edge(clk_in);
      pulse_in <= not active_level_sl;

      if input_pulse_overload then
        -- Send another pulse
        wait until rising_edge(clk_in);
        pulse_in <= active_level_sl;

        wait until rising_edge(clk_in);
        pulse_in <= not active_level_sl;
      end if;
    end procedure;
  begin
    test_runner_setup(runner, runner_cfg);

    for i in 1 to num_input_pulses loop
      -- In the case of input_pulse_overload we will send more than one input pulse per call
      -- to test_pulse().
      -- But the input gating will make sure that only one pulse arrives on the output,
      -- so expected_num_pulses is still i.
      test_pulse;
      wait for sleep_between_pulses;
    end loop;

    if input_pulse_overload and not enable_feedback then
      if output_clock_is_slower then
        -- Pulses can be missed completely.
        check_relation(num_pulses_out < num_input_pulses);
        -- However, at least some pulses should arrive.
        check_relation(num_pulses_out > 20);
      end if;

      if clocks_are_same then
        -- In simulation these are exactly the same and all the pulses arrive, but it can probably
        -- not be guaranteed on hardware.
        check_equal(num_pulses_out, 2 * num_input_pulses);
      end if;

      if output_clock_is_faster then
        -- All pulses should arrive.
        check_equal(num_pulses_out, 2 * num_input_pulses);
      end if;

    else
      -- Feedback makes sure that all the overload pulses are removed.
      check_equal(num_pulses_out, num_input_pulses);
    end if;

    test_runner_cleanup(runner);
  end process;


  ------------------------------------------------------------------------------
  output : process
  begin
    wait until rising_edge(clk_out);

    num_pulses_out <= num_pulses_out + to_int(pulse_out = active_level_sl);
  end process;


  ------------------------------------------------------------------------------
  dut : entity work.resync_pulse
    generic map (
      active_level => active_level_sl,
      enable_feedback => enable_feedback,
      assert_false_on_pulse_overload => not (input_pulse_overload or not enable_feedback)
    )
    port map (
      clk_in => clk_in,
      pulse_in => pulse_in,
      overload_has_occurred => overload_has_occurred,
      --
      clk_out => clk_out,
      pulse_out => pulse_out
    );

end architecture;
