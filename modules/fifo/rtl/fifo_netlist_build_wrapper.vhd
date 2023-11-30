-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the hdl-modules project, a collection of reusable, high-quality,
-- peer-reviewed VHDL building blocks.
-- https://hdl-modules.com
-- https://github.com/hdl-modules/hdl-modules
-- -------------------------------------------------------------------------------------------------
-- A wrapper of the FIFO with only the "barebone" ports routed. To be used
-- for size assertions in netlist builds.
-- -------------------------------------------------------------------------------------------------

library ieee;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;


entity fifo_netlist_build_wrapper is
  generic (
    use_asynchronous_fifo : boolean;
    width : positive;
    depth : positive;
    enable_output_register : boolean
  );
  port (
    clk : in std_ulogic;
    clk_read : in std_ulogic;
    clk_write : in std_ulogic;
    --# {{}}
    read_ready : in std_ulogic;
    read_valid : out std_ulogic := '0';
    read_data : out std_ulogic_vector(width - 1 downto 0) := (others => '0');
    --# {{}}
    write_ready : out std_ulogic := '0';
    write_valid : in std_ulogic;
    write_data : in std_ulogic_vector(width - 1 downto 0)
  );
end entity;

architecture a of fifo_netlist_build_wrapper is

begin

  ------------------------------------------------------------------------------
  fifo_wrapper_inst : entity work.fifo_wrapper
    generic map (
      use_asynchronous_fifo => use_asynchronous_fifo,
      width => width,
      depth => depth,
      enable_output_register => enable_output_register
    )
    port map (
      clk => clk,
      clk_read => clk_read,
      clk_write => clk_write,
      --
      read_ready => read_ready,
      read_valid => read_valid,
      read_data => read_data,
      --
      write_ready => write_ready,
      write_valid => write_valid,
      write_data => write_data
    );

end architecture;
