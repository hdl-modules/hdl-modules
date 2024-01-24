-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the hdl-modules project, a collection of reusable, high-quality,
-- peer-reviewed VHDL building blocks.
-- https://hdl-modules.com
-- https://github.com/hdl-modules/hdl-modules
-- -------------------------------------------------------------------------------------------------
-- FIFO for AXI read response channel (R). Can be used as clock crossing by setting
-- the ``asynchronous`` generic. By setting the width generics, the bus is packed
-- optimally so that no unnecessary resources are consumed.
--
-- .. note::
--   If asynchronous operation is enabled, the constraints of :ref:`fifo.asynchronous_fifo`
--   must be used.
-- -------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

library common;
use common.attribute_pkg.all;

library fifo;

use work.axi_pkg.all;


entity axi_r_fifo is
  generic (
    asynchronous : boolean;
    id_width : natural range 0 to axi_id_sz;
    data_width : positive range 8 to axi_data_sz;
    depth : natural := 16;
    enable_packet_mode : boolean := false;
    ram_type : ram_style_t := ram_style_auto
  );
  port (
    clk : in std_ulogic;
    -- Only need to assign the clock if generic asynchronous is "True"
    clk_input : in std_ulogic := '0';
    --# {{}}
    input_m2s : in axi_m2s_r_t;
    input_s2m : out axi_s2m_r_t := axi_s2m_r_init;
    --# {{}}
    output_m2s : out axi_m2s_r_t := axi_m2s_r_init;
    output_s2m : in axi_s2m_r_t;
    -- Level of the FIFO. If this is an asynchronous FIFO, this value is on the "output" side.
    output_level : out integer range 0 to depth := 0
  );
end entity;

architecture a of axi_r_fifo is

begin

  ------------------------------------------------------------------------------
  passthrough_or_fifo : if depth = 0 generate

    output_m2s <= input_m2s;
    input_s2m <= output_s2m;

  ------------------------------------------------------------------------------
  else generate

    constant r_width : positive := axi_s2m_r_sz(data_width=>data_width, id_width=>id_width);

    signal read_valid : std_ulogic := '0';
    signal read_data, write_data : std_ulogic_vector(r_width - 1 downto 0);

  begin

    ------------------------------------------------------------------------------
    assign : process(all)
    begin
      input_s2m <= to_axi_s2m_r(data=>read_data, data_width=>data_width, id_width=>id_width);
      input_s2m.valid <= read_valid;

      write_data <= to_slv(data=>output_s2m, data_width=>data_width, id_width=>id_width);
    end process;


    ------------------------------------------------------------------------------
    fifo_wrapper_inst : entity fifo.fifo_wrapper
      generic map (
        use_asynchronous_fifo => asynchronous,
        width => write_data'length,
        depth => depth,
        enable_last => enable_packet_mode,
        enable_packet_mode => enable_packet_mode,
        ram_type => ram_type
      )
      port map(
        clk => clk,
        clk_read => clk_input,
        clk_write => clk,
        --
        read_ready => input_m2s.ready,
        read_valid => read_valid,
        read_data => read_data,
        --
        write_ready => output_m2s.ready,
        write_valid => output_s2m.valid,
        write_data => write_data,
        --
        write_level => output_level
      );

  end generate;

end architecture;
