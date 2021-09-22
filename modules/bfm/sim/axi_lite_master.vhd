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

library math;
use math.math_pkg.all;

library axi;
use axi.axi_lite_pkg.all;

library vunit_lib;
context vunit_lib.vunit_context;
context vunit_lib.vc_context;


entity axi_lite_master is
  generic (
    bus_handle : bus_master_t
  );
  port (
    clk : in std_logic;

    axi_lite_m2s : out axi_lite_m2s_t := axi_lite_m2s_init;
    axi_lite_s2m : in axi_lite_s2m_t := axi_lite_s2m_init
  );
end entity;

architecture a of axi_lite_master is

  signal rdata, wdata : std_logic_vector(data_length(bus_handle) - 1 downto 0);
  signal wstrb : std_logic_vector(byte_enable_length(bus_handle) - 1 downto 0);

  signal araddr, awaddr : std_logic_vector(address_length(bus_handle) - 1 downto 0);

begin

  ------------------------------------------------------------------------------
  axi_lite_m2s.read.ar.addr(araddr'range) <= unsigned(araddr);
  rdata <= axi_lite_s2m.read.r.data(rdata'range);

  axi_lite_m2s.write.aw.addr(awaddr'range) <= unsigned(awaddr);
  axi_lite_m2s.write.w.data(wdata'range) <= wdata;
  axi_lite_m2s.write.w.strb(wstrb'range) <= wstrb;


  ------------------------------------------------------------------------------
  axi_lite_master_inst : entity vunit_lib.axi_lite_master
  generic map (
    bus_handle => bus_handle
  )
  port map (
    aclk => clk,

    arready => axi_lite_s2m.read.ar.ready,
    arvalid => axi_lite_m2s.read.ar.valid,
    araddr => araddr,

    rready => axi_lite_m2s.read.r.ready,
    rvalid => axi_lite_s2m.read.r.valid,
    rdata => rdata,
    rresp => axi_lite_s2m.read.r.resp,

    awready => axi_lite_s2m.write.aw.ready,
    awvalid => axi_lite_m2s.write.aw.valid,
    awaddr => awaddr,

    wready => axi_lite_s2m.write.w.ready,
    wvalid => axi_lite_m2s.write.w.valid,
    wdata => wdata,
    wstrb => wstrb,

    bready => axi_lite_m2s.write.b.ready,
    bvalid => axi_lite_s2m.write.b.valid,
    bresp => axi_lite_s2m.write.b.resp
  );

end architecture;
