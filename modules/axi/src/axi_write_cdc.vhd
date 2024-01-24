-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the hdl-modules project, a collection of reusable, high-quality,
-- peer-reviewed VHDL building blocks.
-- https://hdl-modules.com
-- https://github.com/hdl-modules/hdl-modules
-- -------------------------------------------------------------------------------------------------
-- Clock domain crossing of a full AXI write bus using asynchronous FIFOs for the ``AW``, ``W``
-- and ``B`` channels.
-- By setting the width generics, the bus is packed
-- optimally so that no unnecessary resources are consumed.
--
-- .. note::
--   The constraints of :ref:`fifo.asynchronous_fifo` must be used.
-- -------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

library common;
use common.attribute_pkg.all;

library fifo;

use work.axi_pkg.all;


entity axi_write_cdc is
  generic (
    id_width : natural range 0 to axi_id_sz;
    addr_width : positive range 1 to axi_a_addr_sz;
    data_width : positive range 8 to axi_data_sz;
    enable_data_fifo_packet_mode : boolean;
    address_fifo_depth : positive;
    address_fifo_ram_type : ram_style_t := ram_style_auto;
    data_fifo_depth : positive;
    data_fifo_ram_type : ram_style_t := ram_style_auto;
    response_fifo_depth : positive;
    response_fifo_ram_type : ram_style_t := ram_style_auto
  );
  port (
    clk_input : in std_ulogic;
    input_m2s : in axi_write_m2s_t;
    input_s2m : out axi_write_s2m_t := axi_write_s2m_init;
    --# {{}}
    clk_output : in std_ulogic;
    output_m2s : out axi_write_m2s_t := axi_write_m2s_init;
    output_s2m : in axi_write_s2m_t
  );
end entity;

architecture a of axi_write_cdc is

begin

  ------------------------------------------------------------------------------
  axi_address_fifo_inst : entity work.axi_address_fifo
    generic map (
      id_width => id_width,
      addr_width => addr_width,
      asynchronous => true,
      depth => address_fifo_depth,
      ram_type => address_fifo_ram_type
    )
    port map (
      clk => clk_output,
      --
      input_m2s => input_m2s.aw,
      input_s2m => input_s2m.aw,
      --
      output_m2s => output_m2s.aw,
      output_s2m => output_s2m.aw,
      --
      clk_input => clk_input
    );


  ------------------------------------------------------------------------------
  axi_w_fifo_inst : entity work.axi_w_fifo
    generic map (
      data_width => data_width,
      asynchronous => true,
      enable_packet_mode => enable_data_fifo_packet_mode,
      depth => data_fifo_depth,
      ram_type => data_fifo_ram_type
    )
    port map (
      clk => clk_output,
      --
      input_m2s => input_m2s.w,
      input_s2m => input_s2m.w,
      --
      output_m2s => output_m2s.w,
      output_s2m => output_s2m.w,
      --
      clk_input => clk_input
    );


  ------------------------------------------------------------------------------
  axi_b_fifo_inst : entity work.axi_b_fifo
    generic map (
      id_width => id_width,
      asynchronous => true,
      depth => response_fifo_depth,
      ram_type => response_fifo_ram_type
    )
    port map (
      clk => clk_output,
      --
      input_m2s => input_m2s.b,
      input_s2m => input_s2m.b,
      --
      output_m2s => output_m2s.b,
      output_s2m => output_s2m.b,
      --
      clk_input => clk_input
    );

end architecture;
