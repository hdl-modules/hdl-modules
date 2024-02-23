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


entity tb_periodic_pulser is
  generic (
    period : integer range 2 to integer'high;
    shift_register_length : positive;
    runner_cfg : string
  );
end entity;

architecture tb of tb_periodic_pulser is

  signal clk : std_ulogic := '0';
  signal count_enable : std_ulogic := '1';
  signal pulse : std_ulogic := '0';

  signal start_test, test_done : boolean := false;

begin

  clk <= not clk after 5 ns;

  test_runner_watchdog(runner, 1 ms);


  ------------------------------------------------------------------------------
  main : process
  begin
    test_runner_setup(runner, runner_cfg);

    wait until rising_edge(clk);
    start_test <= true;

    wait until rising_edge(clk) and test_done;

    test_runner_cleanup(runner);
  end process;


  ------------------------------------------------------------------------------
  stimuli : process
    variable rnd : RandomPType;
  begin
    wait until rising_edge(clk) and start_test;
    loop
      wait until rising_edge(clk);
      count_enable <= rnd.RandSlv(1)(1);
    end loop;
  end process;


  ------------------------------------------------------------------------------
  check : process
    constant num_pulses_to_check : integer := 3;
    variable tick_count : integer range 0 to period - 1;
    variable num_pulses : integer range 0 to num_pulses_to_check := 0;
    variable expected_pulse : std_ulogic := '0';
  begin
    wait until rising_edge(clk);
    expected_pulse := '0';
    if count_enable then
      if tick_count = period - 1 then
        tick_count := 0;
        expected_pulse := '1';
      else
        tick_count := tick_count + 1;
      end if;
    end if;

    check_equal(pulse, expected_pulse, "Pulse seen at unexpected time");
    if expected_pulse then
      num_pulses := num_pulses + 1;
      if num_pulses = num_pulses_to_check then
        test_done <= true;
      end if;
    end if;
  end process;


  ------------------------------------------------------------------------------
  dut : entity work.periodic_pulser
    generic map (
      period => period,
      shift_register_length => shift_register_length)
    port map (
      clk => clk,
      count_enable => count_enable,
      pulse => pulse
      );


end architecture;
