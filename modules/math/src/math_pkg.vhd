-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the hdl_modules project, a collection of reusable, high-quality,
-- peer-reviewed VHDL building blocks.
-- https://hdl-modules.com
-- https://gitlab.com/hdl_modules/hdl_modules
-- -------------------------------------------------------------------------------------------------
-- Package with some common mathematical functions.
-- -------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;


package math_pkg is

  ------------------------------------------------------------------------------
  -- The maximum value that can be expressed in a signed bit vector of the supplied length.
  function get_min_signed(num_bits : positive) return signed;
  function get_max_signed(num_bits : positive) return signed;

  -- Same as above but result value given as an integer.
  -- Note that this limits the number of bits to 32.
  function get_min_signed_integer(num_bits : positive) return integer;
  function get_max_signed_integer(num_bits : positive) return natural;

  -- The maximum value that can be expressed in an unsigned bit vector of the supplied length,
  -- with result value given as an integer.
  -- Note that this limits the number of bits to 32.
  function get_max_unsigned_integer(num_bits : positive) return positive;
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
  ------------------------------------------------------------------------------

  ------------------------------------------------------------------------------
  function num_bits_needed(value : natural) return positive;
  function num_bits_needed(value : u_unsigned) return positive;
  ------------------------------------------------------------------------------

  ------------------------------------------------------------------------------
  function lt_0(value  : u_signed) return boolean;
  function geq_0(value : u_signed) return boolean;
  ------------------------------------------------------------------------------

  ------------------------------------------------------------------------------
  function to_gray(value : u_unsigned) return std_ulogic_vector;
  function from_gray(code : std_ulogic_vector) return u_unsigned;
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

  function get_min_signed_integer(num_bits : positive) return integer is
    constant min_signed : signed(num_bits - 1 downto 0) := get_min_signed(num_bits=>num_bits);
    variable result : integer := 0;
  begin
    assert num_bits <= 32
      report "Calculation does not work for this many bits: " & integer'image(num_bits)
      severity failure;

    result := to_integer(min_signed);

    return result;
  end function;

  function get_max_signed_integer(num_bits : positive) return natural is
    constant max_signed : signed(num_bits - 1 downto 0) := get_max_signed(num_bits=>num_bits);
    variable result : natural := 0;
  begin
    assert num_bits <= 32
      report "Calculation does not work for this many bits: " & integer'image(num_bits)
      severity failure;

    result := to_integer(max_signed);

    return result;
  end function;

  function get_max_unsigned_integer(num_bits : positive) return positive is
    constant max_unsigned : unsigned(num_bits - 1 downto 0) := (others => '1');
    variable result : positive := 1;
  begin
    assert num_bits <= 32
      report "Calculation does not work for this many bits: " & integer'image(num_bits)
      severity failure;

    result := to_integer(max_unsigned);

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
    assert min'length <= value'length report "Min value can not be assigned" severity failure;
    assert max'length <= value'length report "Max value can not be assigned" severity failure;

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
    assert is_power_of_two(value)
      report "Must be power of two: " & to_string(value)
      severity failure;
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
    -- doing simply "if value <= 0 then ...", hence this bit operation is used instead.
    return value(value'left) = '0';
  end function;
  ------------------------------------------------------------------------------

  ------------------------------------------------------------------------------
  function num_bits_needed(value : u_unsigned) return positive is
  begin
    -- The number of bits needed to express the given value.
    assert value'high > value'low report "Use only with descending range" severity failure;
    assert value'low = 0 report "Use vector that starts at zero" severity failure;

    for bit_idx in value'high downto value'low loop
      if value(bit_idx) = '1' then
        return bit_idx + 1;
      end if;
    end loop;
    return 1;
  end function;

  function num_bits_needed(value : natural) return positive is
    constant value_vector : u_unsigned(64 - 1 downto 0) := to_unsigned(value, 64);
    constant result : positive := num_bits_needed(value_vector);
  begin
    -- The number of bits needed to express the given value in an u_unsigned vector.
    assert value <= 2**result - 1
      report "Calculated value not correct: " & to_string(value) & " " & to_string(result)
      severity failure;
    return result;
  end function;
  ------------------------------------------------------------------------------

  ------------------------------------------------------------------------------
  function to_gray(value : u_unsigned) return std_ulogic_vector is
    variable value_slv, result : std_ulogic_vector(value'range);
  begin
    value_slv := std_logic_vector(value);
    result := value_slv xor "0" & value_slv(value_slv'high downto 1);
    return result;
  end function;

  function from_gray(code : std_ulogic_vector) return u_unsigned is
    variable result : u_unsigned(code'range);
  begin
    result(code'high) := code(code'high);
    for bit_num in code'high -1 downto 0 loop
      result(bit_num) := result(bit_num + 1) xor code(bit_num);
    end loop;

    return result;
  end function;
  ------------------------------------------------------------------------------

  ------------------------------------------------------------------------------
  function abs_vector(vector : integer_vector) return integer_vector is
    variable result : integer_vector(vector'range);
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
    variable tmp, smaller_value, larger_value : natural;
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
