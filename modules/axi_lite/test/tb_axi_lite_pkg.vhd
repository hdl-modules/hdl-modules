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

use work.axi_lite_pkg.all;


entity tb_axi_lite_pkg is
  generic (
    data_width : positive range 1 to axi_lite_data_sz := 32;
    runner_cfg : string
  );
end entity;

architecture tb of tb_axi_lite_pkg is
begin

  main : process

    variable rnd : RandomPType;

    procedure test_slv_conversion(addr_width : positive) is
      variable data_w : axi_lite_m2s_w_t := axi_lite_m2s_w_init;
      variable data_w_slv, data_w_converted :
        std_ulogic_vector(axi_lite_m2s_w_sz(data_width) - 1 downto 0) := (others => '0');

      variable data_r : axi_lite_s2m_r_t := axi_lite_s2m_r_init;
      variable data_r_slv, data_r_converted :
        std_ulogic_vector(axi_lite_s2m_r_sz(data_width) - 1 downto 0) := (others => '0');
    begin
      data_w_slv := rnd.RandSLV(data_w_slv'length);
      data_w := to_axi_lite_m2s_w(data_w_slv, data_width);
      data_w_converted := to_slv(data_w, data_width);

      check_equal(data_w_converted, data_w_slv);

      data_r_slv := rnd.RandSLV(data_r_slv'length);
      data_r := to_axi_lite_s2m_r(data_r_slv, data_width);
      data_r_converted := to_slv(data_r, data_width);

      check_equal(data_r_converted, data_r_slv);
    end procedure;

    procedure test_axi_lite_strb is
      constant got : std_ulogic_vector(axi_lite_w_strb_sz - 1 downto 0) :=
        to_axi_lite_strb(data_width);
      constant expected : positive := 2 ** (data_width / 8) - 1;
    begin
      check_equal(unsigned(got), expected);
    end procedure;

  begin
    test_runner_setup(runner, runner_cfg);
    rnd.InitSeed(rnd'instance_name);

    if run("test_slv_conversion") then
      -- Loop a couple of times to get good random coverage
      for i in 0 to 1000 loop
        test_slv_conversion(addr_width=>32);
        test_slv_conversion(addr_width=>40);
      end loop;

    elsif run("test_axi_lite_strb") then
      test_axi_lite_strb;

    elsif run("test_sanity_check_axi_lite_data_width") then
      check_equal(sanity_check_axi_lite_data_width(32), true);
      check_equal(sanity_check_axi_lite_data_width(64), true);

      check_equal(sanity_check_axi_lite_data_width(-64), false);
      check_equal(sanity_check_axi_lite_data_width(-32), false);
      check_equal(sanity_check_axi_lite_data_width(-1), false);
      check_equal(sanity_check_axi_lite_data_width(0), false);
      check_equal(sanity_check_axi_lite_data_width(1), false);
      check_equal(sanity_check_axi_lite_data_width(7), false);
      check_equal(sanity_check_axi_lite_data_width(8), false);
      check_equal(sanity_check_axi_lite_data_width(16), false);
      check_equal(sanity_check_axi_lite_data_width(24), false);
      check_equal(sanity_check_axi_lite_data_width(128), false);

    end if;

    test_runner_cleanup(runner);
  end process;

end architecture;
