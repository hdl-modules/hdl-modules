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


package numeric_pkg is

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
  -- Limit the supplied 'value' between 'min' and 'max'.
  function clamp(value, min, max : integer) return integer;
  function clamp(value, min, max : signed) return signed;
  ------------------------------------------------------------------------------

end package;

package body numeric_pkg is

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
    variable min_signed_integer : integer := 0;
  begin
    assert num_bits <= 32
      report "Calculation does not work for this many bits: " & integer'image(num_bits)
      severity failure;

    min_signed_integer := to_integer(min_signed);

    return min_signed_integer;
  end function;

  function get_max_signed_integer(num_bits : positive) return natural is
    constant max_signed : signed(num_bits - 1 downto 0) := get_max_signed(num_bits=>num_bits);
    variable max_signed_integer : natural := 0;
  begin
    assert num_bits <= 32
      report "Calculation does not work for this many bits: " & integer'image(num_bits)
      severity failure;

    max_signed_integer := to_integer(max_signed);

    return max_signed_integer;
  end function;

  function get_max_unsigned_integer(num_bits : positive) return positive is
    constant max_unsigned : unsigned(num_bits - 1 downto 0) := (others => '1');
    variable max_unsigned_integer : natural := 0;
  begin
    assert num_bits <= 32
      report "Calculation does not work for this many bits: " & integer'image(num_bits)
      severity failure;

    max_unsigned_integer := to_integer(max_unsigned);

    return max_unsigned_integer;
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

end package body;
