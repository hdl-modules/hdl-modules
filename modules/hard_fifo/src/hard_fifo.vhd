-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the hdl_modules project.
-- https://hdl-modules.com
-- https://gitlab.com/tsfpga/hdl_modules
-- -------------------------------------------------------------------------------------------------
-- Synchronous (one clock) First In First Out (FIFO) data buffering stage with AXI-Stream-like
-- handshaking interface. This is a wrapper around the Xilinx hard FIFO primitive, and can only
-- be used in certain devices.
-- -------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.hard_fifo_pkg.all;


entity hard_fifo is
  generic (
    data_width : positive;
    enable_output_register : boolean;
    primitive_type : fifo_primitive_t
  );
  port (
    clk : in std_logic;
    --# {{}}
    read_ready : in std_logic;
    read_valid : out std_logic := '0';
    read_data : out std_logic_vector(data_width - 1 downto 0) := (others => '0');
    --# {{}}
    write_ready : out std_logic := '0';
    write_valid : in std_logic;
    write_data : in std_logic_vector(data_width - 1 downto 0)
  );
end entity;

architecture a of hard_fifo is

begin

  ------------------------------------------------------------------------------
  select_primitive : if primitive_type = primitive_fifo36e2 generate

    ------------------------------------------------------------------------------
    fifo36e2_wrapper_inst : entity work.fifo36e2_wrapper
      generic map (
        data_width => data_width,
        is_asynchronous => false,
        enable_output_register => enable_output_register
      )
      port map (
        clk_read => clk,
        --
        read_ready => read_ready,
        read_valid => read_valid,
        read_data => read_data,
        --
        clk_write => clk,
        --
        write_ready => write_ready,
        write_valid => write_valid,
        write_data => write_data
      );


  ------------------------------------------------------------------------------
  else generate

    assert false report "Unknown primitive type" severity failure;

  end generate;

end architecture;
