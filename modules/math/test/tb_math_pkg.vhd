-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the hdl-modules project, a collection of reusable, high-quality,
-- peer-reviewed VHDL building blocks.
-- https://hdl-modules.com
-- https://github.com/hdl-modules/hdl-modules
-- -------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
use vunit_lib.check_pkg.all;
use vunit_lib.run_pkg.all;

library common;
use common.types_pkg.all;

use work.math_pkg.all;


entity tb_math_pkg is
  generic (
    runner_cfg : string
    );
end entity;

architecture tb of tb_math_pkg is

begin

  ------------------------------------------------------------------------------
  main : process

    ------------------------------------------------------------------------------
    constant clamp_num_bits : positive := 3;
    constant clamp_min_value : integer := get_min_signed_integer(num_bits=>clamp_num_bits);
    constant clamp_max_value : integer := get_max_signed_integer(num_bits=>clamp_num_bits);

    function clamp_integer(value : integer) return integer is
    begin
      return clamp(value=>value, min=>clamp_min_value, max=>clamp_max_value);
    end function;

    function clamp_signed(value : integer) return signed is
      -- +1 since input 'value' will sometimes be outside of the clamp range.
      constant value_signed : signed(clamp_num_bits + 1 - 1 downto 0) := to_signed(
        value, clamp_num_bits + 1
      );
      constant min_value_signed : signed(clamp_num_bits - 1 downto 0) := to_signed(
        clamp_min_value, clamp_num_bits
      );
      constant max_value_signed : signed(clamp_num_bits - 1 downto 0) := to_signed(
        clamp_max_value, clamp_num_bits
      );
      variable result : signed(value_signed'range) := (others => '0');
    begin
      result := clamp(value=>value_signed, min=>min_value_signed, max=>max_value_signed);
      return result;
    end function;
    ------------------------------------------------------------------------------

    ------------------------------------------------------------------------------
    variable vector : integer_vec_t(0 to 2) := (others => 0);
    variable matrix : integer_matrix_t(0 to 1)(0 to 2) := (others => (others => 0));
    ------------------------------------------------------------------------------

    ------------------------------------------------------------------------------
    variable value : u_signed(5 - 1 downto 0);
    variable value_slv : u_unsigned(8 - 1 downto 0);
    constant some_integer_vector : integer_vector(0 to 3) := (-1, 4, 0, -7);
    variable abs_vector_output : integer_vector(0 to 3);
    ------------------------------------------------------------------------------

  begin
    test_runner_setup(runner, runner_cfg);

    if run("test_get_min_max_signed_integer") then
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
      check_equal(clamp_integer(clamp_min_value - 1), clamp_min_value);
      check_equal(clamp_integer(clamp_min_value), clamp_min_value);
      check_equal(clamp_integer(clamp_min_value + 1), clamp_min_value + 1);

      check_equal(clamp_integer(clamp_max_value - 1), clamp_max_value - 1);
      check_equal(clamp_integer(clamp_max_value), clamp_max_value);
      check_equal(clamp_integer(clamp_max_value + 1), clamp_max_value);

    elsif run("test_clamp_signed") then
      check_equal(clamp_signed(clamp_min_value - 1), clamp_min_value);
      check_equal(clamp_signed(clamp_min_value), clamp_min_value);
      check_equal(clamp_signed(clamp_min_value + 1), clamp_min_value + 1);

      check_equal(clamp_signed(clamp_max_value - 1), clamp_max_value - 1);
      check_equal(clamp_signed(clamp_max_value), clamp_max_value);
      check_equal(clamp_signed(clamp_max_value + 1), clamp_max_value);

    elsif run("test_ceil_log2") then
      check_equal(ceil_log2(1), 0);

      check_equal(ceil_log2(2), 1);

      check_equal(ceil_log2(3), 2);
      check_equal(ceil_log2(4), 2);

      check_equal(ceil_log2(5), 3);
      check_equal(ceil_log2(7), 3);
      check_equal(ceil_log2(8), 3);

      check_equal(ceil_log2(9), 4);

    elsif run("test_log2") then
      check_equal(log2(1), 0);
      check_equal(log2(2), 1);
      check_equal(log2(32), 5);
      check_equal(log2(64), 6);
      check_equal(log2(128), 7);

    elsif run("test_num_bits_needed_unsigned_integer") then
      check_equal(num_bits_needed(0), 1);
      check_equal(num_bits_needed(1), 1);
      check_equal(num_bits_needed(2), 2);
      check_equal(num_bits_needed(3), 2);

      check_equal(num_bits_needed(6), 3);
      check_equal(num_bits_needed(7), 3);
      check_equal(num_bits_needed(8), 4);
      check_equal(num_bits_needed(9), 4);

    elsif run("test_num_bits_needed_signed_integer") then
      check_equal(num_bits_needed_signed(0), 1);

      check_equal(num_bits_needed_signed(-1), 1);
      check_equal(num_bits_needed_signed(-3), 3);
      check_equal(num_bits_needed_signed(-4), 3);

      check_equal(num_bits_needed_signed(1), 2);
      check_equal(num_bits_needed_signed(3), 3);
      check_equal(num_bits_needed_signed(4), 4);

    elsif run("test_num_bits_needed_signed_vector") then
      check_equal(num_bits_needed_signed(vector), 1);

      vector := (7, 6, -1);
      check_equal(num_bits_needed_signed(vector), 4);
      vector := (0, 8, -1);
      check_equal(num_bits_needed_signed(vector), 5);

      vector := (-7, 6, -1);
      check_equal(num_bits_needed_signed(vector), 4);
      vector := (1, -9, -1);
      check_equal(num_bits_needed_signed(vector), 5);

    elsif run("test_num_bits_needed_signed_matrix") then
      check_equal(num_bits_needed_signed(matrix), 1);

      matrix := ((7, 6, -1), (0, 8, -1));
      check_equal(num_bits_needed_signed(matrix), 5);

      matrix := ((-7, 6, -1), (1, -9, -1));
      check_equal(num_bits_needed_signed(matrix), 5);

    elsif run("test_round_up_to_power_of_two") then
      check_equal(round_up_to_power_of_two(1), 1);
      check_equal(round_up_to_power_of_two(1.0), 1.0);

      check_equal(round_up_to_power_of_two(2), 2);
      check_equal(round_up_to_power_of_two(2.0), 2.0);

      check_equal(round_up_to_power_of_two(3), 4);
      check_equal(round_up_to_power_of_two(4), 4);
      check_equal(round_up_to_power_of_two(3.0), 4.0);
      check_equal(round_up_to_power_of_two(4.0), 4.0);

      check_equal(round_up_to_power_of_two(5), 8);
      check_equal(round_up_to_power_of_two(5.0), 8.0);

      check_equal(round_up_to_power_of_two(127), 128);
      check_equal(round_up_to_power_of_two(128), 128);
      check_equal(round_up_to_power_of_two(129), 256);
      check_equal(round_up_to_power_of_two(127.0), 128.0);
      check_equal(round_up_to_power_of_two(128.0), 128.0);
      check_equal(round_up_to_power_of_two(129.0), 256.0);

    elsif run("test_num_bits_needed_vector") then
      value_slv := "00000000";
      check_equal(num_bits_needed(value_slv), 1);

      value_slv := "00000001";
      check_equal(num_bits_needed(value_slv), 1);

      value_slv := "00000010";
      check_equal(num_bits_needed(value_slv), 2);

      value_slv := "00000011";
      check_equal(num_bits_needed(value_slv), 2);

      value_slv := "00000100";
      check_equal(num_bits_needed(value_slv), 3);

    elsif run("test_lt_0") then
      value := to_signed(-3, value'length);
      check_true(lt_0(value));
      value := to_signed(0, value'length);
      check_false(lt_0(value));
      value := to_signed(3, value'length);
      check_false(lt_0(value));

    elsif run("test_geq_0") then
      value := to_signed(-3, value'length);
      check_false(geq_0(value));
      value := to_signed(0, value'length);
      check_true(geq_0(value));
      value := to_signed(3, value'length);
      check_true(geq_0(value));

    elsif run("test_to_and_from_gray") then
      for i in 1 to 2 ** value_slv'length - 2 loop
        value_slv := to_unsigned(i, value_slv'length);
        check_equal(from_gray(to_gray(value_slv)), value_slv);
        -- Verify that only one bit changes when incrementing the input
        -- to to_gray
        check_equal(hamming_distance(to_gray(value_slv), to_gray(value_slv + 1)), 1);
        check_equal(hamming_distance(to_gray(value_slv - 1), to_gray(value_slv)), 1);
        check_equal(hamming_distance(to_gray(value_slv - 1), to_gray(value_slv + 1)), 2);
      end loop;

    elsif run("test_hamming_distance") then
      check_equal(hamming_distance("0010", "0010"), 0);
      check_equal(hamming_distance("1110", "0010"), 2);
      check_equal(hamming_distance("0010", "0011"), 1);
      check_equal(hamming_distance("1010", "0011"), 2);

    elsif run("test_is_power_of_two") then
      check_true(is_power_of_two(2));
      check_true(is_power_of_two(4));
      check_true(is_power_of_two(16));

      check_false(is_power_of_two(15));
      check_false(is_power_of_two(17));

    elsif run("test_abs_vector") then
      abs_vector_output := abs_vector(some_integer_vector);
      for idx in some_integer_vector'range loop
        check_equal(abs_vector_output(idx), abs(some_integer_vector(idx)));
      end loop;

    elsif run("test_vector_sum") then
      check_equal(vector_sum((0, 1, -4)), -3);
      check_equal(vector_sum((4, 1, 3)), 8);

    elsif run("test_greatest_common_divisor") then
      check_equal(greatest_common_divisor(6, 3), 3);
      check_equal(greatest_common_divisor(7, 3), 1);
      check_equal(greatest_common_divisor(7, 1), 1);
      check_equal(greatest_common_divisor(8, 15), 1);

    elsif run("test_is_mutual_prime") then
      check_equal(is_mutual_prime(6, (3, 7)), false);
      check_equal(is_mutual_prime(7, (3, 6)), true);
      check_equal(is_mutual_prime(7, (1, 5)), true);
      check_equal(is_mutual_prime(8, (3, 7)), true);
    end if;

    test_runner_cleanup(runner);
  end process;

end architecture;
