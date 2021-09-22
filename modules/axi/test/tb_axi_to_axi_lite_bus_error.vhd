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
use vunit_lib.bus_master_pkg.all;
use vunit_lib.memory_pkg.all;
context vunit_lib.vunit_context;
context vunit_lib.com_context;

library osvvm;
use osvvm.RandomPkg.all;

library math;
use math.math_pkg.all;

use work.axi_lite_pkg.all;
use work.axi_pkg.all;
use work.axi_pkg.axi_resp_okay;
use work.axi_pkg.axi_resp_slverr;


entity tb_axi_to_axi_lite_bus_error is
  generic (
    data_width : integer;
    runner_cfg : string
  );
end entity;

architecture tb of tb_axi_to_axi_lite_bus_error is
  signal clk : std_logic := '0';

  signal axi_m2s : axi_m2s_t;
  signal axi_s2m : axi_s2m_t;

  signal axi_lite_m2s : axi_lite_m2s_t;
  signal axi_lite_s2m : axi_lite_s2m_t := axi_lite_s2m_init;

  constant correct_size : integer := log2(data_width / 8);
  constant correct_len : integer := 0;

begin

  test_runner_watchdog(runner, 10 ms);
  clk <= not clk after 2 ns;


  ------------------------------------------------------------------------------
  main : process
    procedure test_ar(len, size : integer; resp : std_logic_vector) is
    begin
      axi_lite_s2m.read.ar.ready <= '1';

      axi_m2s.read.ar.valid <= '1';
      axi_m2s.read.ar.len <= to_unsigned(len, axi_m2s.read.ar.len'length);
      axi_m2s.read.ar.size <= to_unsigned(size, axi_m2s.read.ar.size'length);

      wait until (axi_m2s.read.ar.valid and axi_s2m.read.ar.ready) = '1' and rising_edge(clk);
      axi_m2s.read.r.ready <= '1';
      axi_lite_s2m.read.r.valid <= '1';

      wait until (axi_s2m.read.r.valid and axi_m2s.read.r.ready) = '1' and rising_edge(clk);
      check_equal(axi_s2m.read.r.resp, resp);
    end procedure;

    procedure test_aw(len, size : integer; resp : std_logic_vector) is
    begin
      axi_lite_s2m.write.aw.ready <= '1';

      axi_m2s.write.aw.valid <= '1';
      axi_m2s.write.aw.len <= to_unsigned(len, axi_m2s.write.aw.len'length);
      axi_m2s.write.aw.size <= to_unsigned(size, axi_m2s.write.aw.size'length);

      wait until (axi_m2s.write.aw.valid and axi_s2m.write.aw.ready) = '1' and rising_edge(clk);
      axi_m2s.write.b.ready <= '1';
      axi_lite_s2m.write.b.valid <= '1';

      wait until (axi_s2m.write.b.valid and axi_m2s.write.b.ready) = '1' and rising_edge(clk);
      check_equal(axi_s2m.write.b.resp, resp);
    end procedure;

  begin
    test_runner_setup(runner, runner_cfg);

    -- All should be okay before test
    test_ar(correct_len, correct_size, axi_resp_okay);
    test_aw(correct_len, correct_size, axi_resp_okay);

    if run("ar_len_error") then
      test_ar(correct_len + 1, correct_size, axi_resp_slverr);
    elsif run("ar_size_error") then
      test_ar(correct_len, correct_size + 1, axi_resp_slverr);
    elsif run("aw_len_error") then
      test_aw(correct_len + 1, correct_size, axi_resp_slverr);
    elsif run("aw_size_error") then
      test_aw(correct_len, correct_size + 1, axi_resp_slverr);
    end if;

    -- The upcoming transaction after an offending transaction should be all okay
    test_ar(correct_len, correct_size, axi_resp_okay);
    test_aw(correct_len, correct_size, axi_resp_okay);

    test_runner_cleanup(runner);
  end process;


  ------------------------------------------------------------------------------
  dut : entity work.axi_to_axi_lite
    generic map (
      data_width => data_width
    )
    port map (
      clk => clk,

      axi_m2s => axi_m2s,
      axi_s2m => axi_s2m,

      axi_lite_m2s => axi_lite_m2s,
      axi_lite_s2m => axi_lite_s2m
    );

end architecture;
