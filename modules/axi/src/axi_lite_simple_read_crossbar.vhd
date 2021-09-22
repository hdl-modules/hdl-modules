-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the tsfpga project.
-- https://tsfpga.com
-- https://gitlab.com/tsfpga/tsfpga
-- -------------------------------------------------------------------------------------------------
-- Simple N-to-1 crossbar for connecting multiple AXI-Lite masters to one port.
-- This is a wrapper around the simple AXI read crossbar. See that entity for details.
-- -------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

library axi;
use axi.axi_pkg.all;
use axi.axi_lite_pkg.all;


entity axi_lite_simple_read_crossbar is
  generic(
    num_inputs : integer
  );
  port(
    clk : in std_logic;
    --
    input_ports_m2s : in axi_lite_read_m2s_vec_t(0 to num_inputs - 1) :=
      (others => axi_lite_read_m2s_init);
    input_ports_s2m : out axi_lite_read_s2m_vec_t(0 to num_inputs - 1) :=
      (others => axi_lite_read_s2m_init);
    --
    output_m2s : out axi_lite_read_m2s_t := axi_lite_read_m2s_init;
    output_s2m : in axi_lite_read_s2m_t := axi_lite_read_s2m_init
  );
end entity;

architecture a of axi_lite_simple_read_crossbar is

  signal input_ports_axi_m2s : axi_read_m2s_vec_t(0 to num_inputs - 1) :=
    (others => axi_read_m2s_init);
  signal input_ports_axi_s2m : axi_read_s2m_vec_t(0 to num_inputs - 1) :=
    (others => axi_read_s2m_init);

  signal output_axi_m2s : axi_read_m2s_t := axi_read_m2s_init;
  signal output_axi_s2m : axi_read_s2m_t := axi_read_s2m_init;

begin

  -- Assign to the AXI records only what is needed for the AXI-Lite function.

  ------------------------------------------------------------------------------
  input_ports_loop : for input_idx in input_ports_m2s'range generate
    input_ports_axi_m2s(input_idx).ar.valid <= input_ports_m2s(input_idx).ar.valid;
    input_ports_axi_m2s(input_idx).ar.addr <= input_ports_m2s(input_idx).ar.addr;

    input_ports_s2m(input_idx).ar.ready <= input_ports_axi_s2m(input_idx).ar.ready;

    input_ports_axi_m2s(input_idx).r.ready <= input_ports_m2s(input_idx).r.ready;

    input_ports_s2m(input_idx).r.valid <= input_ports_axi_s2m(input_idx).r.valid;
    input_ports_s2m(input_idx).r.data <=
      input_ports_axi_s2m(input_idx).r.data(input_ports_s2m(input_idx).r.data'range);
    input_ports_s2m(input_idx).r.resp <=
      input_ports_axi_s2m(input_idx).r.resp(input_ports_s2m(input_idx).r.resp'range);
  end generate;

  output_m2s.ar.valid <= output_axi_m2s.ar.valid;
  output_m2s.ar.addr <= output_axi_m2s.ar.addr;

  output_axi_s2m.ar.ready <= output_s2m.ar.ready;

  output_m2s.r.ready <= output_axi_m2s.r.ready;

  output_axi_s2m.r.valid <= output_s2m.r.valid;
  output_axi_s2m.r.data(output_s2m.r.data'range) <= output_s2m.r.data;
  output_axi_s2m.r.resp(output_s2m.r.resp'range) <= output_s2m.r.resp;
  -- AXI-Lite always burst length 1. Need to set last for the logic in axi_interconnect.
  output_axi_s2m.r.last <= '1';


  ------------------------------------------------------------------------------
  axi_simple_read_crossbar_inst : entity work.axi_simple_read_crossbar
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
