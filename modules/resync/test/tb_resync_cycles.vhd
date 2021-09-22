-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the tsfpga project.
-- https://tsfpga.com
-- https://gitlab.com/tsfpga/tsfpga
-- -------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
context vunit_lib.vunit_context;

library common;
use common.types_pkg.all;


entity tb_resync_cycles is
  generic (
    output_clock_is_faster : boolean := false;
    output_clock_is_slower : boolean := false;
    active_high : boolean;
    runner_cfg : string
  );
end entity;

architecture tb of tb_resync_cycles is
  constant counter_width : integer := 3;
  constant clock_period_fast : time := 2 ns;
  constant clock_period_medium : time := 5 ns;
  constant clock_period_slow : time := 10 ns;
  constant active_level : std_logic := to_sl(active_high);

  function clk_out_period return time is
  begin
    if output_clock_is_faster then
      return clock_period_fast;
    elsif output_clock_is_slower then
      return clock_period_slow;
    else
      return clock_period_medium;
    end if;
  end function;

  signal clk_in, clk_out : std_logic := '0';
  signal data_in, data_out : std_logic := not active_level;

  signal num_data_out : integer := 0;
  signal reset_reference_counter : boolean := false;

begin

  test_runner_watchdog(runner, 100 us);
  clk_in <= not clk_in after clock_period_medium / 2;
  clk_out <= not clk_out after clk_out_period / 2;


  ------------------------------------------------------------------------------
  main : process
    procedure test(num_cycles : integer) is
      variable start_time : time;
    begin
      wait until rising_edge(clk_out);
      reset_reference_counter <= true;
      wait until rising_edge(clk_out);
      reset_reference_counter <= false;

      start_time := now;

      for i in 1 to num_cycles loop
        wait until rising_edge(clk_in);
        data_in <= active_level;
      end loop;

      wait until rising_edge(clk_in);
      data_in <= not active_level;

      wait until rising_edge(clk_out) and
        ((now - start_time) > ((num_cycles + 5) * clock_period_slow));

      check_equal(num_data_out, num_cycles);
    end procedure;
  begin
    test_runner_setup(runner, runner_cfg);
    wait until rising_edge(clk_in);

    if output_clock_is_slower then
      -- The resync may fail only after 2**counter_width input cycles
      for test_num in 1 to 10 loop
        test(2**counter_width);
        test(2**counter_width);
      end loop;
    else
      for test_num in 1 to 10 loop
        test(100);
      end loop;
    end if;

    test_runner_cleanup(runner);
  end process;


  ------------------------------------------------------------------------------
  output : process
  begin
    wait until rising_edge(clk_out);
    if reset_reference_counter then
      num_data_out <= 0;
    elsif data_out = active_level then
      num_data_out <= num_data_out + 1;
    end if;
  end process;


  ------------------------------------------------------------------------------
  dut : entity work.resync_cycles
    generic map (
      counter_width => counter_width,
      active_level => active_level
    )
    port map (
      clk_in => clk_in,
      data_in => data_in,

      clk_out => clk_out,
      data_out => data_out);

end architecture;
