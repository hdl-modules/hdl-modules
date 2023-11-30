-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the hdl-modules project, a collection of reusable, high-quality,
-- peer-reviewed VHDL building blocks.
-- https://hdl-modules.com
-- https://github.com/hdl-modules/hdl-modules
-- -------------------------------------------------------------------------------------------------
-- Asynchronous (two clocks) First In First Out (FIFO) data buffering stage with AXI-Stream-like
-- handshaking interface. This is a wrapper around the Xilinx hard FIFO primitive, and can only
-- be used in certain devices.
-- -------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.hard_fifo_pkg.all;


entity asynchronous_hard_fifo is
  generic (
    data_width : positive;
    enable_output_register : boolean;
    primitive_type : fifo_primitive_t := primitive_fifo36e2
  );
  port (
    clk_read : in std_ulogic;
    read_ready : in std_ulogic;
    read_valid : out std_ulogic := '0';
    read_data : out std_ulogic_vector(data_width - 1 downto 0) := (others => '0');
    --# {{}}
    clk_write : in std_ulogic;
    write_ready : out std_ulogic := '0';
    write_valid : in std_ulogic;
    write_data : in std_ulogic_vector(data_width - 1 downto 0)
  );
end entity;

architecture a of asynchronous_hard_fifo is

begin

  ------------------------------------------------------------------------------
  select_primitive : if primitive_type = primitive_fifo36e2 generate

    ------------------------------------------------------------------------------
    fifo36e2_wrapper_inst : entity work.fifo36e2_wrapper
      generic map (
        data_width => data_width,
        is_asynchronous => true,
        enable_output_register => enable_output_register
      )
      port map (
        clk_read => clk_read,
        read_ready => read_ready,
        read_valid => read_valid,
        read_data => read_data,
        --
        clk_write => clk_write,
        write_ready => write_ready,
        write_valid => write_valid,
        write_data => write_data
      );


    ------------------------------------------------------------------------------
    else generate

      assert false report "Unknown primitive type" severity failure;

    end generate;

end architecture;
