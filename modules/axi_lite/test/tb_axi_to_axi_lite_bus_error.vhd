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

library osvvm;
use osvvm.RandomPkg.RandomPType;

library vunit_lib;
use vunit_lib.check_pkg.all;
use vunit_lib.run_pkg.all;

library axi;
use axi.axi_pkg.all;

library math;
use math.math_pkg.all;

library common;
use common.types_pkg.all;

use work.axi_lite_pkg.all;


entity tb_axi_to_axi_lite_bus_error is
  generic (
    data_width : positive range 1 to axi_lite_data_sz;
    runner_cfg : string
  );
end entity;

architecture tb of tb_axi_to_axi_lite_bus_error is
  signal clk : std_ulogic := '0';

  signal axi_m2s : axi_m2s_t := axi_m2s_init;
  signal axi_s2m : axi_s2m_t := axi_s2m_init;

  signal axi_lite_m2s : axi_lite_m2s_t := axi_lite_m2s_init;
  signal axi_lite_s2m : axi_lite_s2m_t := axi_lite_s2m_init;

  constant correct_size : integer := log2(data_width / 8);
  constant correct_len : integer := 0;

begin

  test_runner_watchdog(runner, 10 ms);
  clk <= not clk after 2 ns;


  ------------------------------------------------------------------------------
  main : process
    procedure test_ar(len, size : integer; resp : std_ulogic_vector) is
    begin
      axi_lite_s2m.read.ar.ready <= '1';

      axi_m2s.read.ar.valid <= '1';
      axi_m2s.read.ar.len <= to_unsigned(len, axi_m2s.read.ar.len'length);
      axi_m2s.read.ar.size <= to_unsigned(size, axi_m2s.read.ar.size'length);

      wait until axi_m2s.read.ar.valid and axi_s2m.read.ar.ready and rising_edge(clk);
      axi_lite_s2m.read.ar.ready <= '0';
      axi_m2s.read.ar.valid <= '0';

      axi_m2s.read.r.ready <= '1';

      axi_lite_s2m.read.r.valid <= '1';
      axi_lite_s2m.read.r.resp <= axi_resp_okay;

      wait until axi_s2m.read.r.valid and axi_m2s.read.r.ready and rising_edge(clk);
      check_equal(axi_s2m.read.r.resp, resp);

      axi_m2s.read.r.ready <= '0';
      axi_lite_s2m.read.r.valid <= '0';
    end procedure;

    procedure test_aw(len, size : integer; resp : std_ulogic_vector) is
    begin
      axi_lite_s2m.write.aw.ready <= '1';

      axi_m2s.write.aw.valid <= '1';
      axi_m2s.write.aw.len <= to_unsigned(len, axi_m2s.write.aw.len'length);
      axi_m2s.write.aw.size <= to_unsigned(size, axi_m2s.write.aw.size'length);

      wait until axi_m2s.write.aw.valid and axi_s2m.write.aw.ready and rising_edge(clk);
      axi_lite_s2m.write.aw.ready <= '0';
      axi_m2s.write.aw.valid <= '0';

      axi_m2s.write.b.ready <= '1';

      axi_lite_s2m.write.b.valid <= '1';
      axi_lite_s2m.write.b.resp <= axi_resp_okay;

      wait until axi_s2m.write.b.valid and axi_m2s.write.b.ready and rising_edge(clk);
      axi_m2s.write.b.ready <= '0';
      axi_lite_s2m.write.b.valid <= '0';

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
      --
      axi_m2s => axi_m2s,
      axi_s2m => axi_s2m,
      --
      axi_lite_m2s => axi_lite_m2s,
      axi_lite_s2m => axi_lite_s2m
    );

end architecture;
