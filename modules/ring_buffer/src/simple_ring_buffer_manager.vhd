-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the hdl-modules project, a collection of reusable, high-quality,
-- peer-reviewed VHDL building blocks.
-- https://hdl-modules.com
-- https://github.com/hdl-modules/hdl-modules
-- -------------------------------------------------------------------------------------------------
-- Simple implementation of the logic for a ring buffer or circular buffer.
-- It is simple in the sense address segments are always of the same length,
-- which is defined at compile-time.
--
-- The entity is designed to be used with applications where the FPGA writes data to
-- a memory buffer and a CPU progressively reads/consumes it.
-- Even though the entity might have other use cases, the terminology and naming of things is based
-- on this presumed use case.
--
-- The ``buffer_start_address``, ``buffer_end_address`` and ``buffer_read_address`` must be set
-- by the user before enabling the entity with the ``enable`` signal.
-- Initially, the ``buffer_read_address`` should be set to the ``buffer_start_address``.
-- All these addresses need to be byte-aligned with the segment length, i.e. they must be integer
-- multiples of ``segment_length_bytes``.
--
-- .. warning::
--
--   Once the entity has been enabled, it does not support disabling, doing so would result in
--   undefined behavior.
--
-- Once enabled, the entity will start providing segment addresses to the user on the
-- ``segment`` interface.
-- This is an AXI-Stream-like handshaking interface.
-- Once a segment has been written, the ``segment_written`` signal must be pulsed by the user.
-- The entity will then update the ``buffer_written_address`` accordingly.
-- Once the CPU has updated ``buffer_read_address`` accordingly, the address of this segment can
-- once again be provided on the ``segment`` interface.
--
-- .. note::
--   In order to distinguish between the full and empty states, this entity will never
--   utilize 100% of the provided buffer space.
--   There will always be one segment that is not used.
--   In other words, there will never be more than
--   ``(buffer_end_address - buffer_start_address) / segment_length_bytes - 1``
--   segments outstanding.
--
-- .. warning::
--
--   This entity will fail if ``buffer_last_address`` is the very last address in the address space.
--   (e.g. 0xFFFFFFFF).
-- -------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library common;
use common.common_pkg.all;
use common.types_pkg.all;

library math;
use math.math_pkg.all;

use work.simple_ring_buffer_manager_pkg.all;


entity simple_ring_buffer_manager is
  generic (
    address_width : positive;
    segment_length_bytes : positive
  );
  port (
    clk : in std_ulogic;
    --# {{}}
    enable : in std_ulogic;
    --# {{}}
    buffer_start_address : in u_unsigned(address_width - 1 downto 0);
    buffer_end_address : in u_unsigned(address_width - 1 downto 0);
    buffer_written_address : out u_unsigned(address_width - 1 downto 0) := (others => '0');
    buffer_read_address : in u_unsigned(address_width - 1 downto 0);
    --# {{}}
    segment_ready : in std_ulogic;
    segment_valid : out std_ulogic := '0';
    segment_address : out u_unsigned(address_width - 1 downto 0) := (others => '0');
    --# {{}}
    segment_written : in std_ulogic;
    --# {{}}
    status : out simple_ring_buffer_manager_status_t := (
      simple_ring_buffer_manager_status_idle_no_error
    )
  );
end entity;

architecture a of simple_ring_buffer_manager is

  constant unaligned_address_width : natural := ceil_log2(segment_length_bytes);
  constant aligned_address_width : natural := address_width - unaligned_address_width;

  subtype unaligned_address_range is natural range unaligned_address_width - 1 downto 0;
  subtype aligned_address_range is natural range address_width - 1 downto unaligned_address_width;

  signal enable_p1 : std_ulogic := '0';

  type state_t is (idle, wait_for_handshake);
  signal state : state_t := idle;

  signal buffer_start_index, buffer_end_index, buffer_written_index, buffer_read_index,
    segment_index : u_unsigned(aligned_address_width - 1 downto 0) := (others => '0');

begin

  ------------------------------------------------------------------------------
  assert is_power_of_two(segment_length_bytes)
    report "Must be power of two for efficient address calculation."
    severity failure;

  assert address_width > unaligned_address_width + 1
    report "Buffer must be able to hold at least two segments"
    severity failure;


  ------------------------------------------------------------------------------
  assertions_gen : if in_simulation generate

    ------------------------------------------------------------------------------
    -- A couple of assertions that are very important but also very expensive to do in hardware.
    -- Hence they are checked only in simulation, but hopefully they can catch some misuse.
    assertions : process
      variable buffer_size_bytes : natural := 0;
    begin
      wait until enable = '1' and enable_p1 = '0' and rising_edge(clk);

      assert buffer_end_address > buffer_start_address
        report "Bad buffer layout";

      assert buffer_read_address = buffer_start_address
        report "Initial read address should be start address";

      buffer_size_bytes := to_integer(buffer_end_address - buffer_start_address);

      assert buffer_size_bytes mod segment_length_bytes = 0
        report "Buffer size should hold a whole number of segments";

      assert buffer_size_bytes >= 2 * segment_length_bytes
        report "Buffer must be able to hold at least two segments";

      assert buffer_start_address mod segment_length_bytes = 0
        report "Buffer addresses must be aligned to segment length";

      assert buffer_end_address mod segment_length_bytes = 0
        report "Buffer addresses must be aligned to segment length";

      wait;
    end process;

  end generate;


  buffer_start_index <= buffer_start_address(aligned_address_range);
  buffer_end_index <= buffer_end_address(aligned_address_range);
  buffer_read_index <= buffer_read_address(aligned_address_range);

  segment_address(aligned_address_range) <= segment_index;
  buffer_written_address(aligned_address_range) <= buffer_written_index;


  ------------------------------------------------------------------------------
  main : process
    variable segment_index_next, written_index_next : u_unsigned(segment_index'range) := (
      others => '0'
    );
  begin
    wait until rising_edge(clk);

    if segment_index + 1 = buffer_end_index then
      segment_index_next := buffer_start_index;
    else
      segment_index_next := segment_index + 1;
    end if;

    if buffer_written_index + 1 = buffer_end_index then
      written_index_next := buffer_start_index;
    else
      written_index_next := buffer_written_index + 1;
    end if;

    if enable and not enable_p1 then
      buffer_written_index <= buffer_start_index;
      segment_index <= buffer_start_index;
    end if;

    if segment_written then
      buffer_written_index <= written_index_next;
    end if;

    case state is
      when idle =>
        if enable = '1' and segment_index_next /= buffer_read_index then
          segment_valid <= '1';
          state <= wait_for_handshake;
        end if;

      when wait_for_handshake =>
        -- We know that 'segment_valid' is '1' here so we don't have to do 'ready and valid'.
        if segment_ready then
          segment_valid <= '0';
          state <= idle;
        end if;
    end case;

    if segment_ready and segment_valid then
      segment_index <= segment_index_next;
    end if;

    enable_p1 <= enable;
  end process;

  status.idle <= to_sl(state = idle);


  ------------------------------------------------------------------------------
  set_unaligned_error_gen : if segment_length_bytes > 1 generate

    ------------------------------------------------------------------------------
    set_unaligned_error : process
      constant unaligned_address_zero : u_unsigned(unaligned_address_range) := (others => '0');
    begin
      wait until rising_edge(clk);

      if buffer_start_address(unaligned_address_zero'range) /= unaligned_address_zero then
        status.start_address_unaligned <= '1';
      end if;

      if buffer_end_address(unaligned_address_zero'range) /= unaligned_address_zero then
        status.end_address_unaligned <= '1';
      end if;

      if buffer_read_address(unaligned_address_zero'range) /= unaligned_address_zero then
        status.read_address_unaligned <= '1';
      end if;
    end process;

  end generate;

end architecture;
