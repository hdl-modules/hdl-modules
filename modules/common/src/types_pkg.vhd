-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the hdl_modules project, a collection of reusable, high-quality,
-- peer-reviewed VHDL building blocks.
-- https://hdl-modules.com
-- https://gitlab.com/hdl_modules/hdl_modules
-- -------------------------------------------------------------------------------------------------
-- Some basic types that make it easier to work with VHDL.
-- Also some basic functions operating on these types.
-- -------------------------------------------------------------------------------------------------

library ieee;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;


package types_pkg is

  type slv_vec_t is array (integer range <>) of std_ulogic_vector;
  type unsigned_vec_t is array (integer range <>) of u_unsigned;
  type signed_vec_t is array (integer range <>) of u_signed;

  type natural_vec_t is array (integer range <>) of natural;
  function sum(data : natural_vec_t) return natural;
  function get_maximum(data : natural_vec_t) return natural;

  type positive_vec_t is array (integer range <>) of positive;
  function sum(data : positive_vec_t) return positive;
  function get_maximum(values : positive_vec_t) return positive;

  type time_vec_t is array (integer range <>) of time;
  type real_vec_t is array (integer range <>) of real;
  type boolean_vec_t is array (integer range <>) of boolean;

  function to_sl(value : boolean) return std_ulogic;
  function to_bool(value : std_ulogic) return boolean;
  function to_bool(value : natural) return boolean;

  subtype binary_integer_t is integer range 0 to 1;
  function to_int(value : boolean) return binary_integer_t;
  function to_int(value : std_ulogic) return binary_integer_t;

  subtype binary_real_t is real range 0.0 to 1.0;
  function to_real(value : boolean) return binary_real_t;

  function swap_byte_order(data : std_ulogic_vector) return std_ulogic_vector;
  function swap_bit_order(data : std_ulogic_vector) return std_ulogic_vector;

  function count_ones(data : std_ulogic_vector) return natural;

  --------------------------------------------------------------------------------------------------
  -- Below are a couple of methods for working with the VHDL 'time' type.
  --
  -- The 'time' type can be tricky sometimes because its precision is implementation dependent,
  -- just like the integer and universal_integer types:
  --
  -- integer'high is
  -- * 2147483647 in GHDL 3.0.0-dev, corresponding to a 32 bit signed integer.
  -- * 2147483647 in Vivado 2021.2, corresponding to a 32 bit signed integer.
  --
  -- time'high is
  -- * 9223372036854775807 fs in GHDL 3.0.0-dev, corresponding to a 64 bit signed integer.
  --   Time values greater than this will result in an error.
  -- * 2147483647 fs in Vivado 2021.2, corresponding to a 32 bit signed integer.
  --   However, Vivado 2021.2 can represent time values greater than this since it uses a dynamic
  --   secondary unit for 'time', as outlined in IEEE Std 1076-2008, page 39.
  --   Precision is never greater than 32 bits though.
  --
  -- In the standard library, the following functions are available for working with
  -- 'time' values (IEEE Std 1076-2008, page 260):
  --  * function "=" (anonymous, anonymous: TIME) return BOOLEAN;
  --  * function "/=" (anonymous, anonymous: TIME) return BOOLEAN;
  --  * function "<" (anonymous, anonymous: TIME) return BOOLEAN;
  --  * function "<=" (anonymous, anonymous: TIME) return BOOLEAN;
  --  * function ">" (anonymous, anonymous: TIME) return BOOLEAN;
  --  * function ">=" (anonymous, anonymous: TIME) return BOOLEAN;
  --  * function "+" (anonymous: TIME) return TIME;
  --  * function "- (anonymous: TIME) return TIME;
  --  * function "abs" (anonymous: TIME) return TIME;
  --  * function "+" (anonymous, anonymous: TIME) return TIME;
  --  * function "-" (anonymous, anonymous: TIME) return TIME;
  --  * function "*" (anonymous: TIME; anonymous: INTEGER) return TIME;
  --  * function "*" (anonymous: TIME; anonymous: REAL) return TIME;
  --  * function "*" (anonymous: INTEGER; anonymous: TIME) return TIME;
  --  * function "*" (anonymous: REAL; anonymous: TIME) return TIME;
  --  * function "/" (anonymous: TIME; anonymous: INTEGER) return TIME;
  --  * function "/" (anonymous: TIME; anonymous: REAL) return TIME;
  --  * function "/" (anonymous, anonymous: TIME) return universal_integer;
  --  * function "mod" (anonymous, anonymous: TIME) return TIME;
  --  * function "rem" (anonymous, anonymous: TIME) return TIME;
  --  * function MINIMUM (L, R: TIME) return TIME;
  --  * function MAXIMUM (L, R: TIME) return TIME;
  --
  -- Notably missing is a convenient and accurate way of converting a 'time' value to 'real'
  -- or 'integer'.
  -- So that is most of the complexity in the conversion functions below.

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
  -- Manually rounded down versions of the above frequencies.
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
  --------------------------------------------------------------------------------------------------

  --------------------------------------------------------------------------------------------------
  -- Instead of e.g. writing
  --
  --   wait until (ready and valid) = '1' and rising_edge(clk);
  --
  -- in testbenches, these two operator functions can be used so that it is enough to write
  --
  --   wait until ready and valid and rising_edge(clk);
  --
  -- which is a lot shorter. Can also be used in implementation to the extent that std_logic/boolean
  -- are mixed.
  --
  -- The boolean type only has two states (true, false) whereas std_logic has many, including 'X',
  -- 'U', etc.
  -- These operator functions use '1' as the only std_logic state equivalent to the boolean state
  -- of "true".
  function "and" (left : boolean; right: std_ulogic) return boolean;
  function "and" (left : std_ulogic; right: boolean) return boolean;
  --------------------------------------------------------------------------------------------------

end package;

package body types_pkg is

  function sum(data : natural_vec_t) return natural is
    variable result : natural := 0;
  begin
    for data_idx in data'range loop
      result := result + data(data_idx);
    end loop;

    return result;
  end function;

  function get_maximum(data : natural_vec_t) return natural is
    variable result : natural := natural'low;
  begin
    for data_idx in data'range loop
      result := maximum(result, data(data_idx));
    end loop;

    return result;
  end function;

  function sum(data : positive_vec_t) return positive is
    variable result : natural := 0;
  begin
    for data_idx in data'range loop
      result := result + data(data_idx);
    end loop;

    return result;
  end function;

  function get_maximum(values : positive_vec_t) return positive is
    -- Minimum possible value
    variable result : positive := 1;
  begin
    for value_idx in values'range loop
      result := maximum(result, values(value_idx));
    end loop;
    return result;
  end function;

  function to_sl(value : boolean) return std_ulogic is
  begin
    if value then
      return '1';
    end if;
    return '0';
  end function;

  function to_bool(value : std_ulogic) return boolean is
  begin
    if value = '1' then
      return true;
    elsif value = '0' then
      return false;
    end if;
    assert false report "Can not convert value: " & std_logic'image(value) severity failure;
    return false;
  end function;

  function to_bool(value : natural) return boolean is
  begin
    if value = 1 then
      return true;
    end if;
    if value = 0 then
      return false;
    end if;

    assert false report "Can not convert value: " & natural'image(value) severity failure;
    return false;
  end function;

  function to_int(value : boolean) return binary_integer_t is
  begin
    if value then
      return 1;
    else
      return 0;
    end if;
  end function;

  function to_int(value : std_ulogic) return binary_integer_t is
  begin
    if value = '1' then
      return 1;
    end if;
    return 0;
  end function;

  function to_real(value : boolean) return binary_real_t is
  begin
    if value then
      return 1.0;
    end if;
    return 0.0;
  end function;

  function swap_byte_order(data : std_ulogic_vector) return std_ulogic_vector is
    variable result : std_ulogic_vector(data'range);
    constant num_bytes : integer := data'length / 8;
    variable result_byte_idx : integer;
  begin
    -- Swap endianness of the input word.
    -- I.e., while maintaining the range and vector direction, swap the location of the data bytes.

    assert data'left > data'right report "Only use with descending range" severity failure;
    assert data'length mod 8 = 0 report "Must be a whole number of bytes" severity failure;

    for input_byte_idx in 0 to num_bytes - 1 loop
      result_byte_idx := num_bytes - 1 - input_byte_idx;
      result(result'low + result_byte_idx * 8 + 7 downto result'low + result_byte_idx * 8) :=
        data(data'low + input_byte_idx * 8 + 7 downto data'low + input_byte_idx * 8);
    end loop;

    return result;
  end function;

  function swap_bit_order(data : std_ulogic_vector) return std_ulogic_vector is
    constant length : positive := data'length;
    variable result : std_ulogic_vector(data'range);
  begin
    -- While maintaining the range and vector direction, swap the location of the data bits.

    for idx in 0 to length - 1 loop
      result(result'low + idx) := data(data'high - idx);
    end loop;

    return result;
  end function;

  function count_ones(data : std_ulogic_vector) return natural is
    variable result : integer range 0 to data'length := 0;
  begin
    for bit_idx in data'range loop
      result := result + to_int(data(bit_idx));
    end loop;
    return result;
  end function;

  --------------------------------------------------------------------------------------------------
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
  --------------------------------------------------------------------------------------------------

  --------------------------------------------------------------------------------------------------
  function "and" (left : boolean; right: std_ulogic) return boolean is
  begin
    return left and (right = '1');
  end function;

  function "and" (left : std_ulogic; right: boolean) return boolean is
  begin
    return (left = '1') and right;
  end function;
  --------------------------------------------------------------------------------------------------

end package body;
