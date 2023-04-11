-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the hdl_modules project, a collection of reusable, high-quality,
-- peer-reviewed VHDL building blocks.
-- https://hdl-modules.com
-- https://gitlab.com/hdl_modules/hdl_modules
-- -------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
context vunit_lib.vunit_context;

use work.numeric_pkg.all;


entity tb_numeric_pkg is
  generic (
    runner_cfg : string
  );
end entity;

architecture tb of tb_numeric_pkg is
begin

  ------------------------------------------------------------------------------
  main : process

    constant clamp_num_bits : positive := 3;
    constant min_value : integer := get_min_signed_integer(num_bits=>clamp_num_bits);
    constant max_value : integer := get_max_signed_integer(num_bits=>clamp_num_bits);

    function clamp_integer(value : integer) return integer is
    begin
      return clamp(value=>value, min=>min_value, max=>max_value);
    end function;

    function clamp_signed(value : integer) return signed is
      constant value_signed : signed(clamp_num_bits + 1 - 1 downto 0) := to_signed(
        value, clamp_num_bits + 1
      );
      constant min_value_signed : signed(clamp_num_bits - 1 downto 0) := to_signed(
        min_value, clamp_num_bits
      );
      constant max_value_signed : signed(clamp_num_bits - 1 downto 0) := to_signed(
        max_value, clamp_num_bits
      );
      variable result : signed(value_signed'range) := (others => '0');
    begin
      result := clamp(value=>value_signed, min=>min_value_signed, max=>max_value_signed);
      return result;
    end function;

    variable byte_data0 : std_ulogic_vector(4 * 8 - 1 downto 0) := x"01_23_45_67";

  begin
    test_runner_setup(runner, runner_cfg);

    if run("get_min_max_signed_integer") then
      -- Since get_min/max_signed_integer calls get_min/max_signed, only testing like this
      -- is enough.

      for num_bits in 1 to 31 loop
        check_equal(get_min_signed_integer(num_bits=>num_bits), - 2 ** (num_bits - 1));
        check_equal(get_max_signed_integer(num_bits=>num_bits), 2 ** (num_bits - 1) - 1);
      end loop;

      -- The calculation of expected value above goes out of range for this number of bits.
      -- Do it manually instead.
      check_equal(get_min_signed_integer(num_bits=>32), -2147483648);
      check_equal(get_max_signed_integer(num_bits=>32), 2147483647);

    elsif run("test_get_max_unsigned_integer") then
      for num_bits in 1 to 30 loop
        check_equal(get_max_unsigned_integer(num_bits=>num_bits), 2 ** num_bits - 1);
      end loop;

      -- The calculation of expected value above goes out of range for this number of bits.
      -- Do it manually instead.
      check_equal(get_max_unsigned_integer(num_bits=>31), 2147483647);

    elsif run("test_clamp_integer") then
      check_equal(clamp_integer(min_value - 1), min_value);
      check_equal(clamp_integer(min_value), min_value);
      check_equal(clamp_integer(min_value + 1), min_value + 1);

      check_equal(clamp_integer(max_value - 1), max_value - 1);
      check_equal(clamp_integer(max_value), max_value);
      check_equal(clamp_integer(max_value + 1), max_value);

    elsif run("test_clamp_signed") then
      check_equal(clamp_signed(min_value - 1), min_value);
      check_equal(clamp_signed(min_value), min_value);
      check_equal(clamp_signed(min_value + 1), min_value + 1);

      check_equal(clamp_signed(max_value - 1), max_value - 1);
      check_equal(clamp_signed(max_value), max_value);
      check_equal(clamp_signed(max_value + 1), max_value);
    end if;

    test_runner_cleanup(runner);
  end process;

end architecture;
