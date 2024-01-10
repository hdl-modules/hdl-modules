-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the hdl-modules project, a collection of reusable, high-quality,
-- peer-reviewed VHDL building blocks.
-- https://hdl-modules.com
-- https://github.com/hdl-modules/hdl-modules
-- -------------------------------------------------------------------------------------------------
-- FIFO for AXI write response channel (``B``). Can be used as clock crossing by setting
-- the ``asynchronous`` generic. By setting the ``id_width`` generic, the bus is packed
-- optimally so that no unnecessary resources are consumed.
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

use work.axi_pkg.all;


entity axi_b_fifo is
  generic (
    id_width : natural range 0 to axi_id_sz;
    asynchronous : boolean;
    depth : natural := 16;
    ram_type : ram_style_t := ram_style_auto
  );
  port (
    clk : in std_ulogic;
    -- Only need to assign the clock if generic asynchronous is "True"
    clk_input : in std_ulogic := '0';
    --# {{}}
    input_m2s : in axi_m2s_b_t;
    input_s2m : out axi_s2m_b_t := axi_s2m_b_init;
    --# {{}}
    output_m2s : out axi_m2s_b_t := axi_m2s_b_init;
    output_s2m : in axi_s2m_b_t
  );
end entity;

architecture a of axi_b_fifo is

begin

  ------------------------------------------------------------------------------
  passthrough_or_fifo : if depth = 0 generate

    output_m2s <= input_m2s;
    input_s2m <= output_s2m;

  ------------------------------------------------------------------------------
  else generate

    constant b_width : positive := axi_s2m_b_sz(id_width=>id_width);

    signal write_data, read_data : std_ulogic_vector(b_width - 1 downto 0);
    signal read_valid : std_ulogic := '0';

  begin

    ------------------------------------------------------------------------------
    assign : process(all)
    begin
      input_s2m <= to_axi_s2m_b(read_data, id_width);
      input_s2m.valid <= read_valid;

      write_data <= to_slv(output_s2m, id_width);
    end process;


    ------------------------------------------------------------------------------
    fifo_wrapper_inst : entity fifo.fifo_wrapper
      generic map (
        use_asynchronous_fifo => asynchronous,
        width => b_width,
        depth => depth,
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
        write_data => write_data
      );

  end generate;

end architecture;
