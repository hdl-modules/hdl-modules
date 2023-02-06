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

use work.types_pkg.all;


entity tb_types_pkg is
  generic (
    runner_cfg : string
  );
end entity;

architecture tb of tb_types_pkg is
begin

  main : process

    variable byte_data0 : std_ulogic_vector(4 * 8 - 1 downto 0) := x"01_23_45_67";
    constant byte_data0_swapped : std_ulogic_vector(byte_data0'range) := x"67_45_23_01";

    variable byte_data1 : std_ulogic_vector(8 * 8 - 1 downto 4 * 8) := x"01_23_45_67";
    constant byte_data1_swapped : std_ulogic_vector(byte_data0'range) := x"67_45_23_01";

    variable bit_data0 : std_ulogic_vector(6 - 1 downto 0) := "101010";
    constant bit_data0_swapped : std_ulogic_vector(bit_data0'range) := "010101";

    variable bit_data1 : std_ulogic_vector(0 to 6 - 1) := "101010";
    constant bit_data1_swapped : std_ulogic_vector(bit_data1'range) := "010101";

    variable bit_data2 : std_ulogic_vector(12 - 1 downto 6) := "101010";
    constant bit_data2_swapped : std_ulogic_vector(bit_data2'range) := "010101";

    variable bit_data3 : std_ulogic_vector(6 to 12 - 1) := "101010";
    constant bit_data3_swapped : std_ulogic_vector(bit_data2'range) := "010101";

    variable natural_vec : natural_vec_t(0 to 3) := (others => 0);
    variable positive_vec : positive_vec_t(0 to 3) := (others => 1);

    variable my_boolean : boolean := false;
    variable my_std_logic : std_logic := '0';

    -- Resolution of the 'time' unit is 1 fs = 10**-15 s.
    -- Allow less than this in diff when converting to real.
    constant real_time_max_diff : real := 0.49e-15;

  begin
    test_runner_setup(runner, runner_cfg);


    if run("test_natural_and_positive_vec_sum") then
      natural_vec := (0, 3, 8, 1);
      check_equal(sum(natural_vec), 12);

      positive_vec := (7, 3, 8, 1);
      check_equal(sum(positive_vec), 19);

    elsif run("test_get_maximum_natural") then
      natural_vec := (1, 1, 0, 1);
      check_equal(get_maximum(natural_vec), 1);

      natural_vec := (3, 2, 1, 4);
      check_equal(get_maximum(natural_vec), 4);

    elsif run("test_get_maximum_positive") then
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

    elsif run("test_to_real_s") then
      report to_string(integer'high);

      -- 9223372036854775807 fs in GHDL.
      -- Meaning the maximum value that can be represented is 2.56 hours.
      -- However, implementation details limit us to ~35 minutes.
      -- Some random values in this legal range are tested below.
      report to_string(time'high);

      check_equal(to_real_s(30 min), 30.0 * 60.0, max_diff=>real_time_max_diff);
      check_equal(to_real_s(3 min), 3.0 * 60.0, max_diff=>real_time_max_diff);

      check_equal(to_real_s(2 sec), 2.0, max_diff=>real_time_max_diff);
      check_equal(to_real_s(1 sec), 1.0, max_diff=>real_time_max_diff);

      check_equal(to_real_s(625 ms), 0.625, max_diff=>real_time_max_diff);

      check_equal(to_real_s(1 ns), 1.0e-9, max_diff=>real_time_max_diff);

      -- Most common use is to handle clock periods around the MHz range, so spend some
      -- time testing these.
      check_equal(to_real_s(8 us + 371 ns), 8.371e-6, max_diff=>real_time_max_diff);
      check_equal(to_real_s(7 us + 371 ns), 7.371e-6, max_diff=>real_time_max_diff);
      check_equal(to_real_s(6 us + 371 ns), 6.371e-6, max_diff=>real_time_max_diff);
      check_equal(to_real_s(5 us + 371 ns), 5.371e-6, max_diff=>real_time_max_diff);
      check_equal(to_real_s(4 us + 371 ns), 4.371e-6, max_diff=>real_time_max_diff);
      check_equal(to_real_s(3 us + 371 ns), 3.371e-6, max_diff=>real_time_max_diff);
      check_equal(to_real_s(2 us + 371 ns), 2.371e-6, max_diff=>real_time_max_diff);
      check_equal(to_real_s(1 us + 371 ns), 1.371e-6, max_diff=>real_time_max_diff);

      check_equal(to_real_s(503 ns), 0.503e-6, max_diff=>real_time_max_diff);

      -- Lowest end of the 'time' range
      check_equal(to_real_s(8 fs), 8.0e-15, max_diff=>real_time_max_diff);
      check_equal(to_real_s(7 fs), 7.0e-15, max_diff=>real_time_max_diff);
      check_equal(to_real_s(6 fs), 6.0e-15, max_diff=>real_time_max_diff);
      check_equal(to_real_s(5 fs), 5.0e-15, max_diff=>real_time_max_diff);
      check_equal(to_real_s(4 fs), 4.0e-15, max_diff=>real_time_max_diff);
      check_equal(to_real_s(3 fs), 3.0e-15, max_diff=>real_time_max_diff);
      check_equal(to_real_s(2 fs), 2.0e-15, max_diff=>real_time_max_diff);
      check_equal(to_real_s(1 fs), 1.0e-15, max_diff=>real_time_max_diff);

    elsif run("test_frequency_conversion") then
      -- Same checks as in the netlist build. Should give same result in Vivado as in simulator.

      for test_idx in test_periods'range loop
        -- 'time' period calculated from 'real' frequency
        assert  to_period(test_frequencies_real(test_idx)) = test_periods(test_idx);

        -- 'time' period calculated from 'integer' frequency
        -- The assert is a "check almost equal" for 'time' type.
        assert (
          (
            to_period(test_frequencies_integer(test_idx))
            >= test_periods(test_idx) - test_tolerances_period_from_integer_frequency(test_idx)
          ) and (
            to_period(test_frequencies_integer(test_idx))
            <= test_periods(test_idx) + test_tolerances_period_from_integer_frequency(test_idx)
          )
        );

        -- 'real' frequency calculated from 'time' period
        check_equal(
          got=>to_frequency_hz(test_periods(test_idx)),
          expected=>test_frequencies_real(test_idx),
          max_diff=>test_tolerances_real_frequency_from_period(test_idx)
        );

        -- 'time' period to 'integer' frequency
        check_equal(to_frequency_hz(test_periods(test_idx)), test_frequencies_integer(test_idx));

      end loop;

    elsif run("test_boolean_std_logic_and_operator") then
      my_boolean := true;
      my_std_logic := '1';
      check_true(my_boolean and my_std_logic);
      check_true(my_std_logic and my_boolean);

      my_boolean := false;
      check_false(my_boolean and my_std_logic);

      my_boolean := true;
      my_std_logic := '0';
      check_false(my_std_logic and my_boolean);

      my_std_logic := 'U';
      check_false(my_std_logic and my_boolean);

      my_std_logic := '-';
      check_false(my_std_logic and my_boolean);

    end if;

    test_runner_cleanup(runner);
  end process;

end architecture;
