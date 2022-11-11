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
  -- Functions for converting between frequency and period values using the 'time' type.
  -- Doing these operations have historically been very risky with Vivado.
  -- Hence the conversion functions are verified using assertions in a netlist build.
  -- They are also checked to give identical results in simulation test cases.
  function to_period(frequency_hz : real) return time;
  function to_period(frequency_hz : positive) return time;
  function to_frequency_hz(period : time) return real;
  function to_frequency_hz(period : time) return positive;

  -- Test values, both in high range and low range: 468 MHz, 513 Khz.
  constant test_periods : time_vec_t(0 to 1) := (2_134_217 fs, 1_946_581_198 fs);
  constant test_frequencies_real : real_vec_t(0 to 1)
    := (468_555_915.354436779, 513_721.185136);
  constant test_frequencies_integer : positive_vec_t(0 to 1) := (468_555_915, 513_721);

  constant test_tolerances_period_via_real : time_vec_t(0 to 1) := (0 fs, 1 fs);
  constant test_tolerances_period_via_integer : time_vec_t(0 to 1) := (1 fs, 750 fs);
  constant test_tolerances_frequency_real : real_vec_t(0 to 1) := (0.0, 0.0001);
  -- Period to integer frequency seems to give no error (in the test cases at least)
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
    assert false report "Can not convert value: " & std_ulogic'image(value) severity failure;
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
  function to_period(frequency_hz : real) return time is
    -- Using 'time' / 'real' -> 'time' function (IEEE Std 1076-2008, pp. 260).
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
    -- Using 'time' / 'time' -> 'universal_integer' function (IEEE Std 1076-2008, pp. 260).
    -- Note that 'universal_integer' range is implementation dependent.
    -- 'time' range is also implementation dependent, but guaranteed to be at least 32 bit
    -- u_signed integer (pp. 41).
    -- Vivado seems to handle 'universal_integer' as a 32 bit u_signed integer.
    -- We divide by "1 fs" below, in order to preserve the maximum resolution as a fixed point
    -- number before converting to a floating point number.
    -- The 'period_fs' value can overflow for 'period' values that are too small.
    -- A check for this is done below.
    constant period_fs : integer := period / (1 fs);
    constant frequency_hz : real := 1.0e15 / real(period_fs);
  begin
    -- 2**31 - 1 fs. Means that frequency has to be greater than 466 kHz.
    assert period <= (1 fs) * integer'high
      report "Can not handle this period without integer overflow: " & time'image(period)
      severity failure;

    return frequency_hz;
  end function;

  function to_frequency_hz(period : time) return positive is
    constant frequency_hz_real : real := to_frequency_hz(period);
  begin
    -- Use the floating point function, with the check that period is not too great, to get a value
    -- that is then converted to integer. When converting to integer there can additionally
    -- occur an overflow if the period is too small. This is checked here.
    -- 2**31 - 1 Hz. Means that frequency must be less than 2147 MHz.
    assert frequency_hz_real <= real(positive'high)
      report "Can not handle this period without integer overflow: " & time'image(period)
      severity failure;

    return positive(frequency_hz_real);
  end function;
  --------------------------------------------------------------------------------------------------

end package body;
