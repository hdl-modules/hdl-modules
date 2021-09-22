-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the tsfpga project.
-- https://tsfpga.com
-- https://gitlab.com/tsfpga/tsfpga
-- -------------------------------------------------------------------------------------------------
-- Convenience wrapper for splitting and CDC'ing a register bus.
-- -------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

library common;
use common.addr_pkg.all;

library axi;
use axi.axi_pkg.all;
use axi.axi_lite_pkg.all;


entity axi_to_axi_lite_vec is
  generic (
    axi_lite_slaves : addr_and_mask_vec_t;
    clocks_are_the_same : boolean_vector(axi_lite_slaves'range) := (others => true);
    pipeline : boolean := false;
    -- Only needed if pipeline is enabled
    data_width : positive := 32
  );
  port (
    clk_axi : in std_logic;
    axi_m2s : in axi_m2s_t;
    axi_s2m : out axi_s2m_t;

    -- Only need to set if different from axi_clk
    clk_axi_lite_vec : in std_logic_vector(axi_lite_slaves'range) := (others => '0');
    axi_lite_m2s_vec : out axi_lite_m2s_vec_t(axi_lite_slaves'range);
    axi_lite_s2m_vec : in axi_lite_s2m_vec_t(axi_lite_slaves'range)
  );
end entity;

architecture a of axi_to_axi_lite_vec is

  signal axi_lite_m2s, axi_lite_pipelined_m2s : axi_lite_m2s_t := axi_lite_m2s_init;
  signal axi_lite_s2m, axi_lite_pipelined_s2m : axi_lite_s2m_t := axi_lite_s2m_init;

  constant addr_width : positive := addr_bits_needed(axi_lite_slaves);

begin

  ------------------------------------------------------------------------------
  axi_to_axi_lite_inst : entity work.axi_to_axi_lite
    generic map (
      data_width => 32
    )
    port map (
      clk => clk_axi,

      axi_m2s => axi_m2s,
      axi_s2m => axi_s2m,

      axi_lite_m2s => axi_lite_m2s,
      axi_lite_s2m => axi_lite_s2m
    );


  ------------------------------------------------------------------------------
  pipeline_gen : if pipeline generate
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
      axi_lite_slaves => axi_lite_slaves,
      clocks_are_the_same => clocks_are_the_same
    )
    port map (
      clk_axi_lite => clk_axi,
      axi_lite_m2s => axi_lite_pipelined_m2s,
      axi_lite_s2m => axi_lite_pipelined_s2m,

      clk_axi_lite_vec => clk_axi_lite_vec,
      axi_lite_m2s_vec => axi_lite_m2s_vec,
      axi_lite_s2m_vec => axi_lite_s2m_vec
    );

end architecture;
