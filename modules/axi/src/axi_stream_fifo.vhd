-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the hdl-modules project, a collection of reusable, high-quality,
-- peer-reviewed VHDL building blocks.
-- https://hdl-modules.com
-- https://github.com/hdl-modules/hdl-modules
-- -------------------------------------------------------------------------------------------------
-- FIFO for AXI Stream. Can be used as clock crossing by setting the ``asynchronous`` generic.
-- By setting the width generics, the bus is packed optimally so that no unnecessary resources
-- are consumed.
--
-- .. note::
--   If asynchronous operation is enabled, the constraints of :ref:`fifo.asynchronous_fifo`
--   must be used.
-- -------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

library fifo;

library common;
use common.attribute_pkg.all;

use work.axi_stream_pkg.all;


entity axi_stream_fifo is
  generic (
    data_width : positive range 1 to axi_stream_data_sz;
    user_width : natural range 0 to axi_stream_user_sz;
    asynchronous : boolean;
    depth : positive;
    ram_type : ram_style_t := ram_style_auto
  );
  port (
    clk : in std_ulogic;
    -- Only need to assign the clock if generic asynchronous is "True"
    clk_output : in std_ulogic := '0';
    --# {{}}
    input_m2s : in axi_stream_m2s_t;
    input_s2m : out axi_stream_s2m_t := axi_stream_s2m_init;
    --# {{}}
    output_m2s : out axi_stream_m2s_t := axi_stream_m2s_init;
    output_s2m : in axi_stream_s2m_t
  );
end entity;

architecture a of axi_stream_fifo is

  constant bus_width : positive := axi_stream_m2s_sz(
    data_width=>data_width, user_width=>user_width
  );

  signal write_data, read_data : std_ulogic_vector(bus_width - 1 downto 0) := (others => '0');
  signal read_valid : std_ulogic := '0';

begin

  write_data <= to_slv(data=>input_m2s, data_width=>data_width, user_width=>user_width);

  output_m2s <= to_axi_stream_m2s(
    data=>read_data, data_width=>data_width, user_width=>user_width, valid=>read_valid
  );


  ------------------------------------------------------------------------------
  fifo_wrapper_inst : entity fifo.fifo_wrapper
    generic map (
      use_asynchronous_fifo => asynchronous,
      width => bus_width,
      depth => depth,
      ram_type => ram_type
    )
    port map(
      clk => clk,
      clk_read => clk_output,
      clk_write => clk,
      --
      read_ready => output_s2m.ready,
      read_valid => read_valid,
      read_data => read_data,
      --
      write_ready => input_s2m.ready,
      write_valid => input_m2s.valid,
      write_data => write_data
    );

end architecture;
