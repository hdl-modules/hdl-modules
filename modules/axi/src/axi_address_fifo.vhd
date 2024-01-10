-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the hdl-modules project, a collection of reusable, high-quality,
-- peer-reviewed VHDL building blocks.
-- https://hdl-modules.com
-- https://github.com/hdl-modules/hdl-modules
-- -------------------------------------------------------------------------------------------------
-- FIFO for AXI address channel (``AR`` or ``AW``). Can be used as clock crossing by setting
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


entity axi_address_fifo is
  generic (
    id_width : natural range 0 to axi_id_sz;
    addr_width : positive range 1 to axi_a_addr_sz;
    asynchronous : boolean;
    depth : natural := 16;
    ram_type : ram_style_t := ram_style_auto
  );
  port (
    clk : in std_ulogic;
    -- Only need to assign the clock if generic asynchronous is "True"
    clk_input : in std_ulogic := '0';
    --# {{}}
    input_m2s : in axi_m2s_a_t;
    input_s2m : out axi_s2m_a_t := axi_s2m_a_init;
    --# {{}}
    output_m2s : out axi_m2s_a_t := axi_m2s_a_init;
    output_s2m : in axi_s2m_a_t
  );
end entity;

architecture a of axi_address_fifo is

begin

  ------------------------------------------------------------------------------
  passthrough_or_fifo : if depth = 0 generate

    output_m2s <= input_m2s;
    input_s2m <= output_s2m;

  ------------------------------------------------------------------------------
  else generate

    constant ar_width : positive := axi_m2s_a_sz(id_width=>id_width, addr_width=>addr_width);

    signal read_valid : std_ulogic := '0';
    signal read_data, write_data : std_ulogic_vector(ar_width - 1 downto 0);

  begin

    ------------------------------------------------------------------------------
    assign : process(all)
    begin
      write_data <= to_slv(input_m2s, id_width, addr_width);

      output_m2s <= to_axi_m2s_a(read_data, id_width, addr_width);
      output_m2s.valid <= read_valid;
    end process;


    ------------------------------------------------------------------------------
    fifo_wrapper_inst : entity fifo.fifo_wrapper
      generic map (
        use_asynchronous_fifo => asynchronous,
        width => ar_width,
        depth => depth,
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
        --
        write_ready => input_s2m.ready,
        write_valid => input_m2s.valid,
        write_data => write_data
      );

  end generate;

end architecture;
