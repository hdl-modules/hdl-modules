-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the hdl-modules project, a collection of reusable, high-quality,
-- peer-reviewed VHDL building blocks.
-- https://hdl-modules.com
-- https://github.com/hdl-modules/hdl-modules
-- -------------------------------------------------------------------------------------------------
-- Wrapper that selects synchronous/asynchronous FIFO or passthrough depending on generic values.
-- -------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library common;
use common.attribute_pkg.all;


entity fifo_wrapper is
  generic (
    use_asynchronous_fifo : boolean;
    -- Generics for the FIFOs.
    -- Note that the default values are carefully chosen. Must be exactly the same as in fifo.vhd
    -- and asynchronous_fifo.vhd.
    width : positive;
    -- Set depth to 0 to not include any fifo at all
    depth : natural;
    almost_full_level : natural range 0 to depth := depth;
    almost_empty_level : natural range 0 to depth := 0;
    enable_last : boolean := false;
    enable_packet_mode : boolean := false;
    enable_drop_packet : boolean := false;
    enable_peek_mode : boolean := false;
    enable_output_register : boolean := false;
    ram_type : ram_style_t := ram_style_auto
  );
  port (
    -- This clock is used for a synchronous FIFO
    clk : in std_ulogic;
    -- These clocks are used for an asynchronous FIFO
    clk_write : in std_ulogic := '0';
    clk_read : in std_ulogic := '0';

    --# {{}}
    write_ready : out std_ulogic := '1';
    write_valid : in  std_ulogic;
    write_data : in  std_ulogic_vector(width - 1 downto 0);
    write_last : in std_ulogic := '0';

    -- Note that this is the same as read_level for a synchronous FIFO.
    write_level : out natural range 0 to depth := 0;
    -- Note that for an asynchronous FIFO, this signal is in the "write" clock domain.
    almost_full : out std_ulogic := '0';

    -- Note that for an asynchronous FIFO, this signal is in the "write" clock domain
    drop_packet : in std_ulogic := '0';

    --# {{}}
    read_ready : in  std_ulogic;
    read_valid : out std_ulogic := '0';
    read_data : out std_ulogic_vector(width - 1 downto 0) := (others => '0');
    read_last : out std_ulogic := '0';
    read_peek_mode : in std_ulogic := '0';

    -- Note that this is the same as write_level for a synchronous FIFO.
    -- Note that this value is not assigned for an asynchronous FIFO in packet mode.
    read_level : out natural range 0 to depth := 0;
    -- Note that for an asynchronous FIFO, this signal is in the "read" clock domain.
    almost_empty : out std_ulogic := '1'
  );
end entity;

architecture a of fifo_wrapper is

begin

  ------------------------------------------------------------------------------
  choose_fifo : if depth = 0 generate

    assert not enable_packet_mode report "Can not use packet mode without FIFO";
    assert not enable_drop_packet report "Can not use drop packet without FIFO";
    assert not enable_peek_mode report "Can not use peek mode without FIFO";
    assert not enable_output_register report "Can not use output register without FIFO";

    write_ready <= read_ready;
    read_valid <= write_valid;
    read_data <= write_data;
    read_last <= write_last;


  ------------------------------------------------------------------------------
  elsif use_asynchronous_fifo generate

    assert not enable_peek_mode report "Only available for synchronous FIFO" severity failure;


    ------------------------------------------------------------------------------
    asynchronous_fifo_inst : entity work.asynchronous_fifo
      generic map (
        width => width,
        depth => depth,
        almost_full_level => almost_full_level,
        almost_empty_level => almost_empty_level,
        enable_last => enable_last,
        enable_packet_mode => enable_packet_mode,
        enable_drop_packet => enable_drop_packet,
        enable_output_register => enable_output_register,
        ram_type => ram_type
      )
      port map (
        clk_write => clk_write,
        write_ready => write_ready,
        write_valid => write_valid,
        write_data => write_data,
        write_last => write_last,
        --
        write_level => write_level,
        write_almost_full => almost_full,
        --
        drop_packet => drop_packet,
        --
        clk_read => clk_read,
        read_ready => read_ready,
        read_valid => read_valid,
        read_data => read_data,
        read_last => read_last,
        --
        read_level => read_level,
        read_almost_empty => almost_empty
      );


  ------------------------------------------------------------------------------
  else generate

    ------------------------------------------------------------------------------
    fifo_inst : entity work.fifo
      generic map (
        width => width,
        depth => depth,
        almost_full_level => almost_full_level,
        almost_empty_level => almost_empty_level,
        enable_last => enable_last,
        enable_packet_mode => enable_packet_mode,
        enable_drop_packet => enable_drop_packet,
        enable_peek_mode => enable_peek_mode,
        enable_output_register => enable_output_register,
        ram_type => ram_type
      )
      port map (
        clk => clk,
        --
        level => read_level,
        --
        write_ready => write_ready,
        write_valid => write_valid,
        write_data => write_data,
        write_last => write_last,
        almost_full => almost_full,
        --
        drop_packet => drop_packet,
        --
        read_ready => read_ready,
        read_valid => read_valid,
        read_data => read_data,
        read_last => read_last,
        read_peek_mode => read_peek_mode,
        almost_empty => almost_empty
      );

    write_level <= read_level;

  end generate;

end architecture;
