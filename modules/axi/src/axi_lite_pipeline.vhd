-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the tsfpga project.
-- https://tsfpga.com
-- https://gitlab.com/tsfpga/tsfpga
-- -------------------------------------------------------------------------------------------------
-- Pipelining of an AXI-Lite bus. Full throughput and improved timing characteristics are achieved
-- through the use of skid buffers. However to generics to handshake_pipeline can be modified to
-- get a simpler handshake_pipeline implementation that results in lower resource utilizatoin.
-- -------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library common;

use work.axi_lite_pkg.all;
use work.axi_pkg.all;


entity axi_lite_pipeline is
  generic (
    data_width : positive;
    addr_width : positive;
    -- Settings to the handshake_pipeline blocks. These default settings (the same as
    -- handshake_pipeline's defaults) give full throughput and the lowest logic depth.
    -- They can be changed from default in order to decrease logic utilization.
    full_throughput : boolean := true;
    allow_poor_input_ready_timing : boolean := false
  );
  port (
    clk : in std_logic;
    --
    master_m2s : in axi_lite_m2s_t;
    master_s2m : out axi_lite_s2m_t := axi_lite_s2m_init;
    --
    slave_m2s : out axi_lite_m2s_t := axi_lite_m2s_init;
    slave_s2m : in axi_lite_s2m_t
  );
end entity;

architecture a of axi_lite_pipeline is

begin

  ------------------------------------------------------------------------------
  aw_block : block
    signal output_data, input_data : std_logic_vector(addr_width - 1 downto 0);
  begin

    slave_m2s.write.aw.addr(output_data'range) <= unsigned(output_data);
    input_data <= std_logic_vector(master_m2s.write.aw.addr(input_data'range));

    aw_handshake_pipeline_inst : entity common.handshake_pipeline
      generic map (
        data_width => axi_lite_m2s_a_sz(addr_width),
        full_throughput => full_throughput,
        allow_poor_input_ready_timing => allow_poor_input_ready_timing
      )
      port map(
        clk => clk,
        --
        input_ready => master_s2m.write.aw.ready,
        input_valid => master_m2s.write.aw.valid,
        input_data => input_data,
        --
        output_ready => slave_s2m.write.aw.ready,
        output_valid => slave_m2s.write.aw.valid,
        output_data => output_data
      );
  end block;


  ------------------------------------------------------------------------------
  w_block : block
    constant w_width : integer := axi_lite_m2s_w_sz(data_width);
    signal master_m2s_w, slave_m2s_w : std_logic_vector(w_width - 1 downto 0);
  begin

    slave_m2s.write.w.data <= to_axi_lite_m2s_w(slave_m2s_w, data_width).data;
    slave_m2s.write.w.strb <= to_axi_lite_m2s_w(slave_m2s_w, data_width).strb;
    master_m2s_w <= to_slv(master_m2s.write.w, data_width);

    handshake_pipeline_inst : entity common.handshake_pipeline
      generic map (
        data_width => w_width,
        full_throughput => full_throughput,
        allow_poor_input_ready_timing => allow_poor_input_ready_timing
      )
      port map(
        clk => clk,
        --
        input_ready => master_s2m.write.w.ready,
        input_valid => master_m2s.write.w.valid,
        input_data => master_m2s_w,
        --
        output_ready => slave_s2m.write.w.ready,
        output_valid => slave_m2s.write.w.valid,
        output_data => slave_m2s_w
      );
  end block;


  ------------------------------------------------------------------------------
  b_handshake_pipeline_inst : entity common.handshake_pipeline
    generic map (
      data_width => axi_lite_s2m_b_sz,
      full_throughput => full_throughput,
      allow_poor_input_ready_timing => allow_poor_input_ready_timing
    )
    port map(
      clk => clk,
      --
      input_ready => slave_m2s.write.b.ready,
      input_valid => slave_s2m.write.b.valid,
      input_data => slave_s2m.write.b.resp,
      --
      output_ready => master_m2s.write.b.ready,
      output_valid => master_s2m.write.b.valid,
      output_data => master_s2m.write.b.resp
    );


  ------------------------------------------------------------------------------
  ar_block : block
    signal output_data, input_data : std_logic_vector(addr_width - 1 downto 0);
  begin

    slave_m2s.read.ar.addr(output_data'range) <= unsigned(output_data);
    input_data <= std_logic_vector(master_m2s.read.ar.addr(input_data'range));

    ar_handshake_pipeline_inst : entity common.handshake_pipeline
      generic map (
        data_width => axi_lite_m2s_a_sz(addr_width),
        full_throughput => full_throughput,
        allow_poor_input_ready_timing => allow_poor_input_ready_timing
      )
      port map(
        clk => clk,
        --
        input_ready => master_s2m.read.ar.ready,
        input_valid => master_m2s.read.ar.valid,
        input_data => input_data,
        --
        output_ready => slave_s2m.read.ar.ready,
        output_valid => slave_m2s.read.ar.valid,
        output_data => output_data
      );
  end block;


  ------------------------------------------------------------------------------
  r_block : block
    constant r_width : integer := axi_lite_s2m_r_sz(data_width);
    signal master_s2m_r, slave_s2m_r : std_logic_vector(r_width - 1 downto 0);
  begin

    master_s2m.read.r.data <= to_axi_lite_s2m_r(master_s2m_r, data_width).data;
    master_s2m.read.r.resp <= to_axi_lite_s2m_r(master_s2m_r, data_width).resp;
    slave_s2m_r <= to_slv(slave_s2m.read.r, data_width);

    handshake_pipeline_inst : entity common.handshake_pipeline
      generic map (
        data_width => r_width,
        full_throughput => full_throughput,
        allow_poor_input_ready_timing => allow_poor_input_ready_timing
      )
      port map(
        clk => clk,
        --
        input_ready => slave_m2s.read.r.ready,
        input_valid => slave_s2m.read.r.valid,
        input_data => slave_s2m_r,
        --
        output_ready => master_m2s.read.r.ready,
        output_valid => master_s2m.read.r.valid,
        output_data => master_s2m_r
      );
  end block;

end architecture;
