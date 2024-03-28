-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the hdl-modules project, a collection of reusable, high-quality,
-- peer-reviewed VHDL building blocks.
-- https://hdl-modules.com
-- https://github.com/hdl-modules/hdl-modules
-- -------------------------------------------------------------------------------------------------
-- Wrapper around VUnit ``axi_read_slave`` and ``axi_write_slave`` verification components.
-- Uses convenient record types for the AXI-Lite signals.
--
-- The instantiated verification components will process the incoming AXI-Lite operations and
-- apply them to the :ref:`VUnit memory model <vunit:memory_model>`.
--
-- This entity instantiates :ref:`bfm.axi_lite_read_slave` and/or :ref:`bfm.axi_lite_write_slave`
-- based on what generics are provided.
-- See those BFMs for more details.
-- -------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

library vunit_lib;
use vunit_lib.axi_slave_pkg.all;

library axi_lite;
use axi_lite.axi_lite_pkg.all;

use work.axi_slave_bfm_pkg.all;


entity axi_lite_slave is
  generic (
    axi_read_slave : axi_slave_t := axi_slave_init;
    axi_write_slave : axi_slave_t := axi_slave_init;
    data_width : positive range 1 to axi_lite_data_sz;
    -- Suffix for error log messages. Can be used to differentiate between multiple instances.
    logger_name_suffix : string := ""
  );
  port (
    clk : in std_ulogic;
    --# {{}}
    axi_lite_read_m2s : in axi_lite_read_m2s_t := axi_lite_read_m2s_init;
    axi_lite_read_s2m : out axi_lite_read_s2m_t := axi_lite_read_s2m_init;
    --# {{}}
    axi_lite_write_m2s : in axi_lite_write_m2s_t := axi_lite_write_m2s_init;
    axi_lite_write_s2m : out axi_lite_write_s2m_t := axi_lite_write_s2m_init
  );
end entity;

architecture a of axi_lite_slave is

begin

  ------------------------------------------------------------------------------
  axi_read_slave_gen : if axi_read_slave /= axi_slave_init generate

    axi_lite_read_slave_inst : entity work.axi_lite_read_slave
      generic map (
        axi_slave => axi_read_slave,
        data_width => data_width,
        logger_name_suffix => logger_name_suffix
      )
      port map (
        clk => clk,
        --
        axi_lite_read_m2s => axi_lite_read_m2s,
        axi_lite_read_s2m => axi_lite_read_s2m
      );
  end generate;


  ------------------------------------------------------------------------------
  axi_write_slave_gen : if axi_write_slave /= axi_slave_init generate

    axi_lite_write_slave_inst : entity work.axi_lite_write_slave
      generic map (
        axi_slave => axi_write_slave,
        data_width => data_width,
        logger_name_suffix => logger_name_suffix
      )
      port map (
        clk => clk,
        --
        axi_lite_write_m2s => axi_lite_write_m2s,
        axi_lite_write_s2m => axi_lite_write_s2m
      );

  end generate;

end architecture;
