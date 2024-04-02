-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the hdl-modules project, a collection of reusable, high-quality,
-- peer-reviewed VHDL building blocks.
-- https://hdl-modules.com
-- https://github.com/hdl-modules/hdl-modules
-- -------------------------------------------------------------------------------------------------
-- Package with some common mathematical functions.
-- -------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

library common;
use common.types_pkg.all;


package math_pkg is

  ------------------------------------------------------------------------------
  -- The smallest/greatest value that can be expressed in a signed bit vector of the
  -- supplied length.
  function get_min_signed(num_bits : positive) return signed;
  function get_max_signed(num_bits : positive) return signed;

  -- Same as above but result value given as an integer.
  -- Note that this limits the number of bits to 32.
  function get_min_signed_integer(num_bits : positive range 1 to 32) return integer;
  function get_max_signed_integer(num_bits : positive range 1 to 32) return natural;

  -- The smallest/greatest value that can be expressed in an unsigned bit vector of the
  -- supplied length.
  function get_min_unsigned(num_bits : positive) return unsigned;
  function get_max_unsigned(num_bits : positive) return unsigned;

  -- Same as above but result value given as an integer.
  -- Note that this limits the number of bits to 32.
  function get_max_unsigned_integer(num_bits : positive range 1 to 32) return positive;
  ------------------------------------------------------------------------------

  ------------------------------------------------------------------------------
  -- Limit the supplied 'value' to the inclusive range [min, max].

  function clamp(value, min, max : integer) return integer;
  -- Note that 'value' may be wider than 'min' and/or 'max' but not the other way around.
  -- Width of result value is the same width as 'value'.
  function clamp(value, min, max : signed) return signed;
  ------------------------------------------------------------------------------

  ------------------------------------------------------------------------------
  function ceil_log2(value : positive) return natural;
  function log2(value : positive) return natural;
  function is_power_of_two(value : positive) return boolean;
  function round_up_to_power_of_two(value : positive) return positive;
  function round_up_to_power_of_two(value : real range 1.0 to real'high) return real;
  ------------------------------------------------------------------------------

  ------------------------------------------------------------------------------
  -- The minimum number of bits needed to express the given value as an unsigned vector.
  function num_bits_needed(value : u_unsigned) return positive;
  -- The number of bits needed to express the given value as an unsigned vector.
  function num_bits_needed(value : natural) return positive;

  -- The number of bits needed to express the value as a signed vector.
  function num_bits_needed_signed(value : integer) return positive;
  -- The number of bits required to express each of the values as a signed vector.
  function num_bits_needed_signed(values : integer_vec_t) return positive;
  -- The number of bits required to express each of the values as a signed vector.
  function num_bits_needed_signed(values : integer_matrix_t) return positive;
  ------------------------------------------------------------------------------

  ------------------------------------------------------------------------------
  function lt_0(value  : u_signed) return boolean;
  function geq_0(value : u_signed) return boolean;
  ------------------------------------------------------------------------------

  ------------------------------------------------------------------------------
  function to_gray(value : u_unsigned) return std_ulogic_vector;
  function from_gray(code : std_ulogic_vector) return u_unsigned;

  -- The number of bits that differ when comparing the two vectors.
  function hamming_distance(data1, data2 : std_ulogic_vector) return natural;
  ------------------------------------------------------------------------------

  ------------------------------------------------------------------------------
  function abs_vector(vector : integer_vector) return integer_vector;
  function vector_sum(vector : integer_vector) return integer;
  ------------------------------------------------------------------------------

  ------------------------------------------------------------------------------
  function greatest_common_divisor(value1, value2 : positive) return positive;
  function is_mutual_prime(candidate : positive; check_against : integer_vector) return boolean;
  ------------------------------------------------------------------------------

end package;

package body math_pkg is

  ------------------------------------------------------------------------------
  function get_min_signed(num_bits : positive) return signed is
    variable result : signed(num_bits - 1 downto 0) := (others => '0');
  begin
    result(result'high) := '1';
    return result;
  end function;

  function get_max_signed(num_bits : positive) return signed is
    variable result : signed(num_bits - 1 downto 0) := (others => '1');
  begin
    result(result'high) := '0';
    return result;
  end function;

  function get_min_signed_integer(num_bits : positive range 1 to 32) return integer is
    constant min_signed : signed(num_bits - 1 downto 0) := get_min_signed(num_bits=>num_bits);
    constant result : integer := to_integer(min_signed);
  begin
    return result;
  end function;

  function get_max_signed_integer(num_bits : positive range 1 to 32) return natural is
    constant max_signed : signed(num_bits - 1 downto 0) := get_max_signed(num_bits=>num_bits);
    constant result : natural := to_integer(max_signed);
  begin
    return result;
  end function;

  function get_min_unsigned(num_bits : positive) return unsigned is
    constant result : unsigned(num_bits - 1 downto 0) := (others => '0');
  begin
    return result;
  end function;

  function get_max_unsigned(num_bits : positive) return unsigned is
    constant result : unsigned(num_bits - 1 downto 0) := (others => '1');
  begin
    return result;
  end function;

  function get_max_unsigned_integer(num_bits : positive range 1 to 32) return positive is
    constant max_unsigned : unsigned(num_bits - 1 downto 0) := get_max_unsigned(num_bits=>num_bits);
    constant result : positive := to_integer(max_unsigned);
  begin
    return result;
  end function;
  ------------------------------------------------------------------------------

  ------------------------------------------------------------------------------
  function clamp(value, min, max : integer) return integer is
  begin
    if value < min then
      return min;
    end if;

    if value > max then
      return max;
    end if;

    return value;
  end function;

  function clamp(value, min, max : signed) return signed is
  begin
    assert min'length <= value'length report "Min value can not be assigned";
    assert max'length <= value'length report "Max value can not be assigned";

    if value < min then
      return resize(min, value'length);
    end if;

    if value > max then
      return resize(max, value'length);
    end if;

    return value;
  end function;
  ------------------------------------------------------------------------------

  ------------------------------------------------------------------------------
  function ceil_log2(value : positive) return natural is
  begin
    -- 2-base logarithm rounded up
    return natural(ceil(log2(real(value))));
  end function;

  function floor_log2(value : positive) return natural is
  begin
    return natural(log2(real(value)));
  end function;

  function log2(value : positive) return natural is
  begin
    -- 2-base logarithm where argument must be a power of two
    assert is_power_of_two(value) report "Must be power of two: " & to_string(value);

    return floor_log2(value);
  end function;

  function is_power_of_two(value : positive) return boolean is
    constant log2_value : natural := floor_log2(value);
  begin
    return 2 ** log2_value = value;
  end function;

  function round_up_to_power_of_two(value : positive) return positive is
  begin
    return 2 ** ceil_log2(value);
  end function;

  function round_up_to_power_of_two(value : real range 1.0 to real'high) return real is
    constant value_integer : positive := positive(ceil(value));
    constant result_integer : positive := round_up_to_power_of_two(value_integer);
  begin
    return real(result_integer);
  end function;
  ------------------------------------------------------------------------------

  ------------------------------------------------------------------------------
  function lt_0(value : u_signed) return boolean is
  begin
    -- The Vivado synthesis engine has been shown to produce a lot of logic (20-30 LUTs) when
    -- doing simply "if value < 0 then ...", hence this bit operation is used instead.
    return value(value'left) = '1';
  end function;

  function geq_0(value : u_signed) return boolean is
  begin
    -- The Vivado synthesis engine has been shown to produce a lot of logic (20-30 LUTs) when
    -- doing simply "if value >= 0 then ...", hence this bit operation is used instead.
    return value(value'left) = '0';
  end function;
  ------------------------------------------------------------------------------

  ------------------------------------------------------------------------------
  function num_bits_needed(value : u_unsigned) return positive is
  begin
    assert value'high > value'low report "Use only with descending range" severity failure;
    assert value'low = 0 report "Use vector that starts at zero" severity failure;

    for bit_idx in value'high downto value'low loop
      if value(bit_idx) = '1' then
        return bit_idx + 1;
      end if;
    end loop;

    -- Special case when value is zero.
    return 1;
  end function;

  function num_bits_needed(value : natural) return positive is
    constant value_vector : u_unsigned(64 - 1 downto 0) := to_unsigned(value, 64);
    constant result : positive := num_bits_needed(value_vector);
  begin
    assert value <= 2**result - 1
      report "Calculated value not correct: " & to_string(value) & " " & to_string(result)
      severity failure;

    return result;
  end function;

  function num_bits_needed_signed(value : integer) return positive is
    constant value_vector : u_signed(64 - 1 downto 0) := to_signed(value, 64);
  begin
    for bit_idx in value_vector'high downto value_vector'low loop
      if value_vector(bit_idx) = not value_vector(value_vector'high) then
        return bit_idx + 1 + 1;
      end if;
    end loop;

    -- Special case when value is zero.
    return 1;
  end function;

  function num_bits_needed_signed(values : integer_vec_t) return positive is
    variable result : positive := 1;
  begin
    for value_idx in values'range loop
      result := maximum(result, num_bits_needed_signed(value=>values(value_idx)));
    end loop;
    return result;
  end function;

  function num_bits_needed_signed(values : integer_matrix_t) return positive is
    variable result : positive := 1;
  begin
    for first_dimension_idx in values'range loop
      for second_dimension_idx in values(0)'range loop
        result := maximum(
          result, num_bits_needed_signed(value=>values(first_dimension_idx)(second_dimension_idx))
        );
      end loop;
    end loop;
    return result;
  end function;
  ------------------------------------------------------------------------------

  ------------------------------------------------------------------------------
  function to_gray(value : u_unsigned) return std_ulogic_vector is
    variable value_slv, result : std_ulogic_vector(value'range) := (others => '0');
  begin
    value_slv := std_logic_vector(value);
    result := value_slv xor "0" & value_slv(value_slv'high downto 1);
    return result;
  end function;

  function from_gray(code : std_ulogic_vector) return u_unsigned is
    variable result : u_unsigned(code'range) := (others => '0');
  begin
    result(code'high) := code(code'high);
    for bit_num in code'high - 1 downto 0 loop
      result(bit_num) := result(bit_num + 1) xor code(bit_num);
    end loop;

    return result;
  end function;

  function hamming_distance(data1, data2 : std_ulogic_vector) return natural is
    constant xor_value : std_ulogic_vector(data1'range) := data1 xor data2;
    constant result : natural range 0 to data1'length := count_ones(xor_value);
  begin
    assert data1'length = data2'length report "Arguments must be of equal length" severity failure;
    return result;
  end function;
  ------------------------------------------------------------------------------

  ------------------------------------------------------------------------------
  function abs_vector(vector : integer_vector) return integer_vector is
    variable result : integer_vector(vector'range) := (others => 0);
  begin
    for idx in vector'range loop
      result(idx) := abs(vector(idx));
    end loop;
    return result;
  end function;

  function vector_sum(vector : integer_vector) return integer is
    variable result : integer := 0;
  begin
    for idx in vector'range loop
      result := result + vector(idx);
    end loop;
    return result;
  end function;
  ------------------------------------------------------------------------------

  ------------------------------------------------------------------------------
  function greatest_common_divisor(value1, value2 : positive) return positive is
    variable tmp, smaller_value, larger_value : natural := 0;
  begin
    -- Calculate the greatest_common_divisor between two values.
    -- Uses the euclidean algorithm
    smaller_value := minimum(value1, value2);
    larger_value := maximum(value1, value2);

    while smaller_value /= 0 loop
      tmp := smaller_value;
      smaller_value := larger_value mod smaller_value;
      larger_value := tmp;
    end loop;

    return larger_value;
  end function;

  function is_mutual_prime(candidate : positive; check_against : integer_vector) return boolean is
  begin
    -- Check if a number is a mutual prime (i.e. the greatest common divisor is one)
    -- with all numbers in a list.
    for idx in check_against'range loop
      if greatest_common_divisor(candidate, check_against(idx)) /= 1 then
        return false;
      end if;
    end loop;

    -- Greatest common divisor was 1 with all other factors, meaning that this
    -- factor was a mutual prime with all.
    return true;
  end function;
  ------------------------------------------------------------------------------

end package body;
