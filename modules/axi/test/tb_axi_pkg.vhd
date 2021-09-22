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

library osvvm;
use osvvm.RandomPkg.all;

use work.axi_pkg.all;


entity tb_axi_pkg is
  generic (
    data_width : integer;
    id_width : integer;
    addr_width : integer;
    runner_cfg : string
  );
end entity;

architecture tb of tb_axi_pkg is
begin

  main : process
    variable rnd : RandomPType;

    procedure test_slv_conversion(iteration : natural) is
      constant offset_max : integer := 73;

      variable data_a : axi_m2s_a_t := axi_m2s_a_init;
      variable data_a_converted :
        std_logic_vector(axi_m2s_a_sz(id_width=>id_width, addr_width=>addr_width) - 1 downto 0) :=
        (others => '0');
      variable data_a_slv : std_logic_vector(data_a_converted'high + offset_max downto 0) :=
        (others => '0');

      variable data_w : axi_m2s_w_t := axi_m2s_w_init;
      variable data_w_converted :
        std_logic_vector(axi_m2s_w_sz(data_width=>data_width, id_width=>id_width) - 1 downto 0) :=
        (others => '0');
      variable data_w_slv : std_logic_vector(data_w_converted'high + offset_max downto 0) :=
        (others => '0');

      variable data_r : axi_s2m_r_t := axi_s2m_r_init;
      variable data_r_converted :
        std_logic_vector(axi_s2m_r_sz(data_width=>data_width, id_width=>id_width) - 1 downto 0) :=
        (others => '0');
      variable data_r_slv : std_logic_vector(data_r_converted'high + offset_max downto 0) :=
        (others => '0');

      variable data_b : axi_s2m_b_t := axi_s2m_b_init;
      variable data_b_converted : std_logic_vector(axi_s2m_b_sz(id_width=>id_width) - 1 downto 0) :=
        (others => '0');
      variable data_b_slv : std_logic_vector(data_b_converted'high + offset_max downto 0) :=
        (others => '0');

      variable hi, lo : integer := 0;
    begin
      -- Slice slv input, to make sure that ranges don't have to be down to 0
      lo := iteration mod offset_max;

      hi := data_a_converted'high + lo;
      data_a_slv(hi downto lo) := rnd.RandSLV(data_a_converted'length);
      data_a := to_axi_m2s_a(data_a_slv(hi downto lo), id_width=>id_width, addr_width=>addr_width);
      data_a_converted := to_slv(data_a, id_width=>id_width, addr_width=>addr_width);

      check_equal(data_a_converted, data_a_slv(hi downto lo));

      hi := data_w_converted'high + lo;
      data_w_slv(hi downto lo) := rnd.RandSLV(data_w_converted'length);
      data_w := to_axi_m2s_w(data_w_slv(hi downto lo), data_width=>data_width, id_width=>id_width);
      data_w_converted := to_slv(data_w, data_width=>data_width, id_width=>id_width);

      check_equal(data_w_converted, data_w_slv(hi downto lo));

      hi := data_r_converted'high + lo;
      data_r_slv(hi downto lo) := rnd.RandSLV(data_r_converted'length);
      data_r := to_axi_s2m_r(data_r_slv(hi downto lo), data_width=>data_width, id_width=>id_width);
      data_r_converted := to_slv(data_r, data_width=>data_width, id_width=>id_width);

      check_equal(data_r_converted, data_r_slv(hi downto lo));

      hi := data_b_converted'high + lo;
      data_b_slv(hi downto lo) := rnd.RandSLV(data_b_converted'length);
      data_b := to_axi_s2m_b(data_b_slv(hi downto lo), id_width=>id_width);
      data_b_converted := to_slv(data_b, id_width=>id_width);

      check_equal(data_b_converted, data_b_slv(hi downto lo));
    end procedure;

    procedure test_combine_response is
      variable resp, resp1, resp2, expected : std_logic_vector(axi_resp_sz - 1 downto 0);
    begin
      for i in 0 to 1000 loop
        resp1 := rnd.RandSlv(resp'length);
        resp2 := rnd.RandSlv(resp'length);
        resp := combine_response(resp1, resp2);

        if resp1 = axi_resp_decerr or resp2 = axi_resp_decerr then
          expected := axi_resp_decerr;
        elsif resp1 = axi_resp_slverr or resp2 = axi_resp_slverr then
          expected := axi_resp_slverr;
        elsif resp1 = axi_resp_okay or resp2 = axi_resp_okay then
          expected := axi_resp_okay;
        else
          expected := axi_resp_exokay;
        end if;
        check_equal(resp, expected, "resp1: " & to_string(resp1) & ", resp2: " & to_string(resp1));

      end loop;
    end procedure;

  begin
    test_runner_setup(runner, runner_cfg);
    rnd.InitSeed(rnd'instance_name);

    if run("test_slv_conversion") then

      for iteration in 0 to 1000 loop
        -- Loop a couple of times to get good random coverage
        test_slv_conversion(iteration);
      end loop;


    elsif run("test_combine_response") then
      test_combine_response;
    end if;

    test_runner_cleanup(runner);
  end process;

end architecture;
