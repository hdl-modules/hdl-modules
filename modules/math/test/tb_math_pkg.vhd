-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the tsfpga project.
-- https://tsfpga.com
-- https://gitlab.com/tsfpga/tsfpga
-- -------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
context vunit_lib.vunit_context;

use work.math_pkg.all;


entity tb_math_pkg is
  generic (
    runner_cfg : string
    );
end entity;

architecture tb of tb_math_pkg is

  -- This function calculates the number of bits pars that differs
  -- in the two input vectors.
  function hamming_distance(in1, in2 : std_logic_vector) return integer is
    variable tmp : std_logic_vector(in1'range);
    variable ret : integer := 0;
  begin
    tmp := in1 xor in2;
    for i in tmp'range loop
      if tmp(i) = '1' then
        ret := ret + 1;
      end if;
    end loop;
    return ret;
  end function;
begin

  main : process
    variable value : signed(5 - 1 downto 0);
    variable value_slv : unsigned(8 - 1 downto 0);
    constant some_integer_vector : integer_vector(0 to 3) := (-1, 4, 0, -7);
    variable abs_vector_output : integer_vector(0 to 3);
  begin
    test_runner_setup(runner, runner_cfg);

    if run("ceil_log2") then
      check_equal(ceil_log2(1), 0);

      check_equal(ceil_log2(2), 1);

      check_equal(ceil_log2(3), 2);
      check_equal(ceil_log2(4), 2);

      check_equal(ceil_log2(5), 3);
      check_equal(ceil_log2(7), 3);
      check_equal(ceil_log2(8), 3);

      check_equal(ceil_log2(9), 4);

    elsif run("log2") then
      check_equal(log2(1), 0);
      check_equal(log2(2), 1);
      check_equal(log2(32), 5);
      check_equal(log2(64), 6);
      check_equal(log2(128), 7);

    elsif run("num_bits_needed_int") then
      check_equal(num_bits_needed(0), 1);
      check_equal(num_bits_needed(1), 1);
      check_equal(num_bits_needed(2), 2);
      check_equal(num_bits_needed(3), 2);

      check_equal(num_bits_needed(6), 3);
      check_equal(num_bits_needed(7), 3);
      check_equal(num_bits_needed(8), 4);
      check_equal(num_bits_needed(9), 4);

    elsif run("round_up_to_power_of_two") then
      check_equal(round_up_to_power_of_two(1), 1);

      check_equal(round_up_to_power_of_two(2), 2);

      check_equal(round_up_to_power_of_two(3), 4);
      check_equal(round_up_to_power_of_two(4), 4);

      check_equal(round_up_to_power_of_two(5), 8);

      check_equal(round_up_to_power_of_two(127), 128);
      check_equal(round_up_to_power_of_two(128), 128);
      check_equal(round_up_to_power_of_two(129), 256);

    elsif run("num_bits_needed_vector") then
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

    elsif run("lt_0") then
      value := to_signed(-3, value'length);
      check_true(lt_0(value));
      value := to_signed(0, value'length);
      check_false(lt_0(value));
      value := to_signed(3, value'length);
      check_false(lt_0(value));

    elsif run("geq_0") then
      value := to_signed(-3, value'length);
      check_false(geq_0(value));
      value := to_signed(0, value'length);
      check_true(geq_0(value));
      value := to_signed(3, value'length);
      check_true(geq_0(value));

    elsif run("to_and_from_gray") then
      for i in 1 to 2 ** value_slv'length - 2 loop
        value_slv := to_unsigned(i, value_slv'length);
        check_equal(from_gray(to_gray(value_slv)), value_slv);
        -- Verify that only one bit changes when incrementing the input
        -- to to_gray
        check_equal(hamming_distance(to_gray(value_slv), to_gray(value_slv + 1)), 1);
        check_equal(hamming_distance(to_gray(value_slv - 1), to_gray(value_slv)), 1);
        check_equal(hamming_distance(to_gray(value_slv - 1), to_gray(value_slv + 1)), 2);
      end loop;

    elsif run("is_power_of_two") then
      check_true(is_power_of_two(2));
      check_true(is_power_of_two(4));
      check_true(is_power_of_two(16));

      check_false(is_power_of_two(15));
      check_false(is_power_of_two(17));

    elsif run("abs_vector") then
      abs_vector_output := abs_vector(some_integer_vector);
      for idx in some_integer_vector'range loop
        check_equal(abs_vector_output(idx), abs(some_integer_vector(idx)));
      end loop;

    elsif run("vector_sum") then
      check_equal(vector_sum((0, 1, -4)), -3);
      check_equal(vector_sum((4, 1, 3)), 8);

    elsif run("greatest_common_divisor") then
      check_equal(greatest_common_divisor(6, 3), 3);
      check_equal(greatest_common_divisor(7, 3), 1);
      check_equal(greatest_common_divisor(7, 1), 1);
      check_equal(greatest_common_divisor(8, 15), 1);

    elsif run("is_mutual_prime") then
      check_equal(is_mutual_prime(6, (3, 7)), false);
      check_equal(is_mutual_prime(7, (3, 6)), true);
      check_equal(is_mutual_prime(7, (1, 5)), true);
      check_equal(is_mutual_prime(8, (3, 7)), true);
    end if;

    test_runner_cleanup(runner);
  end process;

end architecture;
