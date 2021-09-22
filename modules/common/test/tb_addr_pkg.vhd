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

use work.addr_pkg.all;


entity tb_addr_pkg is
  generic (
    runner_cfg : string
  );
end entity;

architecture tb of tb_addr_pkg is

  constant addrs : addr_and_mask_vec_t(0 to 6 - 1) := (
    0 => (addr => x"0000_0000", mask => x"0000_f000"),
    1 => (addr => x"0000_1000", mask => x"0000_f000"),
    2 => (addr => x"0000_2000", mask => x"0000_ff00"),
    3 => (addr => x"0000_2100", mask => x"0000_ff00"),
    4 => (addr => x"0000_3000", mask => x"0000_f000"),
    5 => (addr => x"0000_4000", mask => x"0000_f000")
  );

  constant addrs2 : addr_and_mask_vec_t(0 to 2 - 1) := (
    0 => (addr => x"0120_0000", mask => x"01f0_0000"),
    1 => (addr => x"0130_0000", mask => x"01f0_0000")
  );

begin

  main : process
    variable value : signed(5 - 1 downto 0);

    -- Use this function to get addr vector constrained
    function decode(addr : unsigned(32 - 1 downto 0)) return integer is
    begin
      return decode(addr, addrs);
    end function;

  begin
    test_runner_setup(runner, runner_cfg);

    if run("test_addr_bits_needed") then
      check_equal(addr_bits_needed(addrs), 16);
      check_equal(addr_bits_needed(addrs2), 25);

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
    end if;

    test_runner_cleanup(runner);
  end process;

end architecture;
