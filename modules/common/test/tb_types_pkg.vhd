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

use work.types_pkg.all;


entity tb_types_pkg is
  generic (
    runner_cfg : string
  );
end entity;

architecture tb of tb_types_pkg is
begin

  main : process

    variable byte_data0 : std_logic_vector(4 * 8 - 1 downto 0) := x"01_23_45_67";
    constant byte_data0_swapped : std_logic_vector(byte_data0'range) := x"67_45_23_01";

    variable byte_data1 : std_logic_vector(8 * 8 - 1 downto 4 * 8) := x"01_23_45_67";
    constant byte_data1_swapped : std_logic_vector(byte_data0'range) := x"67_45_23_01";

    variable bit_data0 : std_logic_vector(6 - 1 downto 0) := "101010";
    constant bit_data0_swapped : std_logic_vector(bit_data0'range) := "010101";

    variable bit_data1 : std_logic_vector(0 to 6 - 1) := "101010";
    constant bit_data1_swapped : std_logic_vector(bit_data1'range) := "010101";

    variable bit_data2 : std_logic_vector(12 - 1 downto 6) := "101010";
    constant bit_data2_swapped : std_logic_vector(bit_data2'range) := "010101";

    variable bit_data3 : std_logic_vector(6 to 12 - 1) := "101010";
    constant bit_data3_swapped : std_logic_vector(bit_data2'range) := "010101";

    variable positive_vec : positive_vec_t(0 to 3) := (others => 1);

  begin
    test_runner_setup(runner, runner_cfg);

    if run("test_get_maximum_positive") then
      positive_vec := (1, 1, 1, 1);
      check_equal(get_maximum(positive_vec), 1);

      positive_vec := (4, 3, 2, 1);
      check_equal(get_maximum(positive_vec), 4);

    elsif run("test_to_bool_std_logic") then
      check_equal(to_bool('0'), false);
      check_equal(to_bool('1'), true);

    elsif run("test_to_bool_integer") then
      check_equal(to_bool(0), false);
      check_equal(to_bool(1), true);

    elsif run("test_to_int_std_logic") then
      check_equal(to_int('0'), 0);
      check_equal(to_int('-'), 0);
      check_equal(to_int('X'), 0);
      check_equal(to_int('H'), 0);
      check_equal(to_int('1'), 1);

    elsif run("test_to_real_bool") then
      check_equal(to_real(true), 1.0);
      check_equal(to_real(false), 0.0);

    elsif run("test_swap_byte_order") then
      byte_data0 := swap_byte_order(byte_data0);
      check_equal(byte_data0, byte_data0_swapped);
      check_equal(byte_data0'high, 4 * 8 - 1);
      check_equal(byte_data0'low, 0);
      check_equal(byte_data0'left, byte_data0'high);
      check_equal(byte_data0'right, byte_data0'low);

      byte_data1 := swap_byte_order(byte_data1);
      check_equal(byte_data1, byte_data1_swapped);
      check_equal(byte_data1'high, 8 * 8 - 1);
      check_equal(byte_data1'low, 4 * 8);
      check_equal(byte_data1'left, byte_data1'high);
      check_equal(byte_data1'right, byte_data1'low);

    elsif run("test_swap_bit_order") then
      bit_data0 := swap_bit_order(bit_data0);
      check_equal(bit_data0, bit_data0_swapped);
      check_equal(bit_data0'high, 5);
      check_equal(bit_data0'low, 0);
      check_equal(bit_data0'left, bit_data0'high);
      check_equal(bit_data0'right, bit_data0'low);

      bit_data1 := swap_bit_order(bit_data1);
      check_equal(bit_data1, bit_data1_swapped);
      check_equal(bit_data1'high, 5);
      check_equal(bit_data1'low, 0);
      check_equal(bit_data1'left, bit_data1'low);
      check_equal(bit_data1'right, bit_data1'high);

      bit_data2 := swap_bit_order(bit_data2);
      check_equal(bit_data2, bit_data2_swapped);
      check_equal(bit_data2'high, 11);
      check_equal(bit_data2'low, 6);
      check_equal(bit_data2'left, bit_data2'high);
      check_equal(bit_data2'right, bit_data2'low);

      bit_data3 := swap_bit_order(bit_data3);
      check_equal(bit_data3, bit_data3_swapped);
      check_equal(bit_data3'high, 11);
      check_equal(bit_data3'low, 6);
      check_equal(bit_data3'left, bit_data3'low);
      check_equal(bit_data3'right, bit_data3'high);

    elsif run("test_count_ones") then
      check_equal(count_ones(bit_data3), 3);
      check_equal(count_ones(byte_data1), 12);

    end if;

    test_runner_cleanup(runner);
  end process;

end architecture;
