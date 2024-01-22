-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the hdl-modules project, a collection of reusable, high-quality,
-- peer-reviewed VHDL building blocks.
-- https://hdl-modules.com
-- https://github.com/hdl-modules/hdl-modules
-- -------------------------------------------------------------------------------------------------
-- Pipelining of a full AXI-Lite bus (read and write), with the goal of improving timing on the data
-- and/or control signals.
--
-- The default settings will result in full skid-aside buffers, which pipeline both the
-- data and control signals.
-- However the generics to :ref:`common.handshake_pipeline` can be modified to
-- get a simpler implementation that results in lower resource utilization.
-- -------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library axi;
use axi.axi_pkg.all;

library common;

use work.axi_lite_pkg.all;


entity axi_lite_pipeline is
  generic (
    data_width : positive range 1 to axi_lite_data_sz;
    addr_width : positive range 1 to axi_a_addr_sz;
    -- Settings to the handshake_pipeline blocks. These default settings (the same as
    -- handshake_pipeline's defaults) give full throughput and the lowest logic depth.
    -- They can be changed from default in order to decrease logic utilization.
    full_throughput : boolean := true;
    pipeline_control_signals : boolean := true
  );
  port (
    clk : in std_ulogic;
    --# {{}}
    master_m2s : in axi_lite_m2s_t;
    master_s2m : out axi_lite_s2m_t := axi_lite_s2m_init;
    --# {{}}
    slave_m2s : out axi_lite_m2s_t := axi_lite_m2s_init;
    slave_s2m : in axi_lite_s2m_t
  );
end entity;

architecture a of axi_lite_pipeline is

begin

  ------------------------------------------------------------------------------
  aw_block : block
    constant a_width : positive := axi_lite_m2s_a_sz(addr_width=>addr_width);
    signal input_data, output_data : std_ulogic_vector(a_width - 1 downto 0) := (others => '0');
  begin

    input_data <= std_logic_vector(master_m2s.write.aw.addr(input_data'range));

    slave_m2s.write.aw.addr(output_data'range) <= unsigned(output_data);


    ------------------------------------------------------------------------------
    handshake_pipeline_inst : entity common.handshake_pipeline
      generic map (
        data_width => input_data'length,
        full_throughput => full_throughput,
        pipeline_control_signals => pipeline_control_signals
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
    constant w_width : positive := axi_lite_m2s_w_sz(data_width=>data_width);
    signal input_data, output_data : std_ulogic_vector(w_width - 1 downto 0) := (others => '0');
    signal output_record : axi_lite_m2s_w_t := axi_lite_m2s_w_init;
  begin

    input_data <= to_slv(data=>master_m2s.write.w, data_width=>data_width);

    output_record <= to_axi_lite_m2s_w(data=>output_data, data_width=>data_width);
    slave_m2s.write.w.data <= output_record.data;
    slave_m2s.write.w.strb <= output_record.strb;


    ------------------------------------------------------------------------------
    handshake_pipeline_inst : entity common.handshake_pipeline
      generic map (
        data_width => input_data'length,
        full_throughput => full_throughput,
        pipeline_control_signals => pipeline_control_signals
      )
      port map(
        clk => clk,
        --
        input_ready => master_s2m.write.w.ready,
        input_valid => master_m2s.write.w.valid,
        input_data => input_data,
        --
        output_ready => slave_s2m.write.w.ready,
        output_valid => slave_m2s.write.w.valid,
        output_data => output_data
      );

  end block;


  ------------------------------------------------------------------------------
  b_handshake_pipeline_inst : entity common.handshake_pipeline
    generic map (
      data_width => axi_lite_s2m_b_sz,
      full_throughput => full_throughput,
      pipeline_control_signals => pipeline_control_signals
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
    constant a_width : positive := axi_lite_m2s_a_sz(addr_width=>addr_width);
    signal input_data, output_data : std_ulogic_vector(a_width - 1 downto 0) := (others => '0');
  begin

    input_data <= std_logic_vector(master_m2s.read.ar.addr(input_data'range));

    slave_m2s.read.ar.addr(output_data'range) <= unsigned(output_data);


    ------------------------------------------------------------------------------
    handshake_pipeline_inst : entity common.handshake_pipeline
      generic map (
        data_width => input_data'length,
        full_throughput => full_throughput,
        pipeline_control_signals => pipeline_control_signals
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
    constant r_width : positive := axi_lite_s2m_r_sz(data_width);
    signal input_data, output_data : std_ulogic_vector(r_width - 1 downto 0) := (others => '0');
    signal output_record : axi_lite_s2m_r_t := axi_lite_s2m_r_init;
  begin

    input_data <= to_slv(slave_s2m.read.r, data_width);

    output_record <= to_axi_lite_s2m_r(data=>output_data, data_width=>data_width);
    master_s2m.read.r.data <= output_record.data;
    master_s2m.read.r.resp <= output_record.resp;


    ------------------------------------------------------------------------------
    handshake_pipeline_inst : entity common.handshake_pipeline
      generic map (
        data_width => input_data'length,
        full_throughput => full_throughput,
        pipeline_control_signals => pipeline_control_signals
      )
      port map(
        clk => clk,
        --
        input_ready => slave_m2s.read.r.ready,
        input_valid => slave_s2m.read.r.valid,
        input_data => input_data,
        --
        output_ready => master_m2s.read.r.ready,
        output_valid => master_s2m.read.r.valid,
        output_data => output_data
      );

  end block;

end architecture;
