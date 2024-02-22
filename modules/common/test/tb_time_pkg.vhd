-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the hdl-modules project, a collection of reusable, high-quality,
-- peer-reviewed VHDL building blocks.
-- https://hdl-modules.com
-- https://github.com/hdl-modules/hdl-modules
-- -------------------------------------------------------------------------------------------------

library vunit_lib;
use vunit_lib.check_pkg.all;
use vunit_lib.run_pkg.all;

use work.time_pkg.all;


entity tb_time_pkg is
  generic (
    runner_cfg : string
  );
end entity;

architecture tb of tb_time_pkg is
begin

  ------------------------------------------------------------------------------
  main : process

    -- Resolution of the 'time' unit is 1 fs = 10**-15 s.
    -- Allow less than this in diff when converting to real.
    constant real_time_max_diff : real := 0.49e-15;

  begin
    test_runner_setup(runner, runner_cfg);

    if run("test_to_real_s") then
      report to_string(integer'high);

      -- 9223372036854775807 fs in GHDL.
      -- Meaning the maximum value that can be represented is 2.56 hours.
      -- However, implementation details limit us to ~35 minutes.
      -- Some random values in this legal range are tested below.
      report to_string(time'high);

      check_equal(to_real_s(30 min), 30.0 * 60.0, max_diff=>real_time_max_diff);
      check_equal(to_real_s(3 min), 3.0 * 60.0, max_diff=>real_time_max_diff);

      check_equal(to_real_s(2 sec), 2.0, max_diff=>real_time_max_diff);
      check_equal(to_real_s(1 sec), 1.0, max_diff=>real_time_max_diff);

      check_equal(to_real_s(625 ms), 0.625, max_diff=>real_time_max_diff);

      check_equal(to_real_s(1 ns), 1.0e-9, max_diff=>real_time_max_diff);

      -- Most common use is to handle clock periods around the MHz range, so spend some
      -- time testing these.
      check_equal(to_real_s(8 us + 371 ns), 8.371e-6, max_diff=>real_time_max_diff);
      check_equal(to_real_s(7 us + 371 ns), 7.371e-6, max_diff=>real_time_max_diff);
      check_equal(to_real_s(6 us + 371 ns), 6.371e-6, max_diff=>real_time_max_diff);
      check_equal(to_real_s(5 us + 371 ns), 5.371e-6, max_diff=>real_time_max_diff);
      check_equal(to_real_s(4 us + 371 ns), 4.371e-6, max_diff=>real_time_max_diff);
      check_equal(to_real_s(3 us + 371 ns), 3.371e-6, max_diff=>real_time_max_diff);
      check_equal(to_real_s(2 us + 371 ns), 2.371e-6, max_diff=>real_time_max_diff);
      check_equal(to_real_s(1 us + 371 ns), 1.371e-6, max_diff=>real_time_max_diff);

      check_equal(to_real_s(503 ns), 0.503e-6, max_diff=>real_time_max_diff);

      -- Lowest end of the 'time' range
      check_equal(to_real_s(8 fs), 8.0e-15, max_diff=>real_time_max_diff);
      check_equal(to_real_s(7 fs), 7.0e-15, max_diff=>real_time_max_diff);
      check_equal(to_real_s(6 fs), 6.0e-15, max_diff=>real_time_max_diff);
      check_equal(to_real_s(5 fs), 5.0e-15, max_diff=>real_time_max_diff);
      check_equal(to_real_s(4 fs), 4.0e-15, max_diff=>real_time_max_diff);
      check_equal(to_real_s(3 fs), 3.0e-15, max_diff=>real_time_max_diff);
      check_equal(to_real_s(2 fs), 2.0e-15, max_diff=>real_time_max_diff);
      check_equal(to_real_s(1 fs), 1.0e-15, max_diff=>real_time_max_diff);

    elsif run("test_frequency_conversion") then
      -- Same checks as in the netlist build. Should give same result in Vivado as in simulator.

      for test_idx in test_periods'range loop
        -- 'time' period calculated from 'real' frequency
        assert  to_period(test_frequencies_real(test_idx)) = test_periods(test_idx);

        -- 'time' period calculated from 'integer' frequency
        -- The assert is a "check almost equal" for 'time' type.
        assert (
          (
            to_period(test_frequencies_integer(test_idx))
            >= test_periods(test_idx) - test_tolerances_period_from_integer_frequency(test_idx)
          ) and (
            to_period(test_frequencies_integer(test_idx))
            <= test_periods(test_idx) + test_tolerances_period_from_integer_frequency(test_idx)
          )
        );

        -- 'real' frequency calculated from 'time' period
        check_equal(
          got=>to_frequency_hz(test_periods(test_idx)),
          expected=>test_frequencies_real(test_idx),
          max_diff=>test_tolerances_real_frequency_from_period(test_idx)
        );

        -- 'time' period to 'integer' frequency
        check_equal(to_frequency_hz(test_periods(test_idx)), test_frequencies_integer(test_idx));

      end loop;

    end if;

    test_runner_cleanup(runner);
  end process;

end architecture;
