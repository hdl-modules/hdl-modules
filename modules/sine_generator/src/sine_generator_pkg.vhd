-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the hdl-modules project, a collection of reusable, high-quality,
-- peer-reviewed VHDL building blocks.
-- https://hdl-modules.com
-- https://github.com/hdl-modules/hdl-modules
-- -------------------------------------------------------------------------------------------------
-- Package with constants/types/functions for the sine generator ecosystem.
-- -------------------------------------------------------------------------------------------------

library ieee;
use ieee.numeric_std.all;
use ieee.math_real.all;


package sine_generator_pkg is

  -- Get the width of the phase accumulator and the phase increment port.
  -- Set arguments to the same values as the generic values to your entity instantiation.
  function get_phase_width(
    memory_address_width : positive; phase_fractional_width : natural
  ) return positive;

  -- Get the phase increment needed to synthesize a sine wave of the given frequency.
  -- Note that this function will truncate the phase increment to the nearest
  -- 'phase_accumulator_width' integer.
  -- It is up to the user to analyze the frequency resolution requirements of the application (see
  -- module documentation).
  function get_phase_increment(
    -- Switching frequency of the clock signal to the module.
    clk_frequency_hz : positive;
    -- Target frequency of the generated sine wave.
    sine_frequency_hz : positive;
    -- Number of bits in the phase counter, provided by the 'get_phase_width' function give your
    -- generic parameterization of the module.
    phase_width : positive
  ) return u_unsigned;

end package;

package body sine_generator_pkg is

  function get_phase_width(
    memory_address_width : positive; phase_fractional_width : natural
  ) return positive is
  begin
    -- +2 for the quadrant indicator, given that only one quadrant is stored in memory.
    return memory_address_width + 2 + phase_fractional_width;
  end function;

  function get_phase_increment(
    clk_frequency_hz : positive;
    sine_frequency_hz : positive;
    phase_width : positive
  ) return u_unsigned is
    constant nyquist_frequency_hz : real := real(clk_frequency_hz) / 2.0;
    constant max_increment : real := 2.0 ** real(phase_width);
    constant ratio : real := real(sine_frequency_hz) / real(clk_frequency_hz);
    constant target_increment : real := ratio * max_increment;

    constant result : u_unsigned(phase_width - 1 downto 0) := to_unsigned(
      integer(round(target_increment)), phase_width
    );
  begin
    assert real(sine_frequency_hz) < nyquist_frequency_hz
      report "Cannot synthesize this sine wave"
      severity failure;

    assert result > 0 report "Phase increment is zero" severity failure;

    return result;
  end function;

end package body;
