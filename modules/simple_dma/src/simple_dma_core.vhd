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
    -- But note that there is not support from writing partial packets.
    packet_length_beats : positive range 1 to axi_max_burst_length_beats;
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
  constant axi_data_width_bytes : positive := axi_data_width / 8;

  constant packet_length_bytes : positive := packet_length_beats * stream_data_width_bytes;
  constant packet_length_axi_beats : positive := packet_length_bytes / axi_data_width_bytes;

  constant max_burst_length_beats : positive := get_max_burst_length_beats(
    enable_axi3=>enable_axi3
  );

  ------------------------------------------------------------------------------
  -- Signals.
  signal segment_ready, segment_valid : std_ulogic := '0';
  signal segment_address : u_unsigned(address_width - 1 downto 0) := (others => '0');

  signal segment_written : std_ulogic := '0';

  signal ring_buffer_status : simple_ring_buffer_manager_status_t := (
    simple_ring_buffer_manager_status_idle_no_error
  );

  signal merged_ready, merged_valid : std_ulogic := '0';

  signal interrupt_sources : register_t := (others => '0');

begin

  ------------------------------------------------------------------------------
  assert stream_data_width = axi_data_width
    report "Widths must be the same at the moment. Will be changed in the future."
    severity failure;

  assert stream_data_width mod axi_data_width = 0 or axi_data_width mod stream_data_width = 0
    report "Data width ratio must be a whole number of beats"
    severity failure;

  -- Once we split the AXI and stream data widths, we should that the stream data width
  -- is a power-of-two number of bytes.
  assert sanity_check_axi_data_width(data_width=>axi_data_width)
    report "Invalid AXI data width"
    severity failure;

  assert packet_length_beats = 1
    report "We support only single-beat bursts at the moment. Will be changed in the future."
    severity failure;

  assert packet_length_axi_beats <= max_burst_length_beats
    report "We do not support burst splitting at the moment. Will be changed in the future."
    severity failure;

  assert packet_length_bytes <= 4096
    report "We do not support burst splitting at the moment. Will be changed in the future."
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
  ring_buffer_block : block
    signal buffer_start_address, buffer_end_address, buffer_written_address, buffer_read_address :
      u_unsigned(address_width - 1 downto 0) := (others => '0');
  begin

    ------------------------------------------------------------------------------
    simple_ring_buffer_manager_inst : entity ring_buffer.simple_ring_buffer_manager
      generic map (
        address_width => address_width,
        segment_length_bytes => packet_length_bytes
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
        segment_written => segment_written,
        --
        status => ring_buffer_status
      );

    buffer_start_address <= u_unsigned(regs_down.buffer_start_address(buffer_start_address'range));
    buffer_end_address <= u_unsigned(regs_down.buffer_end_address(buffer_end_address'range));
    buffer_read_address <= u_unsigned(regs_down.buffer_read_address(buffer_read_address'range));

    regs_up.buffer_written_address(buffer_written_address'range) <= std_logic_vector(
      buffer_written_address
    );

  end block;


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

  -- Note that no ID is set in either AW or W.

  axi_write_m2s.aw.addr(segment_address'range) <= segment_address;
  axi_write_m2s.aw.len <= to_len(burst_length_beats=>1);
  axi_write_m2s.aw.size <= to_size(data_width_bits=>axi_data_width);
  axi_write_m2s.aw.burst <= axi_a_burst_incr;

  axi_write_m2s.w.data(stream_data'range) <= stream_data;
  axi_write_m2s.w.strb <= to_strb(data_width=>axi_data_width);
  axi_write_m2s.w.last <= '1';

  axi_write_m2s.b.ready <= '1';

  segment_written <= axi_write_m2s.b.ready and axi_write_s2m.b.valid;

end architecture;
