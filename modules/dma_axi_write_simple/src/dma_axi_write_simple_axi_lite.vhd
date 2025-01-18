-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the hdl-modules project, a collection of reusable, high-quality,
-- peer-reviewed VHDL building blocks.
-- https://hdl-modules.com
-- https://github.com/hdl-modules/hdl-modules
-- -------------------------------------------------------------------------------------------------
-- Top level for the simple DMA module, with an **AXI-Lite** register interface.
-- This top level is suitable for instantiation in a user design.
-- It integrates :ref:`dma_axi_write_simple.dma_axi_write_simple` and an AXI-Lite
-- register file.
--
-- See :ref:`dma_axi_write_simple.dma_axi_write_simple` for more documentation.
-- -------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

library axi;
use axi.axi_pkg.all;

library axi_lite;
use axi_lite.axi_lite_pkg.all;

use work.dma_axi_write_simple_register_record_pkg.all;


entity dma_axi_write_simple_axi_lite is
  generic (
    -- See 'dma_axi_write_simple_core.vhd' for documentation of the generics.
    address_width : axi_address_width_t;
    stream_data_width : axi_data_width_t;
    axi_data_width : axi_data_width_t;
    packet_length_beats : positive;
    enable_axi3 : boolean := false
  );
  port (
    clk : in std_ulogic;
    --# {{}}
    stream_ready : out std_ulogic := '0';
    stream_valid : in std_ulogic;
    stream_data : in std_ulogic_vector(stream_data_width - 1 downto 0);
    --# {{}}
    regs_m2s : in axi_lite_m2s_t;
    regs_s2m : out axi_lite_s2m_t := axi_lite_s2m_init;
    interrupt : out std_ulogic := '0';
    --# {{}}
    axi_write_m2s : out axi_write_m2s_t := axi_write_m2s_init;
    axi_write_s2m : in axi_write_s2m_t
  );
end entity;

architecture a of dma_axi_write_simple_axi_lite is

  signal regs_up : dma_axi_write_simple_regs_up_t := dma_axi_write_simple_regs_up_init;
  signal regs_down : dma_axi_write_simple_regs_down_t := dma_axi_write_simple_regs_down_init;

begin

  ------------------------------------------------------------------------------
  dma_axi_write_simple_core_inst : entity work.dma_axi_write_simple
    generic map (
      address_width => address_width,
      stream_data_width => stream_data_width,
      axi_data_width => axi_data_width,
      packet_length_beats => packet_length_beats,
      enable_axi3 => enable_axi3
    )
    port map (
      clk => clk,
      --
      stream_ready => stream_ready,
      stream_valid => stream_valid,
      stream_data => stream_data,
      --
      regs_up => regs_up,
      regs_down => regs_down,
      interrupt => interrupt,
      --
      axi_write_m2s => axi_write_m2s,
      axi_write_s2m => axi_write_s2m
    );


  ------------------------------------------------------------------------------
  dma_axi_write_simple_register_file_axi_lite_inst :
    entity work.dma_axi_write_simple_register_file_axi_lite
    port map (
      clk => clk,
      --
      axi_lite_m2s => regs_m2s,
      axi_lite_s2m => regs_s2m,
      --
      regs_up => regs_up,
      regs_down => regs_down
    );

end architecture;
