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
-- Performs protocol checking to verify that the downstream AXI slave is performing
-- everything correctly.
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

library vunit_lib;
use vunit_lib.bus_master_pkg.bus_master_t;
use vunit_lib.bus_master_pkg.address_length;
use vunit_lib.bus_master_pkg.data_length;

library axi;
use axi.axi_pkg.all;

library common;


entity axi_master is
  generic (
    bus_handle : bus_master_t;
    -- Width of the ARID/RID/AWID/BID fields.
    -- Only used for protocol checking of the R and B channels.
    id_width : natural range 0 to axi_id_sz := 0;
    -- Suffix for error log messages. Can be used to differentiate between multiple instances.
    logger_name_suffix : string := ""
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

  constant len : axi_a_len_t := to_len(burst_length_beats=>1);
  constant size : axi_a_size_t := to_size(data_width_bits=>data_width);

  signal araddr, awaddr : std_ulogic_vector(address_length(bus_handle) - 1 downto 0) := (
    others => '0'
  );

  signal rdata, wdata : std_ulogic_vector(data_width - 1 downto 0) := (others => '0');
  signal wstrb : std_ulogic_vector(wdata'length / 8 - 1 downto 0) := (others => '0');

begin

  ------------------------------------------------------------------------------
  assert sanity_check_axi_data_width(data_width)
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


  ------------------------------------------------------------------------------
  ar_protocol_checker_inst : entity common.axi_stream_protocol_checker
    generic map (
      logger_name_suffix => " - axi_master - AR" & logger_name_suffix
    )
    port map (
      clk => clk,
      --
      ready => axi_read_s2m.ar.ready
    );


  ------------------------------------------------------------------------------
  r_protocol_checker_inst : entity common.axi_stream_protocol_checker
    generic map (
      data_width => rdata'length,
      id_width => id_width,
      user_width => axi_read_s2m.r.resp'length,
      logger_name_suffix => " - axi_master - R" & logger_name_suffix
    )
    port map (
      clk => clk,
      --
      ready => axi_read_m2s.r.ready,
      valid => axi_read_s2m.r.valid,
      last => axi_read_s2m.r.last,
      data => rdata,
      id => axi_read_s2m.r.id(id_width - 1 downto 0),
      user => axi_read_s2m.r.resp
    );


  ------------------------------------------------------------------------------
  aw_protocol_checker_inst : entity common.axi_stream_protocol_checker
    generic map (
      logger_name_suffix => " - axi_master - AW" & logger_name_suffix
    )
    port map (
      clk => clk,
      --
      ready => axi_write_s2m.aw.ready
    );


  ------------------------------------------------------------------------------
  w_protocol_checker_inst : entity common.axi_stream_protocol_checker
    generic map (
      logger_name_suffix => " - axi_master - W" & logger_name_suffix
    )
    port map (
      clk => clk,
      --
      ready => axi_write_s2m.w.ready
    );


  ------------------------------------------------------------------------------
  b_protocol_checker_inst : entity common.axi_stream_protocol_checker
    generic map (
      id_width => id_width,
      user_width => axi_write_s2m.b.resp'length,
      logger_name_suffix => " - axi_master - B" & logger_name_suffix
    )
    port map (
      clk => clk,
      --
      ready => axi_write_m2s.b.ready,
      valid => axi_write_s2m.b.valid,
      id => axi_write_s2m.b.id(id_width - 1 downto 0),
      user => axi_write_s2m.b.resp
    );

end architecture;
