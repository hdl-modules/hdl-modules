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


package types_pkg is

  type slv_vec_t is array (integer range <>) of std_logic_vector;
  type unsigned_vec_t is array (integer range <>) of unsigned;
  type signed_vec_t is array (integer range <>) of signed;

  type natural_vec_t is array (integer range <>) of natural;
  type positive_vec_t is array (integer range <>) of positive;
  type boolean_vec_t is array (integer range <>) of boolean;

  function get_maximum(values : positive_vec_t) return positive;

  function to_sl(value : boolean) return std_logic;
  function to_bool(value : std_logic) return boolean;
  function to_bool(value : natural) return boolean;

  subtype binary_integer_t is integer range 0 to 1;
  function to_int(value : boolean) return binary_integer_t;
  function to_int(value : std_logic) return binary_integer_t;

  subtype binary_real_t is real range 0.0 to 1.0;
  function to_real(value : boolean) return binary_real_t;

  function swap_byte_order(data : std_logic_vector) return std_logic_vector;
  function swap_bit_order(data : std_logic_vector) return std_logic_vector;

  function count_ones(data : std_logic_vector) return natural;

end package;

package body types_pkg is

  function get_maximum(values : positive_vec_t) return positive is
    -- Minimum possible value
    variable result : positive := 1;
  begin
    for value_idx in values'range loop
      result := maximum(result, values(value_idx));
    end loop;
    return result;
  end function;

  function to_sl(value : boolean) return std_logic is
  begin
    if value then
      return '1';
    end if;
    return '0';
  end function;

  function to_bool(value : std_logic) return boolean is
  begin
    if value = '1' then
      return true;
    elsif value = '0' then
      return false;
    end if;
    assert false report "Can not convert value " & to_string(value) severity failure;
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

    assert false report "Can not convert this value " & to_string(value) severity failure;
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

  function to_int(value : std_logic) return binary_integer_t is
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

  function swap_byte_order(data : std_logic_vector) return std_logic_vector is
    variable result : std_logic_vector(data'range);
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

  function swap_bit_order(data : std_logic_vector) return std_logic_vector is
    constant length : positive := data'length;
    variable result : std_logic_vector(data'range);
  begin
    -- While maintaining the range and vector direction, swap the location of the data bits.

    for idx in 0 to length - 1 loop
      result(result'low + idx) := data(data'high - idx);
    end loop;

    return result;
  end function;

  function count_ones(data : std_logic_vector) return natural is
    variable result : integer range 0 to data'length := 0;
  begin
    for bit_idx in data'range loop
      result := result + to_int(data(bit_idx));
    end loop;
    return result;
  end function;

end package body;
