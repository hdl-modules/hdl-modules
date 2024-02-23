-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the hdl-modules project, a collection of reusable, high-quality,
-- peer-reviewed VHDL building blocks.
-- https://hdl-modules.com
-- https://github.com/hdl-modules/hdl-modules
-- -------------------------------------------------------------------------------------------------
-- An incoming packet will be dropped cleanly if ``drop`` is asserted for at least one clock cycle
-- during the active packet.
--
-- Once ``drop`` has been asserted during an active packet, this entity will
--
-- 1. Not pass anything of the current ``input`` packet on to the ``result`` side, including
--    anything that was consumed before ``drop`` was asserted.
--
--    This means that only whole, non-corrupted, packets will be available on the ``result`` side.
-- 2. Keep ``input_ready`` high until the whole packet has been consumed, so the upstream on the
--    ``input`` side is not stalled.
--
-- .. note::
--
--   The :ref:`fifo.fifo` instance in this module is in packet mode, meaning that a whole packet
--   has to be written to FIFO before any data is passed on to ``result`` side.
--   Hence the ``fifo_depth`` generic has to be chosen so that it can hold the maximum possible
--   packet length from the ``input`` side.
-- -------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

library common;
use common.types_pkg.all;

library fifo;


entity clean_packet_dropper is
  generic (
    data_width : positive;
    fifo_depth : positive
  );
  port (
    clk : in std_ulogic;
    --# {{}}
    drop : in std_ulogic;
    --# {{}}
    input_ready : out std_ulogic := '0';
    input_valid : in std_ulogic;
    input_last : in std_ulogic;
    input_data : in std_ulogic_vector(data_width - 1 downto 0);
    input_strobe : in std_ulogic_vector(data_width / 8 - 1 downto 0) := (others => '-');
    --# {{}}
    result_ready : in std_ulogic;
    result_valid : out std_ulogic := '0';
    result_last : out std_ulogic := '0';
    result_data : out std_ulogic_vector(data_width - 1 downto 0) := (others => '0');
    result_strobe : out std_ulogic_vector(data_width / 8 - 1 downto 0) := (others => '0')
  );
end entity;

architecture a of clean_packet_dropper is

  signal input_packet_is_ongoing : std_ulogic := '0';
  signal drop_sticky, drop_fifo_packet : std_ulogic := '0';

begin

  ------------------------------------------------------------------------------
  track_packet_drop_status : process
    variable input_packet_is_ongoing_next : std_ulogic := '0';
  begin
    wait until rising_edge(clk);

    input_packet_is_ongoing_next := input_packet_is_ongoing or input_valid;
    input_packet_is_ongoing <= input_packet_is_ongoing_next;

    drop_sticky <= drop_sticky or (drop and input_packet_is_ongoing_next);

    if input_ready and input_valid and input_last then
      drop_sticky <= '0';
      input_packet_is_ongoing <= '0';
    end if;
  end process;

  drop_fifo_packet <= drop or drop_sticky;


  ------------------------------------------------------------------------------
  fifo_block : block
    signal write_ready : std_ulogic := '0';

    constant fifo_width : positive := input_data'length + input_strobe'length;
    signal write_data, read_data : std_ulogic_vector(fifo_width - 1 downto 0) := (others => '0');
  begin

    ------------------------------------------------------------------------------
    fifo_inst : entity fifo.fifo
      generic map (
        width => write_data'length,
        depth => fifo_depth,
        enable_last => true,
        enable_packet_mode => true,
        enable_drop_packet => true
      )
      port map(
        clk => clk,
        --
        drop_packet => drop_fifo_packet,
        --
        read_ready => result_ready,
        read_valid => result_valid,
        read_last => result_last,
        read_data => read_data,
        --
        write_ready => write_ready,
        write_valid => input_valid,
        write_last => input_last,
        write_data => write_data
      );

    -- Pack/unpack data
    write_data <= input_strobe & input_data;

    result_data <= read_data(result_data'range);
    result_strobe <= read_data(read_data'high downto result_data'length);

    -- Pop data on the 'input' interface when we are actively dropping
    input_ready <= write_ready or drop_fifo_packet;

  end block;

end architecture;
