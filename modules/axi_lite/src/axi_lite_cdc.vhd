-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the hdl-modules project, a collection of reusable, high-quality,
-- peer-reviewed VHDL building blocks.
-- https://hdl-modules.com
-- https://github.com/hdl-modules/hdl-modules
-- -------------------------------------------------------------------------------------------------
-- Clock domain crossing of a full AXI-Lite bus (read and write) using asynchronous FIFOs for the
-- different channels.
-- By setting the width generics, the bus is packed optimally so that no unnecessary resources
-- are consumed.
--
-- .. note::
--   The constraints of :ref:`fifo.asynchronous_fifo` must be used.
-- -------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library axi;
use axi.axi_pkg.all;

library common;
use common.attribute_pkg.all;

library fifo;

use work.axi_lite_pkg.all;


entity axi_lite_cdc is
  generic (
    data_width : positive range 1 to axi_lite_data_sz;
    addr_width : positive range 1 to axi_a_addr_sz;
    fifo_depth : positive := 16;
    ram_type : ram_style_t := ram_style_auto
  );
  port (
    clk_master : in std_ulogic;
    master_m2s : in axi_lite_m2s_t;
    master_s2m : out axi_lite_s2m_t := axi_lite_s2m_init;
    --# {{}}
    clk_slave : in std_ulogic;
    slave_m2s : out axi_lite_m2s_t := axi_lite_m2s_init;
    slave_s2m : in axi_lite_s2m_t
  );
end entity;

architecture a of axi_lite_cdc is

begin

  ------------------------------------------------------------------------------
  aw_block : block
    constant a_width : positive := axi_lite_m2s_a_sz(addr_width=>addr_width);
    signal write_data, read_data : std_ulogic_vector(a_width - 1 downto 0) := (others => '0');
  begin

    write_data <= std_logic_vector(master_m2s.write.aw.addr(write_data'range));

    slave_m2s.write.aw.addr(read_data'range) <= unsigned(read_data);


    ------------------------------------------------------------------------------
    aw_asynchronous_fifo_inst : entity fifo.asynchronous_fifo
      generic map (
        width => write_data'length,
        depth => fifo_depth,
        ram_type => ram_type
      )
      port map(
        clk_read => clk_slave,
        read_ready => slave_s2m.write.aw.ready,
        read_valid => slave_m2s.write.aw.valid,
        read_data => read_data,
        --
        clk_write => clk_master,
        write_ready => master_s2m.write.aw.ready,
        write_valid => master_m2s.write.aw.valid,
        write_data => write_data
      );

  end block;


  ------------------------------------------------------------------------------
  w_block : block
    constant w_width : positive := axi_lite_m2s_w_sz(data_width=>data_width);
    signal write_data, read_data : std_ulogic_vector(w_width - 1 downto 0) := (others => '0');
    signal read_record : axi_lite_m2s_w_t := axi_lite_m2s_w_init;
  begin

    write_data <= to_slv(data=>master_m2s.write.w, data_width=>data_width);

    read_record <= to_axi_lite_m2s_w(data=>read_data, data_width=>data_width);
    slave_m2s.write.w.data <= read_record.data;
    slave_m2s.write.w.strb <= read_record.strb;


    ------------------------------------------------------------------------------
    w_asynchronous_fifo_inst : entity fifo.asynchronous_fifo
      generic map (
        width => w_width,
        depth => fifo_depth,
        ram_type => ram_type
      )
      port map(
        clk_read => clk_slave,
        read_ready => slave_s2m.write.w.ready,
        read_valid => slave_m2s.write.w.valid,
        read_data => read_data,
        --
        clk_write => clk_master,
        write_ready => master_s2m.write.w.ready,
        write_valid => master_m2s.write.w.valid,
        write_data => write_data
      );

  end block;


  ------------------------------------------------------------------------------
  b_asynchronous_fifo_inst : entity fifo.asynchronous_fifo
    generic map (
      width => axi_lite_s2m_b_sz,
      depth => fifo_depth,
      ram_type => ram_type
    )
    port map(
      clk_read => clk_master,
      read_ready => master_m2s.write.b.ready,
      read_valid => master_s2m.write.b.valid,
      read_data => master_s2m.write.b.resp,
      --
      clk_write => clk_slave,
      write_ready => slave_m2s.write.b.ready,
      write_valid => slave_s2m.write.b.valid,
      write_data => slave_s2m.write.b.resp
    );


  ------------------------------------------------------------------------------
  ar_block : block
    constant a_width : positive := axi_lite_m2s_a_sz(addr_width=>addr_width);
    signal write_data, read_data : std_ulogic_vector(a_width - 1 downto 0) := (others => '0');
  begin

    write_data <= std_logic_vector(master_m2s.read.ar.addr(write_data'range));

    slave_m2s.read.ar.addr(read_data'range) <= unsigned(read_data);


    ------------------------------------------------------------------------------
    ar_asynchronous_fifo_inst : entity fifo.asynchronous_fifo
      generic map (
        width => write_data'length,
        depth => fifo_depth,
        ram_type => ram_type
      )
      port map(
        clk_read => clk_slave,
        read_ready => slave_s2m.read.ar.ready,
        read_valid => slave_m2s.read.ar.valid,
        read_data => read_data,
        --
        clk_write => clk_master,
        write_ready => master_s2m.read.ar.ready,
        write_valid => master_m2s.read.ar.valid,
        write_data => write_data
      );

  end block;


  ------------------------------------------------------------------------------
  r_block : block
    constant r_width : positive := axi_lite_s2m_r_sz(data_width=>data_width);
    signal write_data, read_data : std_ulogic_vector(r_width - 1 downto 0);
    signal read_record : axi_lite_s2m_r_t := axi_lite_s2m_r_init;
  begin

    write_data <= to_slv(slave_s2m.read.r, data_width);

    read_record <= to_axi_lite_s2m_r(data=>read_data, data_width=>data_width);
    master_s2m.read.r.data <= read_record.data;
    master_s2m.read.r.resp <= read_record.resp;


    ------------------------------------------------------------------------------
    r_asynchronous_fifo_inst : entity fifo.asynchronous_fifo
      generic map (
        width => write_data'length,
        depth => fifo_depth,
        ram_type => ram_type
      )
      port map(
        clk_read => clk_master,
        read_ready => master_m2s.read.r.ready,
        read_valid => master_s2m.read.r.valid,
        read_data => read_data,
        --
        clk_write => clk_slave,
        write_ready => slave_m2s.read.r.ready,
        write_valid => slave_s2m.read.r.valid,
        write_data => write_data
      );

  end block;

end architecture;
