-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the hdl-modules project, a collection of reusable, high-quality,
-- peer-reviewed VHDL building blocks.
-- https://hdl-modules.com
-- https://github.com/hdl-modules/hdl-modules
-- -------------------------------------------------------------------------------------------------
-- Convenience wrapper for converting a AXI bus to AXI-Lite, and then splitting and CDC'ing a
-- register bus.
-- The goal is to split a register bus, and have each resulting AXI-Lite bus in the same clock
-- domain as the module that uses the registers. Typically used in chip top levels.
--
-- Instantiates :ref:`axi_lite.axi_to_axi_lite`, :ref:`axi_lite.axi_lite_mux`
-- and :ref:`axi_lite.axi_lite_cdc`.
-- -------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

library axi;
use axi.axi_pkg.all;

library common;
use common.addr_pkg.all;

library reg_file;
use reg_file.reg_file_pkg.all;

use work.axi_lite_pkg.all;


entity axi_to_axi_lite_vec is
  generic (
    base_addresses : addr_vec_t;
    -- Set to false in order to insert a CDC for this slave.
    -- Must also set clk_axi_lite_vec.
    clocks_are_the_same : boolean_vector(base_addresses'range) := (others => true);
    -- Optionally insert a pipeline stage on the AXI-Lite bus after the AXI to AXI-Lite conversion
    pipeline_axi_lite : boolean := false;
    -- Optionally insert a pipeline stage after the axi_lite_mux for each slave
    pipeline_slaves : boolean := false
  );
  port (
    clk_axi : in std_ulogic;
    axi_m2s : in axi_m2s_t;
    axi_s2m : out axi_s2m_t;
    --# {{}}
    -- Only need to set if different from axi_clk
    clk_axi_lite_vec : in std_ulogic_vector(base_addresses'range) := (others => '0');
    axi_lite_m2s_vec : out axi_lite_m2s_vec_t(base_addresses'range);
    axi_lite_s2m_vec : in axi_lite_s2m_vec_t(base_addresses'range)
  );
end entity;

architecture a of axi_to_axi_lite_vec is

  -- Calculate the required address width, based on the base addresses and masks.
  constant base_addresses_and_mask : addr_and_mask_vec_t := calculate_mask(base_addresses);
  constant addr_width : positive := addr_bits_needed(base_addresses_and_mask);

  constant data_width : positive := reg_width;

  signal axi_lite_m2s, axi_lite_pipelined_m2s : axi_lite_m2s_t := axi_lite_m2s_init;
  signal axi_lite_s2m, axi_lite_pipelined_s2m : axi_lite_s2m_t := axi_lite_s2m_init;

begin

  ------------------------------------------------------------------------------
  axi_to_axi_lite_inst : entity work.axi_to_axi_lite
    generic map (
      data_width => data_width
    )
    port map (
      clk => clk_axi,
      --
      axi_m2s => axi_m2s,
      axi_s2m => axi_s2m,
      --
      axi_lite_m2s => axi_lite_m2s,
      axi_lite_s2m => axi_lite_s2m
    );


  ------------------------------------------------------------------------------
  pipeline_gen : if pipeline_axi_lite generate

    ------------------------------------------------------------------------------
    axi_lite_pipeline_inst : entity work.axi_lite_pipeline
      generic map (
        data_width => data_width,
        addr_width => addr_width
      )
      port map (
        clk => clk_axi,
        --
        master_m2s => axi_lite_m2s,
        master_s2m => axi_lite_s2m,
        --
        slave_m2s => axi_lite_pipelined_m2s,
        slave_s2m => axi_lite_pipelined_s2m
      );

  else generate

    axi_lite_pipelined_m2s <= axi_lite_m2s;
    axi_lite_s2m <= axi_lite_pipelined_s2m;

  end generate;


  ------------------------------------------------------------------------------
  axi_lite_to_vec_inst : entity work.axi_lite_to_vec
    generic map (
      base_addresses => base_addresses,
      clocks_are_the_same => clocks_are_the_same,
      pipeline_slaves => pipeline_slaves
    )
    port map (
      clk_axi_lite => clk_axi,
      axi_lite_m2s => axi_lite_pipelined_m2s,
      axi_lite_s2m => axi_lite_pipelined_s2m,
      --
      clk_axi_lite_vec => clk_axi_lite_vec,
      axi_lite_m2s_vec => axi_lite_m2s_vec,
      axi_lite_s2m_vec => axi_lite_s2m_vec
    );

end architecture;
