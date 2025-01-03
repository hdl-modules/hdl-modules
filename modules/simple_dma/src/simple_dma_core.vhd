-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the hdl-modules project, a collection of reusable, high-quality,
-- peer-reviewed VHDL building blocks.
-- https://hdl-modules.com
-- https://github.com/hdl-modules/hdl-modules
-- -------------------------------------------------------------------------------------------------
-- Main implementation of the simple DMA functionality.
-- This entity is not suitable for instantiation in a user design, use instead e.g.
-- :ref:`simple_dma.simple_dma_axi_lite`.
--
--
-- Packet length
-- _____________
--
-- The ``packet_length_beats`` generic specifies the packet length in terms of number of
-- input ``stream`` beats.
-- When one packet of streaming data has been written to DDR,
-- the ``write_done`` interrupt will trigger and the ``buffer_written_address`` register
-- will be updated.
-- This indicates to the software that there is data in the buffer that can be read.
--
-- .. note::
--   The packet length is a compile-time parameter.
--   It can not be changed during runtime and there is no support for writing or clearing
--   partial packets.
--
--   This saves a lot of resources and is part of the simple nature of this DMA core.
--
-- If the packet length specified by the user equates more than one maximum-length AXI burst,
-- the core will perform burst splitting internally.
--
--
-- .. _simple_dma_resource_usage:
--
-- Resource usage
-- ______________
--
-- The core has a simple design with the goal of low resource utilization in mind.
-- See :ref:`simple_dma.simple_dma_axi_lite.resource_utilization` for some build numbers.
-- These numbers are incredibly low compared to some other implementations.
--
-- The special case when ``packet_length_beats`` is 1 has an optimized implementation that gives
-- even lower resource usage than the general case.
-- This comes at the cost of quite poor memory performance, since every data beat becomes and
-- AXI burst in that case.
--
--
-- .. _simple_dma_throughput:
--
-- AXI/data throughput
-- ___________________
--
-- The core has a one-cycle overhead per packet.
-- Meaning that for each packet, the input ``stream`` will stall (``stream_ready = 0``) for one
-- clock cycle.
-- This is assuming that ``AWREADY`` and ``WREADY`` are high.
-- If they are not, their stall will be propagated to the ``stream``.
--
-- This performance should be enough for even the most demanding applications.
-- The one-cycle overhead could theoretically be optimized away, but it is quite likely
-- that downstream AXI interconnect infrastructure has some overhead for each address
-- transaction anyway.
-- I.e. the one-cycle overhead in this core is probably not limiting the throughput overall.
--
-- If the memory buffer is full, the ``stream`` will stall until there is space.
-- When the software writes an updated ``buffer_read_address`` register indicating available space,
-- the ``stream`` will start after two clock cycles.
--
--
-- AXI behavior
-- ____________
--
-- The core is designed to be as well-behaved as possible in an AXI sense:
--
-- 1. AXI bursts of the maximum length possible will be used.
--
-- 2. The ``AW`` transaction is only initiated once we have at least one ``W`` beat available.
--
-- 3. ``BREADY`` is always high.
--
-- This gives very good AXI performance.
--
-- W channel block
-- ~~~~~~~~~~~~~~~
--
-- Related to bullet point 2 above, the cores does NOT accumulate a whole burst in order to
-- guarantee no holes in the data.
-- Meaning, it is possible that an ``AW`` and a few ``W`` transactions  happen, but then the
-- ``stream`` can stop for a while and block the AXI bus before the burst is finished.
--
-- This can be problematic if the downstream AXI slave is a crossbar/interconnect that
-- arbitrates between multiple AXI masters.
--
-- It is up to the user to make sure that either,
--
-- 1. The ``stream`` never stops within a packet, so that optimal AXI performance is reached.
-- 2. Or, the downstream AXI slave can handle holes without impacting performance.
--    :ref:`axi.axi_write_throttle` is designed to help with this.
--
-- AXI3
-- ~~~~
--
-- Enabling the ``enable_axi3`` generic will make the core compliant with AXI3 instead of AXI4.
-- The core does not use any of the ID fields (``AWID``, ``WID``, ``BID``) so the only difference
-- is the burst length limitation.
-- -------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library axi;
use axi.axi_pkg.all;

library axi_lite;
use axi_lite.axi_lite_pkg.all;

library common;
use common.types_pkg.all;

library math;
use math.math_pkg.is_power_of_two;

library register_file;
use register_file.register_file_pkg.all;

library ring_buffer;
use ring_buffer.simple_ring_buffer_manager_pkg.all;

use work.simple_dma_register_record_pkg.all;
use work.simple_dma_regs_pkg.all;


entity simple_dma_core is
  generic (
    -- The width of the AXI AWADDR field as well as all the ring buffer addresses
    -- handled internally.
    address_width : axi_addr_width_t;
    -- The data width of the 'stream' interface.
    stream_data_width : axi_data_width_t;
    -- The width of the AXI WDATA field.
    -- Must be the native width of the AXI port, we do not support narrow bursts.
    axi_data_width : axi_data_width_t;
    -- The number of beats on the 'stream' interface that are accumulated before
    -- being written to memory.
    -- Increase this number to improve memory performance.
    -- Will also decrease the frequency of 'write_done' interrupts.
    -- But note that there is no support for writing partial packets.
    -- If the 'stream' stops in the middle of a packet, there is not way to write or clear the
    -- accumulated data.
    packet_length_beats : positive;
    -- Enable AXI3 instead of AXI4, with the limitations that this implies.
    enable_axi3 : boolean
  );
  port (
    clk : in std_ulogic;
    --# {{}}
    stream_ready : out std_ulogic := '0';
    stream_valid : in std_ulogic;
    stream_data : in std_ulogic_vector(stream_data_width - 1 downto 0);
    --# {{}}
    regs_up : out simple_dma_regs_up_t := simple_dma_regs_up_init;
    regs_down : in simple_dma_regs_down_t;
    interrupt : out std_ulogic := '0';
    --# {{}}
    axi_write_m2s : out axi_write_m2s_t := axi_write_m2s_init;
    axi_write_s2m : in axi_write_s2m_t
  );
end entity;

architecture a of simple_dma_core is

  ------------------------------------------------------------------------------
  -- Generic constants.
  constant stream_data_width_bytes : positive := stream_data_width / 8;
  constant packet_length_bytes : positive := packet_length_beats * stream_data_width_bytes;

  constant axi_data_width_bytes : positive := axi_data_width / 8;
  constant packet_length_axi_beats : positive := packet_length_bytes / axi_data_width_bytes;

  ------------------------------------------------------------------------------
  -- Signals.
  signal interrupt_sources : register_t := (others => '0');

  signal ring_buffer_status : simple_ring_buffer_manager_status_t := (
    simple_ring_buffer_manager_status_idle_no_error
  );

begin

  ------------------------------------------------------------------------------
  assert stream_data_width = axi_data_width
    report "Widths must be the same at the moment. Will be changed in the future."
    severity failure;

  assert sanity_check_axi_data_width(data_width=>axi_data_width)
    report "Invalid AXI data width. See above."
    severity failure;

  -- We check the data width using the same function, for simplicity.
  assert sanity_check_axi_data_width(data_width=>stream_data_width)
    report "Invalid stream data width. See above."
    severity failure;

  assert is_power_of_two(packet_length_beats)
    report "Packet length must be a power of two for efficient calculations."
    severity failure;

  assert stream_data_width mod axi_data_width = 0 or axi_data_width mod stream_data_width = 0
    report "Data width ratio must be a whole number of beats."
    severity failure;

  assert packet_length_bytes mod axi_data_width_bytes = 0
    report "Packet length must be a whole number of AXI beats."
    severity failure;

  assert is_power_of_two(packet_length_bytes / axi_data_width_bytes)
    report "Packet length must be a power-of-two number of AXI beats."
    severity failure;


  ------------------------------------------------------------------------------
  interrupt_register_block : block
    signal clear, status : register_t := (others => '0');
  begin

    ------------------------------------------------------------------------------
    interrupt_register_inst : entity register_file.interrupt_register
      port map (
        clk => clk,
        --
        sources => interrupt_sources,
        mask => regs_down.interrupt_mask,
        clear => clear,
        --
        status => status,
        trigger => interrupt
      );

    interrupt_sources(simple_dma_interrupt_status_write_done) <= (
      axi_write_m2s.b.ready and axi_write_s2m.b.valid
    );

    interrupt_sources(simple_dma_interrupt_status_write_error) <= (
      axi_write_m2s.b.ready
      and axi_write_s2m.b.valid
      and to_sl(axi_write_s2m.b.resp /= axi_resp_okay)
    );

    interrupt_sources(simple_dma_interrupt_status_start_address_unaligned_error) <= (
      ring_buffer_status.start_address_unaligned
    );

    interrupt_sources(simple_dma_interrupt_status_end_address_unaligned_error) <= (
      ring_buffer_status.end_address_unaligned
    );

    interrupt_sources(simple_dma_interrupt_status_read_address_unaligned_error) <= (
      ring_buffer_status.read_address_unaligned
    );

    clear <= to_slv(regs_down.interrupt_status);

    regs_up.interrupt_status <= to_simple_dma_interrupt_status(status);

  end block;


  ------------------------------------------------------------------------------
  axi_block : block
    function get_num_axi_bursts_per_packet return positive is
      constant max_axi_burst_length_beats : positive := get_max_burst_length_beats(
        enable_axi3=>enable_axi3
      );
      constant max_axi_burst_length_bytes : positive := (
        max_axi_burst_length_beats * axi_data_width_bytes
      );

      constant packet_fits_in_one_axi_burst : boolean := (
        packet_length_axi_beats <= max_axi_burst_length_beats
      );
    begin
      if packet_fits_in_one_axi_burst then
        return 1;
      end if;

      assert packet_length_bytes mod max_axi_burst_length_bytes = 0
        report (
            "When burst splitting, packet length must be a "
            & "whole number of max-length AXI bursts."
          )
          severity failure;

      return packet_length_bytes / max_axi_burst_length_bytes;
    end function;
    constant num_axi_bursts_per_packet : positive := get_num_axi_bursts_per_packet;

    constant axi_burst_length_beats : positive := (
      packet_length_axi_beats / num_axi_bursts_per_packet
    );
    constant axi_burst_length_bytes : positive := axi_burst_length_beats * axi_data_width_bytes;

    signal segment_ready, segment_valid : std_ulogic := '0';
    signal segment_address : u_unsigned(address_width - 1 downto 0) := (others => '0');
  begin

    ------------------------------------------------------------------------------
    print_things : process
    begin
      report "num_axi_bursts_per_packet = " & integer'image(num_axi_bursts_per_packet);
      report "axi_burst_length_beats = " & integer'image(axi_burst_length_beats);

      wait;
    end process;


    ------------------------------------------------------------------------------
    ring_buffer_block : block
      signal buffer_start_address, buffer_end_address, buffer_written_address, buffer_read_address :
        u_unsigned(address_width - 1 downto 0) := (others => '0');

      -- If we are doing burst splitting, not every 'BVALID' marks the end of a packet.
      signal is_last_burst_in_packet : std_ulogic := '0';
      signal write_done : std_ulogic := '0';
    begin

      ------------------------------------------------------------------------------
      simple_ring_buffer_manager_inst : entity ring_buffer.simple_ring_buffer_manager
        generic map (
          address_width => address_width,
          -- We pop one address 'segment' per AXI burst, which might be multiple per packet.
          segment_length_bytes => axi_burst_length_bytes,
          -- Update 'buffer_written_address' once the whole packet (not the 'segment')
          -- has been written.
          segments_per_packet => num_axi_bursts_per_packet
        )
        port map (
          clk => clk,
          --
          enable => regs_down.config.enable,
          --
          buffer_start_address => buffer_start_address,
          buffer_end_address => buffer_end_address,
          buffer_written_address => buffer_written_address,
          buffer_read_address => buffer_read_address,
          --
          segment_ready => segment_ready,
          segment_valid => segment_valid,
          segment_address => segment_address,
          --
          write_done => write_done,
          --
          status => ring_buffer_status
        );

      buffer_start_address <= u_unsigned(
        regs_down.buffer_start_address(buffer_start_address'range)
      );
      buffer_end_address <= u_unsigned(regs_down.buffer_end_address(buffer_end_address'range));
      buffer_read_address <= u_unsigned(regs_down.buffer_read_address(buffer_read_address'range));

      regs_up.buffer_written_address(buffer_written_address'range) <= std_logic_vector(
        buffer_written_address
      );


      ------------------------------------------------------------------------------
      assign_last_inst : entity common.assign_last
        generic map (
          packet_length_beats => num_axi_bursts_per_packet
        )
        port map (
          clk => clk,
          --
          ready => axi_write_m2s.b.ready,
          valid => axi_write_s2m.b.valid,
          last => is_last_burst_in_packet
        );

      write_done <= (
        axi_write_m2s.b.ready and axi_write_s2m.b.valid and is_last_burst_in_packet
      );

    end block;

    -- Note that no AWID is set. Hence no WID has to be set in AXI3 mode either.

    axi_write_m2s.aw.len <= to_len(burst_length_beats=>axi_burst_length_beats);
    axi_write_m2s.aw.size <= to_size(data_width_bits=>axi_data_width);
    axi_write_m2s.aw.burst <= axi_a_burst_incr;

    axi_write_m2s.w.data(stream_data'range) <= stream_data;
    axi_write_m2s.w.strb <= to_strb(data_width=>axi_data_width);

    axi_write_m2s.b.ready <= '1';


    ------------------------------------------------------------------------------
    -- Optimized implementation for single-beat packets.
    packet_length_gen : if packet_length_axi_beats = 1 generate
      signal merged_ready, merged_valid : std_ulogic := '0';
    begin

      ------------------------------------------------------------------------------
      handshake_merger_inst : entity common.handshake_merger
        generic map (
          num_interfaces => 2
        )
        port map (
          clk => clk,
          --
          input_ready(0) => segment_ready,
          input_ready(1) => stream_ready,
          input_valid(0) => segment_valid,
          input_valid(1) => stream_valid,
          --
          result_ready => merged_ready,
          result_valid => merged_valid
        );


      ------------------------------------------------------------------------------
      handshake_splitter_inst : entity common.handshake_splitter
        generic map (
          num_interfaces => 2
        )
        port map (
          clk => clk,
          --
          input_ready => merged_ready,
          input_valid => merged_valid,
          --
          output_ready(0) => axi_write_s2m.aw.ready,
          output_ready(1) => axi_write_s2m.w.ready,
          output_valid(0) => axi_write_m2s.aw.valid,
          output_valid(1) => axi_write_m2s.w.valid
        );

      axi_write_m2s.aw.addr(segment_address'range) <= segment_address;

      -- Packet length one beat -> it is always the last beat.
      axi_write_m2s.w.last <= '1';


    ------------------------------------------------------------------------------
    -- General implementation for multi-beat packets.
    else generate
      type state_t is (wait_for_start_condition, let_data_pass);
      signal state : state_t := wait_for_start_condition;

      signal stream_last : std_ulogic := '0';
    begin

      ------------------------------------------------------------------------------
      address_handshaking : process
      begin
        wait until rising_edge(clk);

        segment_ready <= '0';

        if axi_write_s2m.aw.ready then
          axi_write_m2s.aw.valid <= '0';
        end if;

        case state is
          when wait_for_start_condition =>
            -- In order to initiate an AW transaction and let W data through, we need to make
            -- sure that
            -- 1. We have incoming stream data, since sending an AW transaction before data is
            --    quite ill-behaved in an AXI sense.
            --    Some AXI slaves might not like it.
            -- 2. We have a valid address to write to.
            --    Meaning, the user has initiated the ring buffer and it is not full.
            -- 3. The previous AW transaction is done, since we simply assert AWVALID and do
            --    not wait for a transaction before proceeding in the state machine.
            if stream_valid and segment_valid and not axi_write_m2s.aw.valid then
              axi_write_m2s.aw.valid <= '1';
              -- Sample the address since we will pop the 'segment' word straight away, whereas
              -- we don't know when the 'AW' transaction will happen.
              axi_write_m2s.aw.addr(segment_address'range) <= segment_address;

              -- Since we spend at least one clock cycle in the other state, it is safe to pop like
              -- this and then look at 'segment_valid' as soon as we return to this state again.
              segment_ready <= '1';

              state <= let_data_pass;
            end if;

          when let_data_pass =>
            -- Use the 'ready' and 'valid' that are not gated by the 'state'.
            -- Saves a little bit of critical path.
            if axi_write_s2m.w.ready and stream_valid and stream_last then
              state <= wait_for_start_condition;
            end if;

        end case;
      end process;


      ------------------------------------------------------------------------------
      -- Incoming stream has no 'last' indicator (by design).
      -- So we need to generate it internally.
      assign_last_inst : entity common.assign_last
        generic map (
          packet_length_beats => axi_burst_length_beats
        )
        port map (
          clk => clk,
          --
          ready => stream_ready,
          valid => stream_valid,
          last => stream_last
        );

      axi_write_m2s.w.valid <= stream_valid and to_sl(state = let_data_pass);
      axi_write_m2s.w.last <= stream_last;

      stream_ready <= axi_write_s2m.w.ready and to_sl(state = let_data_pass);

    end generate;

  end block;

end architecture;
