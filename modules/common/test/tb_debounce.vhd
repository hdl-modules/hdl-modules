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
use vunit_lib.check_pkg.all;
use vunit_lib.run_pkg.all;

use work.types_pkg.all;


entity tb_debounce is
  generic (
    enable_iob : boolean;
    runner_cfg : string
  );
end entity;

architecture tb of tb_debounce is

  signal clk : std_ulogic := '0';
  constant clk_period : time := 10 ns;

  constant stable_count : positive := 100;
  signal noisy_input, stable_result, stable_rising_edge, stable_falling_edge : std_ulogic := '0';

  signal num_rising_edges, num_falling_edges : natural := 0;

begin

  test_runner_watchdog(runner, 100 us);
  clk <= not clk after clk_period / 2;


  ------------------------------------------------------------------------------
  main : process

    procedure wait_clk_cycles(count : natural) is
    begin
      for wait_cycle in 1 to count loop
        wait until rising_edge(clk);
      end loop;
    end procedure;

    procedure toggle(intervals : integer_vector) is
    begin
      for sequence_idx in intervals'range loop
        wait_clk_cycles(intervals(sequence_idx));
        noisy_input <= not noisy_input;
      end loop;
    end procedure;

  begin
    test_runner_setup(runner, runner_cfg);

    -- All these test are based on a stable_count of 100.

    if run("test_low_with_noise") then
      -- Keep low for a bit, then a lot of noise (slightly shorter than stable limit).
      toggle((200, 99, 99, 99, 99, 99, 99, 99, 99, 99));
      wait_clk_cycles(2 * stable_count);
      check_equal(num_rising_edges, 0);
      check_equal(num_falling_edges, 0);

    elsif run("test_high_with_noise") then
        -- Keep low for a bit, then a high period (slightly longer than stable limit),
        -- then a lot of noise
        toggle((200, 101, 99, 99, 99, 99, 99, 99, 99));
        wait_clk_cycles(2 * stable_count);
        check_equal(num_rising_edges, 1);
        check_equal(num_falling_edges, 0);

    elsif run("test_high_and_low_amongst_noise") then
      -- Keep low for a bit, then a high period, then some noise, then a high period,
      -- then some noise.
      toggle((200, 101, 99, 99, 99, 99, 101, 99, 99, 99));
      wait_clk_cycles(2 * stable_count);
      check_equal(num_rising_edges, 1);
      check_equal(num_falling_edges, 1);
    end if;

    test_runner_cleanup(runner);
  end process;


  ------------------------------------------------------------------------------
  counters : process
    variable stable_result_p1, stable_result_p2 : std_ulogic := '0';
  begin
    wait until rising_edge(clk);

    num_rising_edges <= num_rising_edges + to_int(stable_result = '1' and stable_result_p1 = '0');
    num_falling_edges <= num_falling_edges + to_int(stable_result = '0' and stable_result_p1 = '1');

    check_equal(stable_rising_edge, stable_result_p1 and not stable_result_p2);
    check_equal(stable_falling_edge, (not stable_result_p1) and stable_result_p2);

    stable_result_p2 := stable_result_p1;
    stable_result_p1 := stable_result;
  end process;


  ------------------------------------------------------------------------------
  dut : entity work.debounce
    generic map (
      stable_count => stable_count,
      enable_iob => enable_iob
    )
    port map (
      noisy_input => noisy_input,
      --
      clk => clk,
      stable_result => stable_result,
      stable_rising_edge => stable_rising_edge,
      stable_falling_edge => stable_falling_edge
    );

end architecture;
