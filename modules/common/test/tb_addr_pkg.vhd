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

use work.addr_pkg.all;


entity tb_addr_pkg is
  generic (
    runner_cfg : string
  );
end entity;

architecture tb of tb_addr_pkg is

  constant addrs_duplicate : addr_vec_t(0 to 3) := (
    0 => x"0000_0000",
    1 => x"0000_1000",
    2 => x"0000_1000",
    3 => x"0000_2000"
  );
  constant addrs_duplicate2 : addr_vec_t(0 to 1) := (
    0 => x"0000_0000",
    1 => x"0000_0000"
  );
  constant addrs_invalid_character : addr_vec_t(0 to 1) := (
    0 => x"0000_00XX",
    1 => x"0000_0001"
  );

  constant addrs_no_duplicate : addr_vec_t(0 to 3) := (
    0 => x"0000_0000",
    1 => x"0000_1000",
    2 => x"0000_3000",
    3 => x"0000_2000"
  );
  constant addrs_no_duplicate2 : addr_vec_t(0 to 0) := (
    0 => x"0000_0000"
  );

  constant addrs : addr_and_mask_vec_t(0 to 5) := (
    0 => (addr => x"0000_0000", mask => x"0000_f000"),
    1 => (addr => x"0000_1000", mask => x"0000_f000"),
    2 => (addr => x"0000_2000", mask => x"0000_ff00"),
    3 => (addr => x"0000_2100", mask => x"0000_ff00"),
    4 => (addr => x"0000_3000", mask => x"0000_f000"),
    5 => (addr => x"0000_4000", mask => x"0000_f000")
  );

  constant addrs2 : addr_and_mask_vec_t(0 to 1) := (
    0 => (addr => x"0120_0000", mask => x"01f0_0000"),
    1 => (addr => x"0130_0000", mask => x"01f0_0000")
  );

  constant addrs_overlap : addr_and_mask_vec_t(0 to 4) := (
    0 => (addr => x"0000_0000", mask => x"0000_7000"),
    1 => (addr => x"0000_1000", mask => x"0000_7000"),
    2 => (addr => x"0000_2000", mask => x"0000_7000"),
    -- With the given mask, this is same as the one above.
    3 => (addr => x"0000_2100", mask => x"0000_7000"),
    4 => (addr => x"0000_4000", mask => x"0000_7000")
  );
  constant addrs_overlap2 : addr_and_mask_vec_t(0 to 3) := (
    0 => (addr => x"0000_0000", mask => x"0000_3000"),
    -- This would match the '3' below.
    1 => (addr => x"0000_1000", mask => x"0000_1000"),
    -- This would match the '3' below.
    2 => (addr => x"0000_2000", mask => x"0000_2000"),
    3 => (addr => x"0000_3000", mask => x"0000_3000")
  );
  constant addrs_invalid_mask : addr_and_mask_vec_t(0 to 1) := (
    0 => (addr => x"0000_0000", mask => x"0000_1000"),
    -- Mask zero is invalid, will always match.
    1 => (addr => x"0000_1000", mask => x"0000_0000")
  );
  -- Only one base address on address zero can not have any other mask than zero because we do not
  -- have any information to use.
  constant addrs_valid_mask_zero : addr_and_mask_vec_t(0 to 0) := (
    0 => (addr => x"0000_0000", mask => x"0000_0000")
  );
  -- If the address is non-zero however, it is still an error.
  constant addrs_invalid_mask_zero : addr_and_mask_vec_t(0 to 0) := (
    0 => (addr => x"0001_0000", mask => x"0000_0000")
  );

  constant addrs_to_mask : addr_vec_t(0 to 5) := (
    0 => x"0000_0000",
    1 => x"0000_1000",
    2 => x"0001_0000",
    3 => x"0002_0000",
    4 => x"0000_2000",
    5 => x"0000_3000"
  );
  -- The reference masks below have been manually inspected to be correct and sufficient.
  constant addr_and_mask_standard_expected : addr_and_mask_vec_t(addrs_to_mask'range) := (
    0 => (addr => addrs_to_mask(0), mask => x"0003_3000"),
    1 => (addr => addrs_to_mask(1), mask => x"0003_3000"),
    2 => (addr => addrs_to_mask(2), mask => x"0003_3000"),
    3 => (addr => addrs_to_mask(3), mask => x"0003_3000"),
    4 => (addr => addrs_to_mask(4), mask => x"0003_3000"),
    5 => (addr => addrs_to_mask(5), mask => x"0003_3000")
  );
  -- The reference masks below have further been manually inspected to be minimal.
  constant addr_and_mask_minimal_expected : addr_and_mask_vec_t(addrs_to_mask'range) := (
    0 => (addr => addrs_to_mask(0), mask => x"0003_3000"),
    1 => (addr => addrs_to_mask(1), mask => x"0000_3000"),
    2 => (addr => addrs_to_mask(2), mask => x"0001_0000"),
    3 => (addr => addrs_to_mask(3), mask => x"0002_0000"),
    4 => (addr => addrs_to_mask(4), mask => x"0000_3000"),
    5 => (addr => addrs_to_mask(5), mask => x"0000_3000")
  );

  constant addrs_to_mask2 : addr_vec_t(0 to 16) := (
    0 => x"0000_1000",
    1 => x"0000_0000",
    2 => x"0001_0000",
    3 => x"0002_0000",
    4 => x"0000_2000",
    5 => x"0000_3000",
    6 => x"0000_4000",
    7 => x"0000_8000",
    8 => x"0003_0000",
    9 => x"0003_1000",
    10 => x"0003_2000",
    11 => x"0003_4000",
    12 => x"0004_0100",
    13 => x"0000_0200",
    14 => x"0000_0300",
    15 => x"8000_0000",
    16 => x"8010_0000"
  );
  -- The reference masks below have been manually inspected to be correct and sufficient.
  constant addr_and_mask2_standard_expected : addr_and_mask_vec_t(addrs_to_mask2'range) := (
    0 => (addr => addrs_to_mask2(0), mask => x"8017_F300"),
    1 => (addr => addrs_to_mask2(1), mask => x"8017_F300"),
    2 => (addr => addrs_to_mask2(2), mask => x"8017_F300"),
    3 => (addr => addrs_to_mask2(3), mask => x"8017_F300"),
    4 => (addr => addrs_to_mask2(4), mask => x"8017_F300"),
    5 => (addr => addrs_to_mask2(5), mask => x"8017_F300"),
    6 => (addr => addrs_to_mask2(6), mask => x"8017_F300"),
    7 => (addr => addrs_to_mask2(7), mask => x"8017_F300"),
    8 => (addr => addrs_to_mask2(8), mask => x"8017_F300"),
    9 => (addr => addrs_to_mask2(9), mask => x"8017_F300"),
    10 => (addr => addrs_to_mask2(10), mask => x"8017_F300"),
    11 => (addr => addrs_to_mask2(11), mask => x"8017_F300"),
    12 => (addr => addrs_to_mask2(12), mask => x"8017_F300"),
    13 => (addr => addrs_to_mask2(13), mask => x"8017_F300"),
    14 => (addr => addrs_to_mask2(14), mask => x"8017_F300"),
    15 => (addr => addrs_to_mask2(15), mask => x"8017_F300"),
    16 => (addr => addrs_to_mask2(16), mask => x"8017_F300")
  );
  -- The reference masks below have further been manually inspected to be minimal.
  constant addr_and_mask2_minimal_expected : addr_and_mask_vec_t(addrs_to_mask2'range) := (
    0 => (addr => addrs_to_mask2(0), mask => x"0001_3000"),
    1 => (addr => addrs_to_mask2(1), mask => x"8003_F300"),
    2 => (addr => addrs_to_mask2(2), mask => x"0003_0000"),
    3 => (addr => addrs_to_mask2(3), mask => x"0003_0000"),
    4 => (addr => addrs_to_mask2(4), mask => x"0001_3000"),
    5 => (addr => addrs_to_mask2(5), mask => x"0000_3000"),
    6 => (addr => addrs_to_mask2(6), mask => x"0001_4000"),
    7 => (addr => addrs_to_mask2(7), mask => x"0000_8000"),
    8 => (addr => addrs_to_mask2(8), mask => x"0003_7000"),
    9 => (addr => addrs_to_mask2(9), mask => x"0001_1000"),
    10 => (addr => addrs_to_mask2(10), mask => x"0001_2000"),
    11 => (addr => addrs_to_mask2(11), mask => x"0001_4000"),
    12 => (addr => addrs_to_mask2(12), mask => x"0004_0000"),
    13 => (addr => addrs_to_mask2(13), mask => x"0000_0300"),
    14 => (addr => addrs_to_mask2(14), mask => x"0000_0300"),
    15 => (addr => addrs_to_mask2(15), mask => x"8010_0000"),
    16 => (addr => addrs_to_mask2(16), mask => x"0010_0000")
  );

  constant addrs_to_mask3 : addr_vec_t(0 to 10) := (
    0 => x"8000_1000",
    1 => x"8001_0000",
    2 => x"8002_0000",
    3 => x"8000_2000",
    4 => x"8000_3000",
    5 => x"4000_4000",
    6 => x"4004_8000",
    7 => x"4000_0000",
    8 => x"4001_0000",
    9 => x"4004_0000",
    10 => x"0000_0000"
  );
  -- The reference masks below have been manually inspected to be correct and sufficient.
  constant addr_and_mask3_standard_expected : addr_and_mask_vec_t(addrs_to_mask3'range) := (
    0 => (addr => addrs_to_mask3(0), mask => x"C007_F000"),
    1 => (addr => addrs_to_mask3(1), mask => x"C007_F000"),
    2 => (addr => addrs_to_mask3(2), mask => x"C007_F000"),
    3 => (addr => addrs_to_mask3(3), mask => x"C007_F000"),
    4 => (addr => addrs_to_mask3(4), mask => x"C007_F000"),
    5 => (addr => addrs_to_mask3(5), mask => x"C007_F000"),
    6 => (addr => addrs_to_mask3(6), mask => x"C007_F000"),
    7 => (addr => addrs_to_mask3(7), mask => x"C007_F000"),
    8 => (addr => addrs_to_mask3(8), mask => x"C007_F000"),
    9 => (addr => addrs_to_mask3(9), mask => x"C007_F000"),
    10 => (addr => addrs_to_mask3(10), mask => x"C007_F000")
  );
  -- The reference masks below have further been manually inspected to be minimal.
  constant addr_and_mask3_minimal_expected : addr_and_mask_vec_t(addrs_to_mask3'range) := (
    0 => (addr => addrs_to_mask3(0), mask => x"0000_3000"),
    1 => (addr => addrs_to_mask3(1), mask => x"4001_0000"),
    2 => (addr => addrs_to_mask3(2), mask => x"0002_0000"),
    3 => (addr => addrs_to_mask3(3), mask => x"0000_3000"),
    4 => (addr => addrs_to_mask3(4), mask => x"0000_3000"),
    5 => (addr => addrs_to_mask3(5), mask => x"0000_4000"),
    6 => (addr => addrs_to_mask3(6), mask => x"0000_8000"),
    7 => (addr => addrs_to_mask3(7), mask => x"4005_4000"),
    8 => (addr => addrs_to_mask3(8), mask => x"4001_0000"),
    9 => (addr => addrs_to_mask3(9), mask => x"0004_8000"),
    10 => (addr => addrs_to_mask3(10), mask => x"C000_0000")
  );

begin

  ------------------------------------------------------------------------------
  main : process
    -- Use this function to get addr vector constrained
    function decode(addr : u_unsigned(32 - 1 downto 0)) return integer is
    begin
      return decode(addr, addrs);
    end function;

    variable addr_and_mask_got : addr_and_mask_vec_t(addrs_to_mask'range) := (
      others => addr_and_mask_init
    );
    variable addr_and_mask2_got : addr_and_mask_vec_t(addrs_to_mask2'range) := (
      others => addr_and_mask_init
    );
    variable addr_and_mask3_got : addr_and_mask_vec_t(addrs_to_mask3'range) := (
      others => addr_and_mask_init
    );
  begin
    test_runner_setup(runner, runner_cfg);

    if run("test_sanity_check_base_addresses") then
      assert sanity_check_base_addresses(addrs_no_duplicate);
      assert sanity_check_base_addresses(addrs_no_duplicate2);

      assert not sanity_check_base_addresses(addrs_duplicate);
      assert not sanity_check_base_addresses(addrs_duplicate2);
      assert not sanity_check_base_addresses(addrs_invalid_character);

    elsif run("test_addr_bits_needed") then
      check_equal(addr_bits_needed(addrs), 16);
      check_equal(addr_bits_needed(addrs2), 25);

      -- Default value in special case.
      check_equal(addr_bits_needed(addrs_valid_mask_zero), 32);

    elsif run("test_decode_happy_path") then
      check_equal(decode(x"43C0_0000"), 0);
      check_equal(decode(x"43C0_1000"), 1);
      check_equal(decode(x"43C0_2000"), 2);
      check_equal(decode(x"43C0_2100"), 3);
      check_equal(decode(x"43C0_3000"), 4);
      check_equal(decode(x"43C0_4000"), 5);

    elsif run("test_decode_fail") then
      check_equal(decode(x"43C0_2200"), addrs'length);
      check_equal(decode(x"43C0_2300"), addrs'length);
      check_equal(decode(x"43C0_5000"), addrs'length);

    elsif run("test_sanity_check_address_and_mask") then
      assert not sanity_check_address_and_mask(addrs_overlap);
      assert not sanity_check_address_and_mask(addrs_overlap2);
      assert not sanity_check_address_and_mask(addrs_invalid_mask);
      assert not sanity_check_address_and_mask(addrs_invalid_mask_zero);

      assert sanity_check_address_and_mask(addrs);
      assert sanity_check_address_and_mask(addrs2);
      assert sanity_check_address_and_mask(addrs_valid_mask_zero);

    elsif run("test_calculate_mask") then
      addr_and_mask_got := calculate_mask(addrs_to_mask);
      addr_and_mask2_got := calculate_mask(addrs_to_mask2);
      addr_and_mask3_got := calculate_mask(addrs_to_mask3);

      assert addr_and_mask_got = addr_and_mask_standard_expected;
      assert addr_and_mask2_got = addr_and_mask2_standard_expected;
      assert addr_and_mask3_got = addr_and_mask3_standard_expected;

      check_equal(get_mask_cost(addr_and_mask_got), 24);
      check_equal(get_mask_cost(addr_and_mask2_got), 187);
      check_equal(get_mask_cost(addr_and_mask3_got), 99);

    elsif run("test_calculate_minimal_mask") then
      addr_and_mask_got := calculate_minimal_mask(addrs_to_mask);
      addr_and_mask2_got := calculate_minimal_mask(addrs_to_mask2);
      addr_and_mask3_got := calculate_minimal_mask(addrs_to_mask3);

      -- The code blocks below can be used to debug/inspect the result.
      report "Reference := ";
      print_addr_and_mask_vec(addr_and_mask3_got);

      for idx in addr_and_mask3_minimal_expected'range loop
        if addr_and_mask3_got(idx).addr /= addr_and_mask3_minimal_expected(idx).addr then
          report "Addr diff at " & to_string(idx);
        end if;

        if addr_and_mask3_got(idx).mask /= addr_and_mask3_minimal_expected(idx).mask then
          report "Mask diff at " & to_string(idx);
        end if;
      end loop;

      -- The actual checks.
      assert addr_and_mask_got = addr_and_mask_minimal_expected;
      assert addr_and_mask2_got = addr_and_mask2_minimal_expected;
      assert addr_and_mask3_got = addr_and_mask3_minimal_expected;

      -- All these are verified by inspecting printouts to be the lower of the two bit loop
      -- direction calculations.
      check_equal(get_mask_cost(addr_and_mask_got), 12);
      check_equal(get_mask_cost(addr_and_mask2_got), 43);
      check_equal(get_mask_cost(addr_and_mask3_got), 21);

    end if;

    test_runner_cleanup(runner);
  end process;

end architecture;
