-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the hdl_modules project, a collection of reusable, high-quality,
-- peer-reviewed VHDL building blocks.
-- https://hdl-modules.com
-- https://gitlab.com/hdl_modules/hdl_modules
-- -------------------------------------------------------------------------------------------------
-- Check via assertions in netlist build that the frequency/period conversion functions
-- give the expected results. The same checks are done in simulation test cases.
-- -------------------------------------------------------------------------------------------------

library common;
use common.types_pkg.all;


entity test_frequency_conversion is

end entity;

architecture a of test_frequency_conversion is

begin

  --------------------------------------------------------------------------------------------------
  frequency_test_block : for test_idx in test_periods'range generate
    constant test_period : time := test_periods(test_idx);
    constant test_frequency_real : real := test_frequencies_real(test_idx);
    constant test_frequency_integer : positive := test_frequencies_integer(test_idx);

    constant tolerance_period_via_real : time := test_tolerances_period_via_real(test_idx);
    constant tolerance_period_via_integer : time := test_tolerances_period_via_integer(test_idx);
    constant tolerance_frequency_real : real := test_tolerances_frequency_real(test_idx);

    constant period_via_real : time := to_period(test_frequency_real);
    constant period_via_integer : time := to_period(test_frequency_integer);

    constant frequency_hz_real : real := to_frequency_hz(test_period);
    constant frequency_hz_integer : positive := to_frequency_hz(test_period);
  begin

    assert (
        period_via_real >= test_period - tolerance_period_via_real
        and period_via_real <= test_period + tolerance_period_via_real
      )
      report "Got period_via_real=" & time'image(period_via_real)
        & " expected test_period=" & time'image(test_period)
        & " (difference=" & time'image(period_via_real - test_period)
        & ", test_idx=" & natural'image(test_idx) & ")"
      severity failure;

    assert (
        period_via_integer >= test_period - tolerance_period_via_integer
        and period_via_integer <= test_period + tolerance_period_via_integer
      )
      report "Got period_via_integer=" & time'image(period_via_integer)
        & " expected test_period=" & time'image(test_period)
        & " (difference=" & time'image(period_via_integer - test_period)
        & ", test_idx=" & natural'image(test_idx) & ")"
      severity failure;

    assert (
        frequency_hz_real >= test_frequency_real - tolerance_frequency_real
        and frequency_hz_real <= test_frequency_real + tolerance_frequency_real
      )
      report "Got frequency_hz_real=" & real'image(frequency_hz_real)
        & " expected test_frequency_real_1=" & real'image(test_frequency_real)
        & " (difference=" & real'image(frequency_hz_real - test_frequency_real)
        & ", test_idx=" & natural'image(test_idx) & ")"
      severity failure;

    -- This one does not appear to ever have an error
    assert frequency_hz_integer = test_frequency_integer
      report "Got frequency_hz_integer=" & positive'image(frequency_hz_integer)
        & " expected test_frequency_integer_1=" & positive'image(test_frequency_integer)
        & " (difference=" & integer'image(frequency_hz_integer - test_frequency_integer)
        & ", test_idx=" & natural'image(test_idx) & ")"
      severity failure;

  end generate;

end architecture;
