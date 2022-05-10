-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the hdl_modules project.
-- https://hdl-modules.com
-- https://gitlab.com/tsfpga/hdl_modules
-- -------------------------------------------------------------------------------------------------
-- Convenience wrapper for splitting and CDC'ing a register bus based on generics.
-- The goal is to split a register bus, and have each resulting AXI-Lite bus in the same clock
-- domain as the module that uses the registers. Typically used in chip top levels.
--
-- Instantiates :ref:`axi.axi_lite_mux` and :ref:`axi.axi_lite_cdc`.
-- -------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

library axi;
use axi.axi_lite_pkg.all;

library common;
use common.addr_pkg.all;
use common.attribute_pkg.all;

library reg_file;
use reg_file.reg_file_pkg.all;


entity axi_lite_to_vec is
  generic (
    axi_lite_slaves : addr_and_mask_vec_t;
    -- Set to false in order to insert a CDC for this slave.
    -- Must also set clk_axi_lite_vec.
    clocks_are_the_same : boolean_vector(axi_lite_slaves'range) := (others => true);
    cdc_fifo_depth : positive := 16;
    cdc_ram_type : ram_style_t := ram_style_auto;
    -- Optionally insert a pipeline stage after the axi_lite_mux for each slave
    pipeline_slaves : boolean := false
  );
  port (
    --# {{}}
    clk_axi_lite : in std_logic;
    axi_lite_m2s : in axi_lite_m2s_t;
    axi_lite_s2m : out axi_lite_s2m_t;
    --# {{}}
    -- Only need to set if different from clk_axi_lite
    clk_axi_lite_vec : in std_logic_vector(axi_lite_slaves'range) := (others => '0');
    axi_lite_m2s_vec : out axi_lite_m2s_vec_t(axi_lite_slaves'range);
    axi_lite_s2m_vec : in axi_lite_s2m_vec_t(axi_lite_slaves'range)
  );
end entity;

architecture a of axi_lite_to_vec is

  constant addr_width : positive := addr_bits_needed(axi_lite_slaves);
  constant data_width : positive := reg_width;

  signal axi_lite_m2s_vec_int : axi_lite_m2s_vec_t(axi_lite_slaves'range);
  signal axi_lite_s2m_vec_int : axi_lite_s2m_vec_t(axi_lite_slaves'range);

begin

  ------------------------------------------------------------------------------
  axi_lite_mux_inst : entity axi.axi_lite_mux
    generic map (
      slave_addrs => axi_lite_slaves
    )
    port map (
      clk => clk_axi_lite,

      axi_lite_m2s => axi_lite_m2s,
      axi_lite_s2m => axi_lite_s2m,

      axi_lite_m2s_vec => axi_lite_m2s_vec_int,
      axi_lite_s2m_vec => axi_lite_s2m_vec_int
    );


  ------------------------------------------------------------------------------
  output_buffering : for slave in axi_lite_slaves'range generate

    ------------------------------------------------------------------------------
    same_or_different_clock : if clocks_are_the_same(slave) generate

      ------------------------------------------------------------------------------
      pipeline_or_passthrough : if pipeline_slaves generate

        ------------------------------------------------------------------------------
        axi_lite_pipeline_inst : entity axi.axi_lite_pipeline
          generic map (
            data_width => data_width,
            addr_width => addr_width,
            -- We do not need full throughput on the register bus. There are never
            -- back-to-back transactions.
            full_throughput => false,
            pipeline_control_signals => true
          )
          port map (
            clk => clk_axi_lite,
            --
            master_m2s => axi_lite_m2s_vec_int(slave),
            master_s2m => axi_lite_s2m_vec_int(slave),
            --
            slave_m2s => axi_lite_m2s_vec(slave),
            slave_s2m => axi_lite_s2m_vec(slave)
          );

      ------------------------------------------------------------------------------
      else generate

        axi_lite_m2s_vec(slave) <= axi_lite_m2s_vec_int(slave);
        axi_lite_s2m_vec_int(slave) <= axi_lite_s2m_vec(slave);

      end generate;


    ------------------------------------------------------------------------------
    else generate

      ------------------------------------------------------------------------------
      axi_lite_cdc_inst : entity axi.axi_lite_cdc
        generic map (
          data_width => data_width,
          addr_width => addr_width,
          fifo_depth => cdc_fifo_depth,
          ram_type => cdc_ram_type
        )
        port map (
          clk_master => clk_axi_lite,
          master_m2s => axi_lite_m2s_vec_int(slave),
          master_s2m => axi_lite_s2m_vec_int(slave),
          --
          clk_slave => clk_axi_lite_vec(slave),
          slave_m2s => axi_lite_m2s_vec(slave),
          slave_s2m => axi_lite_s2m_vec(slave)
        );

      -- If the AXI master and the AXI-Lite slaves are in different clock domains we do not insert
      -- a pipeline stage even if pipeline_slaves is true.
      -- The buffering of the CDC is deemed enough to ease timing.

    end generate;

  end generate;

end architecture;
