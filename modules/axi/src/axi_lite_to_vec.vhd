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
    clocks_are_the_same : boolean_vector(axi_lite_slaves'range) := (others => true);
    cdc_fifo_depth : positive := 16;
    cdc_ram_type : ram_style_t := ram_style_auto
  );
  port (
    clk_axi_lite : in std_logic;
    axi_lite_m2s : in axi_lite_m2s_t;
    axi_lite_s2m : out axi_lite_s2m_t;

    -- Only need to set if different from clk_axi_lite
    clk_axi_lite_vec : in std_logic_vector(axi_lite_slaves'range) := (others => '0');
    axi_lite_m2s_vec : out axi_lite_m2s_vec_t(axi_lite_slaves'range);
    axi_lite_s2m_vec : in axi_lite_s2m_vec_t(axi_lite_slaves'range)
  );
end entity;

architecture a of axi_lite_to_vec is

  constant addr_width : positive := addr_bits_needed(axi_lite_slaves);

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
    clock_domain_crossing : for slave in axi_lite_slaves'range generate
      assign : if clocks_are_the_same(slave) generate
        axi_lite_m2s_vec(slave) <= axi_lite_m2s_vec_int(slave);
        axi_lite_s2m_vec_int(slave) <= axi_lite_s2m_vec(slave);

      else generate
        axi_lite_cdc_inst : entity axi.axi_lite_cdc
          generic map (
            data_width => reg_width,
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
      end generate;
    end generate;

end architecture;
