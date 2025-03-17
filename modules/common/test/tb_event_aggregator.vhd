-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the hdl-modules project, a collection of reusable, high-quality,
-- peer-reviewed VHDL building blocks.
-- https://hdl-modules.com
-- https://github.com/hdl-modules/hdl-modules
-- -------------------------------------------------------------------------------------------------

library ieee;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;

library osvvm;
use osvvm.RandomPkg.RandomPType;

library vunit_lib;
use vunit_lib.check_pkg.all;
use vunit_lib.run_pkg.all;

use work.types_pkg.all;


entity tb_event_aggregator is
  generic (
    event_count : positive := 1;
    tick_count : positive := 1;
    seed : natural;
    runner_cfg : string
  );
end entity;

architecture tb of tb_event_aggregator is

  signal clk, input_event, aggregated_event : std_ulogic := '0';
  constant clk_period : time := 10 ns;

  signal aggregated_event_count : natural := 0;

begin

  test_runner_watchdog(runner, 100 us);
  clk <= not clk after clk_period / 2;


  ------------------------------------------------------------------------------
  main : process
    procedure send_event(count : positive := 1) is
    begin
      report "Sending " & to_string(count) & " events";
      for event_index in 1 to count loop
        input_event <= '1';
        wait until rising_edge(clk);
        input_event <= '0';
        wait until rising_edge(clk);
      end loop;
    end procedure;

    variable start_time : time := now;
    variable rnd : RandomPType;
    variable expected_aggregated_event_count : natural := 0;

  begin
    test_runner_setup(runner, runner_cfg);
    rnd.InitSeed(seed);

    wait until rising_edge(clk);
    start_time := now;

    if run("test_tick_count") then
      for test_index in 0 to 5 loop
        send_event(count=>rnd.RandInt(1, tick_count / 2 - 5));

        wait until aggregated_event = '1' and rising_edge(clk);

        check_equal(
          now - start_time,
          tick_count * clk_period,
          "Test index " & to_string(test_index)
        );
        start_time := now;
      end loop;

      wait for 4 * tick_count * clk_period;
      check_equal(aggregated_event_count, 6);

    elsif run("test_event_count") then
      for test_index in 0 to 5 loop
        send_event(count=>event_count - 1);

        wait for 100 * clk_period;
        send_event;

        check_equal(aggregated_event, '1');
      end loop;

      wait for 100 * clk_period;
      check_equal(aggregated_event_count, 6);

    elsif run("test_both") then
      for test_index in 0 to 5 loop
        send_event(count=>event_count - 1);

        -- Show that the 'tick' mechanism is the one that triggers, despite a few 'event's.
        -- Also shows that event count is reset when tick count is reached.
        wait until aggregated_event = '1' and rising_edge(clk);
        check_equal(
          now - start_time,
          tick_count * clk_period,
          "Test index " & to_string(test_index)
        );
        start_time := now;
      end loop;

      wait for 4 * tick_count * clk_period;
      check_equal(aggregated_event_count, 6);

      start_time := now;
      expected_aggregated_event_count := 6;

      while now < start_time + 10 * tick_count * clk_period loop
        send_event(count=>event_count);
        check_equal(aggregated_event, '1');
        expected_aggregated_event_count := expected_aggregated_event_count + 1;
      end loop;

      wait for 100 * clk_period;
      check_equal(aggregated_event_count, expected_aggregated_event_count);

    end if;

    test_runner_cleanup(runner);
  end process;


  ------------------------------------------------------------------------------
  count_events : process
  begin
    wait until rising_edge(clk);

    aggregated_event_count <= aggregated_event_count + to_int(aggregated_event);
  end process;


  ------------------------------------------------------------------------------
  dut : entity work.event_aggregator
    generic map (
      event_count => event_count,
      tick_count => tick_count
    )
    port map (
      clk => clk,
      --
      input_event => input_event,
      aggregated_event => aggregated_event
    );

end architecture;
