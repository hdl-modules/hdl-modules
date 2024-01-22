-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the hdl-modules project, a collection of reusable, high-quality,
-- peer-reviewed VHDL building blocks.
-- https://hdl-modules.com
-- https://github.com/hdl-modules/hdl-modules
-- -------------------------------------------------------------------------------------------------
-- Simple N-to-1 crossbar for connecting multiple AXI-Lite write masters to one port.
-- This is a wrapper around :ref:`axi.axi_simple_write_crossbar`. See that entity for details.
-- -------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

library axi;
use axi.axi_pkg.all;

library axi_lite;
use axi_lite.axi_lite_pkg.all;


entity axi_lite_simple_write_crossbar is
  generic(
    num_inputs : positive
  );
  port(
    clk : in std_ulogic;
    --# {{}}
    input_ports_m2s : in axi_lite_write_m2s_vec_t(0 to num_inputs - 1) := (
      others => axi_lite_write_m2s_init
    );
    input_ports_s2m : out axi_lite_write_s2m_vec_t(0 to num_inputs - 1) := (
      others => axi_lite_write_s2m_init
    );
    --# {{}}
    output_m2s : out axi_lite_write_m2s_t := axi_lite_write_m2s_init;
    output_s2m : in axi_lite_write_s2m_t := axi_lite_write_s2m_init
  );
end entity;

architecture a of axi_lite_simple_write_crossbar is

  signal input_ports_axi_m2s : axi_write_m2s_vec_t(0 to num_inputs - 1) := (
    others => axi_write_m2s_init
  );
  signal input_ports_axi_s2m : axi_write_s2m_vec_t(0 to num_inputs - 1) := (
    others => axi_write_s2m_init
  );

  signal output_axi_m2s : axi_write_m2s_t := axi_write_m2s_init;
  signal output_axi_s2m : axi_write_s2m_t := axi_write_s2m_init;

begin

  -- Assign to the AXI records only what is needed for the AXI-Lite function.

  ------------------------------------------------------------------------------
  input_ports_loop : for input_idx in input_ports_axi_m2s'range generate
    input_ports_axi_m2s(input_idx).aw.valid <= input_ports_m2s(input_idx).aw.valid;
    input_ports_axi_m2s(input_idx).aw.addr <= input_ports_m2s(input_idx).aw.addr;

    input_ports_s2m(input_idx).aw.ready <= input_ports_axi_s2m(input_idx).aw.ready;

    input_ports_axi_m2s(input_idx).w.valid <= input_ports_m2s(input_idx).w.valid;
    input_ports_axi_m2s(input_idx).w.data(
      input_ports_m2s(0).w.data'range
    ) <= input_ports_m2s(input_idx).w.data;
    input_ports_axi_m2s(input_idx).w.strb(
      input_ports_m2s(0).w.strb'range
    ) <= input_ports_m2s(input_idx).w.strb;

    input_ports_s2m(input_idx).w.ready <= input_ports_axi_s2m(input_idx).w.ready;

    input_ports_axi_m2s(input_idx).b.ready <= input_ports_m2s(input_idx).b.ready;

    input_ports_s2m(input_idx).b.valid <= input_ports_axi_s2m(input_idx).b.valid;
    input_ports_s2m(input_idx).b.resp <= input_ports_axi_s2m(input_idx).b.resp;
  end generate;

  output_m2s.aw.valid <= output_axi_m2s.aw.valid;
  output_m2s.aw.addr <= output_axi_m2s.aw.addr;

  output_axi_s2m.aw.ready <= output_s2m.aw.ready;

  output_m2s.w.valid <= output_axi_m2s.w.valid;
  output_m2s.w.data <= output_axi_m2s.w.data(output_m2s.w.data'range);
  output_m2s.w.strb <= output_axi_m2s.w.strb(output_m2s.w.strb'range);

  output_axi_s2m.w.ready <= output_s2m.w.ready;

  output_m2s.b.ready <= output_axi_m2s.b.ready;

  output_axi_s2m.b.valid <= output_s2m.b.valid;
  output_axi_s2m.b.resp <= output_s2m.b.resp;


  ------------------------------------------------------------------------------
  axi_simple_write_crossbar_inst : entity axi.axi_simple_write_crossbar
    generic map (
      num_inputs => num_inputs
    )
    port map (
      clk => clk,
      --
      input_ports_m2s => input_ports_axi_m2s,
      input_ports_s2m => input_ports_axi_s2m,
      --
      output_m2s => output_axi_m2s,
      output_s2m => output_axi_s2m
    );

end architecture;
