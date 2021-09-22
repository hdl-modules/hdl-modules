-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the tsfpga project.
-- https://tsfpga.com
-- https://gitlab.com/tsfpga/tsfpga
-- -------------------------------------------------------------------------------------------------

library ieee;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;

library vunit_lib;
context vunit_lib.vunit_context;

library math;
use math.math_pkg.all;


entity tb_clock_counter is
  generic (
    reference_clock_rate_mhz : positive;
    target_clock_rate_mhz : positive;
    runner_cfg : string
  );
end entity;

architecture tb of tb_clock_counter is

  constant resolution_bits : positive := 10;
  constant max_relation_bits : positive := 8;

  signal reference_clock, target_clock : std_logic := '0';
  signal target_tick_count : unsigned(resolution_bits + max_relation_bits - 1 downto 0) :=
    (others => '0');

  constant reference_clock_period : time := (1.0 / real(reference_clock_rate_mhz)) * (1 us);
  constant target_clock_period : time := (1.0 / real(target_clock_rate_mhz)) * (1 us);

  constant expected_target_tick_count : real :=
    2.0 ** resolution_bits * real(target_clock_rate_mhz) / real(reference_clock_rate_mhz);

begin

  test_runner_watchdog(runner, 1 ms);
  reference_clock <= not reference_clock after reference_clock_period / 2;
  target_clock <= not target_clock after target_clock_period / 2;


  ------------------------------------------------------------------------------
  main : process
  begin
    test_runner_setup(runner, runner_cfg);

    if run("test_target_tick_count") then
      -- For the first 2 ** resolution_bits cycles, the value is zero,
      -- the next 2 ** resolution_bits cycles, the value is almost correct but a little too low.
      for wait_cycle in 0 to 2 * 2 ** resolution_bits - 1 loop
        wait until rising_edge(reference_clock);
      end loop;

      -- In all upcoming cycles however, the value shall be correct.
      for check_iteration in 0 to 5 * 2 ** resolution_bits loop
        wait until rising_edge(reference_clock);
        check_equal(
          real(to_integer(target_tick_count)),
          expected_target_tick_count,
          msg=>"check_iteration=" & to_string(check_iteration),
          max_diff=>1.0
        );
      end loop;
    end if;

    test_runner_cleanup(runner);
  end process;


  ------------------------------------------------------------------------------
  dut : entity work.clock_counter
    generic map (
      resolution_bits => resolution_bits,
      max_relation_bits => max_relation_bits
    )
    port map (
      target_clock => target_clock,
      --
      reference_clock => reference_clock,
      target_tick_count => target_tick_count
    );

end architecture;
