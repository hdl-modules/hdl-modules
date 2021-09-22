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

library vunit_lib;
context vunit_lib.vc_context;

library axi;
use axi.axi_pkg.all;


entity axi_write_slave is
  generic (
    axi_slave : axi_slave_t;
    data_width : positive;
    -- Note that the VUnit BFM creates and integer_vector_ptr of length 2**id_width, so a large
    -- value for id_width might crash your simulator.
    id_width : natural := 8;
    w_fifo_depth : natural := 0
  );
  port (
    clk : in std_logic;
    axi_write_m2s : in axi_write_m2s_t := axi_write_m2s_init;
    axi_write_s2m : out axi_write_s2m_t := axi_write_s2m_init
  );
end entity;

architecture a of axi_write_slave is

  signal w_fifo_m2s : axi_m2s_w_t := axi_m2s_w_init;
  signal w_fifo_s2m : axi_s2m_w_t := axi_s2m_w_init;

  signal awid, bid : std_logic_vector(id_width - 1 downto 0) := (others => '0');
  signal awaddr : std_logic_vector(axi_write_m2s.aw.addr'range) := (others => '0');
  signal awlen : std_logic_vector(axi_write_m2s.aw.len'range) := (others => '0');
  signal awsize : std_logic_vector(axi_write_m2s.aw.size'range) := (others => '0');

begin

  ------------------------------------------------------------------------------
  -- Optionally use a FIFO for the data channel. This enables a data flow pattern where
  -- the AXI slave can accept a lot of data (many bursts) before a single address transactions
  -- occurs. This can affect the behavior of your AXI master, and is a case that needs to
  -- tested sometimes.
  axi_w_fifo_inst : entity axi.axi_w_fifo
    generic map (
      data_width => data_width,
      asynchronous => false,
      depth => w_fifo_depth
    )
    port map (
      clk => clk,
      --
      input_m2s => axi_write_m2s.w,
      input_s2m => axi_write_s2m.w,
      --
      output_m2s => w_fifo_m2s,
      output_s2m => w_fifo_s2m
    );


  ------------------------------------------------------------------------------
  axi_write_slave_inst : entity vunit_lib.axi_write_slave
    generic map (
      axi_slave => axi_slave
    )
    port map (
      aclk => clk,

      awvalid => axi_write_m2s.aw.valid,
      awready => axi_write_s2m.aw.ready,
      awid => awid,
      awaddr => awaddr,
      awlen => awlen,
      awsize => awsize,
      awburst => axi_write_m2s.aw.burst,

      wvalid => w_fifo_m2s.valid,
      wready => w_fifo_s2m.ready,
      wdata => w_fifo_m2s.data(data_width - 1 downto 0),
      wstrb => w_fifo_m2s.strb,
      wlast => w_fifo_m2s.last,

      bvalid => axi_write_s2m.b.valid,
      bready => axi_write_m2s.b.ready,
      bid => bid,
      bresp => axi_write_s2m.b.resp
    );

  awid <= std_logic_vector(axi_write_m2s.aw.id(id_width - 1 downto 0));
  awaddr <= std_logic_vector(axi_write_m2s.aw.addr);
  awlen <= std_logic_vector(axi_write_m2s.aw.len);
  awsize <= std_logic_vector(axi_write_m2s.aw.size);

  axi_write_s2m.b.id(bid'range) <= unsigned(bid);

end architecture;
