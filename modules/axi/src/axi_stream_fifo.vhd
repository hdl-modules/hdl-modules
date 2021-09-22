-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the tsfpga project.
-- https://tsfpga.com
-- https://gitlab.com/tsfpga/tsfpga
-- -------------------------------------------------------------------------------------------------
-- FIFO for AXI Stream. Can be used as clock crossing by setting the "asynchronous" generic.
-- -------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

library fifo;

library common;
use common.attribute_pkg.all;

use work.axi_stream_pkg.all;


entity axi_stream_fifo is
  generic (
    data_width : positive;
    user_width : natural;
    asynchronous : boolean;
    depth : positive;
    ram_type : ram_style_t := ram_style_auto
  );
  port (
    clk : in std_logic;
    --
    input_m2s : in axi_stream_m2s_t;
    input_s2m : out axi_stream_s2m_t := axi_stream_s2m_init;
    --
    output_m2s : out axi_stream_m2s_t := axi_stream_m2s_init;
    output_s2m : in axi_stream_s2m_t;
    -- Only need to assign the clock if generic asynchronous is "True"
    clk_output : in std_logic := '0'
  );
end entity;

architecture a of axi_stream_fifo is

  constant bus_width : integer := axi_stream_m2s_sz(data_width, user_width);

  signal write_data, read_data : std_logic_vector(bus_width - 1 downto 0);
  signal read_valid : std_logic := '0';

begin

  write_data <= to_slv(input_m2s, data_width, user_width);

  output_m2s <= to_axi_stream_m2s(
    data=>read_data,
    data_width=>data_width,
    user_width=>user_width,
    valid=>read_valid
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
