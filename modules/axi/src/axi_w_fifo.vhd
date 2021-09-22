-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the tsfpga project.
-- https://tsfpga.com
-- https://gitlab.com/tsfpga/tsfpga
-- -------------------------------------------------------------------------------------------------
-- FIFO for AXI write data channel (W). Can be used as clock crossing by setting
-- the "asynchronous" generic.
-- -------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

library common;
use common.attribute_pkg.all;

library fifo;

use work.axi_pkg.all;


entity axi_w_fifo is
  generic (
    asynchronous : boolean;
    data_width : positive;
    depth : natural;
    enable_packet_mode : boolean := false;
    ram_type : ram_style_t := ram_style_auto
  );
  port (
    clk : in std_logic;
    --
    input_m2s : in axi_m2s_w_t;
    input_s2m : out axi_s2m_w_t := axi_s2m_w_init;
    --
    output_m2s : out axi_m2s_w_t := axi_m2s_w_init;
    output_s2m : in axi_s2m_w_t;
    -- Level of the FIFO. If this is an asynchronous FIFO, this value is on the "output" side.
    output_level : out integer range 0 to depth := 0;

    -- Only needs to assign the clock if generic asynchronous is "True"
    clk_input : in std_logic := '0'
  );
end entity;

architecture a of axi_w_fifo is

begin

  passthrough_or_fifo : if depth = 0 generate
    output_m2s <= input_m2s;
    input_s2m <= output_s2m;

  else generate

    constant w_width : integer := axi_m2s_w_sz(data_width);

    signal read_valid : std_logic := '0';
    signal read_data, write_data : std_logic_vector(w_width - 1 downto 0);

  begin

    ------------------------------------------------------------------------------
    assign : process(all)
    begin
      output_m2s <= to_axi_m2s_w(read_data, data_width);
      output_m2s.valid <= read_valid;

      write_data <= to_slv(input_m2s, data_width);
    end process;


    ------------------------------------------------------------------------------
    fifo_wrapper_inst : entity fifo.fifo_wrapper
      generic map (
        use_asynchronous_fifo => asynchronous,
        width => w_width,
        depth => depth,
        enable_last => enable_packet_mode,
        enable_packet_mode => enable_packet_mode,
        ram_type => ram_type
      )
      port map(
        clk => clk,
        clk_read => clk,
        clk_write => clk_input,
        --
        read_ready => output_s2m.ready,
        read_valid => read_valid,
        read_data => read_data,
        read_level => output_level,
        --
        write_ready => input_s2m.ready,
        write_valid => input_m2s.valid,
        write_data => write_data,
        write_last => input_m2s.last
      );

  end generate;

end architecture;
