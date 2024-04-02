-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the hdl-modules project, a collection of reusable, high-quality,
-- peer-reviewed VHDL building blocks.
-- https://hdl-modules.com
-- https://github.com/hdl-modules/hdl-modules
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

  type integer_vec_t is array (integer range <>) of integer;
  type integer_matrix_t is array (integer range <>) of integer_vec_t;

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
  function count_ones(data : u_unsigned) return natural;

  --------------------------------------------------------------------------------------------------
  -- Check that the value is well-defined, meaning '0' or '1'.
  -- No 'X', 'U', '-', etc.
  -- Roughly the inverse of 'is_x' in std_logic_1164 package, but it does not accept 'L' and 'H'.
  function is_01(value : std_ulogic) return boolean;
  function is_01(value : std_ulogic_vector) return boolean;
  function is_01(value : u_unsigned) return boolean;
  function is_01(value : u_signed) return boolean;
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

  function "and" (left : boolean; right: std_ulogic) return std_ulogic;
  function "and" (left : std_ulogic; right: boolean) return std_ulogic;
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
    assert false report "Can not convert value: " & std_logic'image(value);
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

    assert false report "Can not convert value: " & natural'image(value);
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
    variable result : std_ulogic_vector(data'range) := (others => '0');
    constant num_bytes : positive := data'length / 8;
    variable result_byte_idx : natural := 0;
  begin
    -- Swap endianness of the input word.
    -- I.e., while maintaining the range and vector direction, swap the location of the data bytes.

    assert data'left > data'right report "Only use with descending range";
    assert data'length mod 8 = 0 report "Must be a whole number of bytes";

    for input_byte_idx in 0 to num_bytes - 1 loop
      result_byte_idx := num_bytes - 1 - input_byte_idx;
      result(result'low + result_byte_idx * 8 + 7 downto result'low + result_byte_idx * 8) :=
        data(data'low + input_byte_idx * 8 + 7 downto data'low + input_byte_idx * 8);
    end loop;

    return result;
  end function;

  function swap_bit_order(data : std_ulogic_vector) return std_ulogic_vector is
    constant length : positive := data'length;
    variable result : std_ulogic_vector(data'range) := (others => '0');
  begin
    -- While maintaining the range and vector direction, swap the location of the data bits.

    for idx in 0 to length - 1 loop
      result(result'low + idx) := data(data'high - idx);
    end loop;

    return result;
  end function;

  function count_ones(data : std_ulogic_vector) return natural is
    variable result : natural range 0 to data'length := 0;
  begin
    for bit_idx in data'range loop
      result := result + to_int(data(bit_idx));
    end loop;
    return result;
  end function;

  function count_ones(data : u_unsigned) return natural is
    constant result : natural range 0 to data'length := count_ones(data=>std_logic_vector(data));
  begin
    return result;
  end function;

  --------------------------------------------------------------------------------------------------
  function is_01(value : std_ulogic) return boolean is
  begin
    return value = '0' or value = '1';
  end function;

  function is_01(value : std_ulogic_vector) return boolean is
  begin
    for idx in value'range loop
      if value(idx) /= '0' and value(idx) /= '1' then
        return false;
      end if;
    end loop;

    return true;
  end function;

  function is_01(value : u_unsigned) return boolean is
  begin
    return is_01(std_logic_vector(value));
  end function;

  function is_01(value : u_signed) return boolean is
  begin
    return is_01(std_logic_vector(value));
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

  function "and" (left : boolean; right: std_ulogic) return std_ulogic is
  begin
    return to_sl(left) and right;
  end function;

  function "and" (left : std_ulogic; right: boolean) return std_ulogic is
  begin
    return left and to_sl(right);
  end function;
  --------------------------------------------------------------------------------------------------

end package body;
