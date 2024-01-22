-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the hdl-modules project, a collection of reusable, high-quality,
-- peer-reviewed VHDL building blocks.
-- https://hdl-modules.com
-- https://github.com/hdl-modules/hdl-modules
-- -------------------------------------------------------------------------------------------------
-- Creates AXI read/write transactions by wrapping the VUnit ``axi_lite_master``
-- verification component (VC).
-- Uses convenient record types for the AXI signals.
--
-- .. note::
--
--   This AXI BFM wraps an AXI-Lite verification component, meaning it can not be used to produce
--   burst transactions.
--   If you want to create burst transactions, with built-in checkers, see the
--   :ref:`bfm.axi_read_master` and :ref:`bfm.axi_write_master` BFMs instead.
--
-- The AXI-Lite interface of the wrapped verification component is connected to the "full" AXI
-- interface of this BFM.
-- This wrapper is typically only used for register read/write operations on the chip top level,
-- where the register bus is still AXI.
--
-- It is used by performing VUnit VC calls, such as ``read_bus``,
-- or, preferably when operating on a register bus, by using the convenience methods
-- in :ref:`reg_file.reg_operations_pkg`.
-- -------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library axi;
use axi.axi_pkg.all;

library vunit_lib;
context vunit_lib.vc_context;


entity axi_master is
  generic (
    bus_handle : bus_master_t
  );
  port (
    clk : in std_ulogic;
    --# {{}}
    axi_read_m2s : out axi_read_m2s_t := axi_read_m2s_init;
    axi_read_s2m : in axi_read_s2m_t;
    --# {{}}
    axi_write_m2s : out axi_write_m2s_t := axi_write_m2s_init;
    axi_write_s2m : in axi_write_s2m_t
  );
end entity;

architecture a of axi_master is

  constant data_width : positive := data_length(bus_handle);

  constant len : axi_a_len_t := to_len(1);
  constant size : axi_a_size_t := to_size(data_width);

  signal araddr, awaddr : std_ulogic_vector(address_length(bus_handle) - 1 downto 0) := (
    others => '0'
  );
  signal rdata, wdata : std_ulogic_vector(data_width - 1 downto 0) := (others => '0');
  signal wstrb : std_ulogic_vector(byte_enable_length(bus_handle) - 1 downto 0) := (others => '0');

begin

  ------------------------------------------------------------------------------
  assert sanity_check_axi_data_width(data_length(bus_handle))
    report "Invalid AXI data width, see printout above"
    severity failure;


  ------------------------------------------------------------------------------
  axi_read_m2s.ar.addr(araddr'range) <= unsigned(araddr);
  axi_read_m2s.ar.len <= len;
  axi_read_m2s.ar.size <= size;
  axi_read_m2s.ar.burst <= axi_a_burst_incr;

  rdata <= axi_read_s2m.r.data(rdata'range);

  axi_write_m2s.aw.addr(awaddr'range) <= unsigned(awaddr);
  axi_write_m2s.aw.len <= len;
  axi_write_m2s.aw.size <= size;
  axi_write_m2s.aw.burst <= axi_a_burst_incr;

  axi_write_m2s.w.data(wdata'range) <= wdata;
  axi_write_m2s.w.strb(wstrb'range) <= wstrb;
  axi_write_m2s.w.last <= '1';


  ------------------------------------------------------------------------------
  axi_lite_master_inst : entity vunit_lib.axi_lite_master
    generic map (
      bus_handle => bus_handle
    )
    port map (
      aclk => clk,
      --
      arready => axi_read_s2m.ar.ready,
      arvalid => axi_read_m2s.ar.valid,
      araddr => araddr,
      --
      rready => axi_read_m2s.r.ready,
      rvalid => axi_read_s2m.r.valid,
      rdata => rdata,
      rresp => axi_read_s2m.r.resp,
      --
      awready => axi_write_s2m.aw.ready,
      awvalid => axi_write_m2s.aw.valid,
      awaddr => awaddr,
      --
      wready => axi_write_s2m.w.ready,
      wvalid => axi_write_m2s.w.valid,
      wdata => wdata,
      wstrb => wstrb,
      --
      bready => axi_write_m2s.b.ready,
      bvalid => axi_write_s2m.b.valid,
      bresp => axi_write_s2m.b.resp
    );

end architecture;
