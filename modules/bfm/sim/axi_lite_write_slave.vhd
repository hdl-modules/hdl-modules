-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the tsfpga project.
-- https://tsfpga.com
-- https://gitlab.com/tsfpga/tsfpga
-- -------------------------------------------------------------------------------------------------
-- Wrapper around VUnit BFM that uses convenient record types for the AXI signals.
-- -------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library axi;
use axi.axi_pkg.all;
use axi.axi_lite_pkg.all;

library vunit_lib;
context vunit_lib.vc_context;


entity axi_lite_write_slave is
  generic (
    axi_slave : axi_slave_t;
    data_width : integer
  );
  port (
    clk : in std_logic;
    --
    axi_lite_write_m2s : in axi_lite_write_m2s_t := axi_lite_write_m2s_init;
    axi_lite_write_s2m : out axi_lite_write_s2m_t := axi_lite_write_s2m_init
  );
end entity;

architecture a of axi_lite_write_slave is

  constant len : std_logic_vector(axi_a_len_sz - 1 downto 0) := std_logic_vector(to_len(1));
  constant size : std_logic_vector(axi_a_size_sz - 1 downto 0) :=
    std_logic_vector(to_size(data_width));

  -- Using "open" not ok in GHDL: unconstrained port "rid" must be connected
  signal bid, aid : std_logic_vector(8 - 1 downto 0) := (others => '0');

  signal awaddr : std_logic_vector(axi_lite_write_m2s.aw.addr'range);

begin

  ------------------------------------------------------------------------------
  axi_write_slave_inst : entity vunit_lib.axi_write_slave
    generic map (
      axi_slave => axi_slave
    )
    port map (
      aclk => clk,
      --
      awvalid => axi_lite_write_m2s.aw.valid,
      awready => axi_lite_write_s2m.aw.ready,
      awid => aid,
      awaddr => awaddr,
      awlen => len,
      awsize => size,
      awburst => axi_a_burst_fixed,
      --
      wvalid => axi_lite_write_m2s.w.valid,
      wready => axi_lite_write_s2m.w.ready,
      wdata => axi_lite_write_m2s.w.data(data_width - 1 downto 0),
      wstrb => axi_lite_write_m2s.w.strb,
      wlast => '1',
      --
      bvalid => axi_lite_write_s2m.b.valid,
      bready => axi_lite_write_m2s.b.ready,
      bid => bid,
      bresp => axi_lite_write_s2m.b.resp
    );

  awaddr <= std_logic_vector(axi_lite_write_m2s.aw.addr);

end architecture;
