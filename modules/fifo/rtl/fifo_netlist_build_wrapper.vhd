-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the hdl_modules project, a collection of reusable, high-quality,
-- peer-reviewed VHDL building blocks.
-- https://hdl-modules.com
-- https://gitlab.com/hdl_modules/hdl_modules
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
    clk : in std_logic;
    clk_read : in std_logic;
    clk_write : in std_logic;
    --# {{}}
    read_ready : in std_logic;
    read_valid : out std_logic := '0';
    read_data : out std_logic_vector(width - 1 downto 0) := (others => '0');
    --# {{}}
    write_ready : out std_logic := '1';
    write_valid : in std_logic;
    write_data : in std_logic_vector(width - 1 downto 0)
  );
end entity;

architecture a of fifo_netlist_build_wrapper is

begin

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
