-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the tsfpga project.
-- https://tsfpga.com
-- https://gitlab.com/tsfpga/tsfpga
-- -------------------------------------------------------------------------------------------------
-- Wrapper around VUnit BFM that uses convenient record types for the AXI signals.
-- Will instantiate read and/or write BFMs based on what generics are provided.
-- -------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
context vunit_lib.vc_context;

library axi;
use axi.axi_pkg.all;

use work.axi_slave_pkg.all;


entity axi_slave is
  generic (
    axi_read_slave : axi_slave_t := axi_slave_init;
    axi_write_slave : axi_slave_t := axi_slave_init;
    data_width : positive;
    -- Note that the VUnit BFM creates and integer_vector_ptr of length 2**id_width, so a large
    -- value for id_width might crash your simulator.
    id_width : natural := 8;
    w_fifo_depth : natural := 0
  );
  port (
    clk : in std_logic;
    --
    axi_read_m2s : in axi_read_m2s_t := axi_read_m2s_init;
    axi_read_s2m : out axi_read_s2m_t := axi_read_s2m_init;
    --
    axi_write_m2s : in axi_write_m2s_t := axi_write_m2s_init;
    axi_write_s2m : out axi_write_s2m_t := axi_write_s2m_init
  );
end entity;

architecture a of axi_slave is

begin

  ------------------------------------------------------------------------------
  axi_read_slave_gen : if axi_read_slave /= axi_slave_init generate

    axi_read_slave_inst : entity work.axi_read_slave
      generic map (
        axi_slave => axi_read_slave,
        data_width => data_width,
        id_width => id_width
      )
      port map (
        clk => clk,
        axi_read_m2s => axi_read_m2s,
        axi_read_s2m => axi_read_s2m
      );

  end generate;


  ------------------------------------------------------------------------------
  axi_write_slave_gen : if axi_write_slave /= axi_slave_init generate

    axi_write_slave_inst : entity work.axi_write_slave
      generic map (
        axi_slave => axi_write_slave,
        data_width => data_width,
        id_width => id_width,
        w_fifo_depth => w_fifo_depth
      )
      port map (
        clk => clk,
        axi_write_m2s => axi_write_m2s,
        axi_write_s2m => axi_write_s2m
      );

  end generate;

end architecture;
