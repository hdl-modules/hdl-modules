-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the hdl-modules project, a collection of reusable, high-quality,
-- peer-reviewed VHDL building blocks.
-- https://hdl-modules.com
-- https://github.com/hdl-modules/hdl-modules
-- -------------------------------------------------------------------------------------------------
-- Contains a couple of methods for working with the VHDL ``time`` type.
--
-- The ``time`` type can be tricky sometimes because its precision is implementation dependent,
-- just like the ``integer`` and ``universal_integer`` types:
--
-- ``integer'high`` is
--
-- * 2147483647 in GHDL 3.0.0-dev, corresponding to a 32 bit signed integer.
-- * 2147483647 in Vivado 2021.2, corresponding to a 32 bit signed integer.
--
-- ``time'high`` is
--
-- * 9223372036854775807 fs in GHDL 3.0.0-dev, corresponding to a 64 bit signed integer.
--   Time values greater than this will result in an error.
-- * 2147483647 fs in Vivado 2021.2, corresponding to a 32 bit signed integer.
--   However, Vivado 2021.2 can represent time values greater than this since it uses a dynamic
--   secondary unit for ``time``, as outlined in IEEE Std 1076-2008, page 39.
--   Precision is never greater than 32 bits though.
--
-- In the standard library, the following functions are available for working with
-- ``time`` values (IEEE Std 1076-2008, page 260):
--
-- .. code-block::
--
--   function "=" (anonymous, anonymous: TIME) return BOOLEAN;
--   function "/=" (anonymous, anonymous: TIME) return BOOLEAN;
--   function "<" (anonymous, anonymous: TIME) return BOOLEAN;
--   function "<=" (anonymous, anonymous: TIME) return BOOLEAN;
--   function ">" (anonymous, anonymous: TIME) return BOOLEAN;
--   function ">=" (anonymous, anonymous: TIME) return BOOLEAN;
--   function "+" (anonymous: TIME) return TIME;
--   function "- (anonymous: TIME) return TIME;
--   function "abs" (anonymous: TIME) return TIME;
--   function "+" (anonymous, anonymous: TIME) return TIME;
--   function "-" (anonymous, anonymous: TIME) return TIME;
--   function "*" (anonymous: TIME; anonymous: INTEGER) return TIME;
--   function "*" (anonymous: TIME; anonymous: REAL) return TIME;
--   function "*" (anonymous: INTEGER; anonymous: TIME) return TIME;
--   function "*" (anonymous: REAL; anonymous: TIME) return TIME;
--   function "/" (anonymous: TIME; anonymous: INTEGER) return TIME;
--   function "/" (anonymous: TIME; anonymous: REAL) return TIME;
--   function "/" (anonymous, anonymous: TIME) return universal_integer;
--   function "mod" (anonymous, anonymous: TIME) return TIME;
--   function "rem" (anonymous, anonymous: TIME) return TIME;
--   function MINIMUM (L, R: TIME) return TIME;
--   function MAXIMUM (L, R: TIME) return TIME;
--
-- Notably missing is a convenient and accurate way of converting a ``time`` value to ``real``
-- or ``integer``.
-- So that is most of the complexity in the conversion functions below.
-- -------------------------------------------------------------------------------------------------

use work.types_pkg.all;


package time_pkg is

  -- Convert a 'time' value to a floating point number of seconds.
  -- It would be lovely if this was part of the standard library.
  function to_real_s(value : time) return real;

  -- Functions for converting between frequency and period values using the 'time' type.
  -- Doing these operations has historically been very risky with Vivado.
  -- Hence the conversion functions are verified using assertions in a netlist build.
  -- They are also checked to give identical results in simulation test cases.
  function to_period(frequency_hz : real) return time;
  function to_period(frequency_hz : positive) return time;
  function to_frequency_hz(period : time) return real;
  function to_frequency_hz(period : time) return positive;

  -- Test values, both in high range and low range: 468 MHz, 513 KHz, 2.47 Hz.
  -- Used in both simulation and netlist build Vivado checker.
  -- Note that the last one must be expressed in 'ns' since an 'fs' value would be too large
  -- for Vivado to represent.
  constant test_periods : time_vec_t(0 to 2) := (2_134_217 fs, 1_946_581_198 fs, 404_858_791 ns);
  -- Inverse of periods above, calculated in Python 3.10.
  constant test_frequencies_real : real_vec_t(0 to 2)
    := (468_555_915.35443676, 513_721.1851359925, 2.469997001991739);
  -- Rounded version of the above frequencies.
  constant test_frequencies_integer : positive_vec_t(0 to 2) := (468_555_915, 513_721, 2);

  -- Acceptable tolerances, for both simulation and netlist build Vivado checker, listed below:

  -- 'time' period calculated from 'integer' frequency
  -- The non-zero tolerance here comes from the fact that the integer value is a truncated
  -- version of the 'real' value.
  constant test_tolerances_period_from_integer_frequency : time_vec_t(0 to 2) :=
    (1 fs, 750 fs, 600 ms);

  -- 'real' frequency calculated from 'time' period
  -- Relative error roughly
  -- 0: 10**-16
  -- 1: 10**-15
  -- 2: 10**-15
  -- which is very low and should be acceptable.
  constant test_tolerances_real_frequency_from_period : real_vec_t(0 to 2)
    := (1.0e-7, 1.0e-9, 1.0e-15);

  -- No error (in the chosen test cases at least) from
  -- * 'integer' frequency calculated from 'time' period
  -- * 'time' period calculated from 'real' frequency

end package;

package body time_pkg is

  function to_real_s(value : time) return real is
    constant max_fs_integer : time := integer'high * (1 fs);
    constant max_ps_integer : time := integer'high * (1 ps);
    constant max_ns_integer : time := integer'high * (1 ns);
    constant max_us_integer : time := integer'high * (1 us);

    -- 'max_us_integer' above is 61 unsigned bits.
    -- We can not go higher than this since that gives an error in GHDL.
    -- Vivado gives no such error since it uses a dynamic secondary unit for 'time'.
    -- The value of 'max_us_integer' corresponds to roughly 35 minutes, so there is not any
    -- practical FPGA case for going above it.

    variable value_integer : integer := 0;
    variable to_s_factor, value_real_s : real := 0.0;
  begin
    -- Use the 'time' / 'time' -> 'universal_integer' function to get an integer value for
    -- the time.
    -- Use the smallest denominator possible so that we maintain precision.
    -- However, for high 'time' values the resulting integer would go out of range with the
    -- smallest denominator.
    -- Hence we have this if-else chain where we prefer the smallest denominator.
    -- This makes sure we support conversion of everything from 1 fs all the way to the upper limit
    -- of the 'time' type (35 min in GHDL) with very low error (in most cases zero).

    if value <= max_fs_integer then
      value_integer := value / (1 fs);
      to_s_factor := 1.0e-15;

    elsif value <= max_ps_integer then
      value_integer := value / (1 ps);
      to_s_factor := 1.0e-12;

    elsif value <= max_ns_integer then
      value_integer := value / (1 ns);
      to_s_factor := 1.0e-9;

    elsif value <= max_us_integer then
      value_integer := value / (1 us);
      to_s_factor := 1.0e-6;

    else
      assert false
        report "This time is too great to be supported: " & time'image(value)
        severity failure;

    end if;

    value_real_s := real(value_integer) * to_s_factor;
    return value_real_s;
  end function;

  function to_period(frequency_hz : real) return time is
    -- Using 'time' / 'real' -> 'time' function.
    -- Should give maximum precision, compared to e.g. casting to integer.
    constant period : time := (1 sec) / frequency_hz;
  begin
    return period;
  end function;

  function to_period(frequency_hz : positive) return time is
    constant frequency_hz_real : real := real(frequency_hz);
    constant period : time := to_period(frequency_hz_real);
  begin
    -- Use the floating point function straight away.
    return period;
  end function;

  function to_frequency_hz(period : time) return real is
    constant period_s : real := to_real_s(period);
    constant frequency_hz : real := 1.0 / period_s;
  begin
    return frequency_hz;
  end function;

  function to_frequency_hz(period : time) return positive is
    constant frequency_hz_real : real := to_frequency_hz(period);
  begin
    -- Use the floating point function to get a value that is then converted to integer.
    -- When converting to integer there can occur an overflow if the period is too small.
    -- This is checked here.
    -- The limit, assuming a 32 bit unsigned integer type, is 2**31 - 1 Hz = 2.147 GHz.
    assert frequency_hz_real <= real(positive'high)
      report "Can not handle this period without integer overflow: " & time'image(period)
      severity failure;

    return positive(frequency_hz_real);
  end function;

end package body;
