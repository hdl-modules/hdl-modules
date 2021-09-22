-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the tsfpga project.
-- https://tsfpga.com
-- https://gitlab.com/tsfpga/tsfpga
-- -------------------------------------------------------------------------------------------------
-- Clock crossing of an AXI-Lite bus
-- -------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library common;
use common.attribute_pkg.all;

library fifo;

use work.axi_lite_pkg.all;
use work.axi_pkg.all;


entity axi_lite_cdc is
  generic (
    data_width : positive;
    addr_width : positive;
    fifo_depth : positive := 16;
    ram_type : ram_style_t := ram_style_auto
  );
  port (
    clk_master : in std_logic;
    master_m2s : in axi_lite_m2s_t;
    master_s2m : out axi_lite_s2m_t := axi_lite_s2m_init;
    --
    clk_slave : in std_logic;
    slave_m2s : out axi_lite_m2s_t := axi_lite_m2s_init;
    slave_s2m : in axi_lite_s2m_t
  );
end entity;

architecture a of axi_lite_cdc is

begin

  ------------------------------------------------------------------------------
  aw_block : block
    signal read_data, write_data : std_logic_vector(addr_width - 1 downto 0);
  begin

    slave_m2s.write.aw.addr(read_data'range) <= unsigned(read_data);
    write_data <= std_logic_vector(master_m2s.write.aw.addr(write_data'range));

    aw_asynchronous_fifo_inst : entity fifo.asynchronous_fifo
      generic map (
        width => axi_lite_m2s_a_sz(addr_width),
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
    constant w_width : integer := axi_lite_m2s_w_sz(data_width);
    signal write_data, read_data : std_logic_vector(w_width - 1 downto 0);
  begin

    slave_m2s.write.w.data <= to_axi_lite_m2s_w(read_data, data_width).data;
    slave_m2s.write.w.strb <= to_axi_lite_m2s_w(read_data, data_width).strb;
    write_data <= to_slv(master_m2s.write.w, data_width);

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
    signal read_data, write_data : std_logic_vector(addr_width - 1 downto 0);
  begin

    slave_m2s.read.ar.addr(read_data'range) <= unsigned(read_data);
    write_data <= std_logic_vector(master_m2s.read.ar.addr(write_data'range));

    ar_asynchronous_fifo_inst : entity fifo.asynchronous_fifo
      generic map (
        width => axi_lite_m2s_a_sz(addr_width),
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
    constant r_width : integer := axi_lite_s2m_r_sz(data_width);
    signal read_data, write_data : std_logic_vector(r_width - 1 downto 0);
  begin

    master_s2m.read.r.data <= to_axi_lite_s2m_r(read_data, data_width).data;
    master_s2m.read.r.resp <= to_axi_lite_s2m_r(read_data, data_width).resp;
    write_data <= to_slv(slave_s2m.read.r, data_width);

    r_asynchronous_fifo_inst : entity fifo.asynchronous_fifo
      generic map (
        width => r_width,
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
