-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the hdl-modules project, a collection of reusable, high-quality,
-- peer-reviewed VHDL building blocks.
-- https://hdl-modules.com
-- https://github.com/hdl-modules/hdl-modules
-- -------------------------------------------------------------------------------------------------
-- BFM for verifying data on an AXI-Stream interface.
--
-- Reference data is pushed to the ``reference_data_queue``
-- :doc:`VUnit queue <vunit:data_types/queue>` as a
-- :doc:`VUnit integer_array <vunit:data_types/integer_array>`.
-- Each element in the integer array should be an unsigned byte.
-- Little endian byte order is assumed.
--
-- .. note::
--
--   This BFM will inject random handshake jitter/stalling for good verification coverage.
--   Modify the ``stall_config`` generic to change the behavior.
--   You can also set ``seed`` to something unique in order to vary the randomization in each
--   simulation run.
--   This can be done conveniently with the
--   :meth:`add_vunit_config() <tsfpga.module.BaseModule.add_vunit_config>` method if using tsfpga.
--
-- An optional expected ID can be pushed as a ``natural`` to the ``reference_id_queue`` in order to
-- enable ID check of each beat.
--
-- The byte length of the packets (as indicated by the length of the ``reference_data_queue``
-- arrays) does not need to be aligned with the ``data`` width of the bus.
-- If unaligned, the last beat will not have all ``data`` byte lanes checked against reference data.
-- -------------------------------------------------------------------------------------------------

library ieee;
context ieee.ieee_std_context;

library vunit_lib;
context vunit_lib.vc_context;
context vunit_lib.vunit_context;

library bfm;

library common;
use common.types_pkg.all;


entity axi_stream_slave is
  generic (
    -- Set the desired width of the 'data' field.
    data_width : positive;
    -- Push reference data (integer_array_t with push_ref()) to this queue.
    -- The integer arrays will be deallocated after this BFM is done with them.
    reference_data_queue : queue_t;
    -- Set to non-zero in order to enable 'id' check.
    -- In this case reference values have to be pushed to the 'reference_id_queue'.
    id_width : natural := 0;
    -- Push reference 'id' for each data packet to this queue. All data beats in a packet must have
    -- the same ID, and there may be no interleaving of data.
    -- If 'id_width' is zero, no check will be performed and nothing shall be pushed to
    -- this queue.
    reference_id_queue : queue_t := null_queue;
    -- Assign non-zero to randomly insert jitter/stalling in the data stream.
    stall_config : stall_config_t := null_stall_config;
    -- Random seed for handshaking stall/jitter.
    -- Set to something unique in order to vary the random sequence.
    seed : natural := 0;
    -- Suffix for the VUnit logger name. Can be used to differentiate between multiple instances.
    logger_name_suffix : string := "";
    -- The 'strobe' is usually a "byte strobe", but the strobe unit width can be modified for cases
    -- when the strobe lanes are wider than bytes.
    strobe_unit_width : positive := 8;
    -- If true: Once asserted, 'ready' will not fall until valid has been asserted (i.e. a
    -- handshake has happened).
    -- Note that according to the AXI-Stream standard 'ready' may fall at any
    -- time (regardless of 'valid').
    -- However, many modules are developed with this well-behavedness as a way of saving resources.
    well_behaved_stall : boolean := false;
    -- For buses that do not have the 'last' indicator, the check for 'last' on the last beat of
    -- data can be disabled.
    disable_last_check : boolean := false
  );
  port (
    clk : in std_ulogic;
    --# {{}}
    ready : out std_ulogic := '0';
    valid : in std_ulogic;
    last : in std_ulogic := '1';
    id : in u_unsigned(id_width - 1 downto 0) := (others => '0');
    data : in std_ulogic_vector(data_width - 1 downto 0);
    strobe : in std_ulogic_vector(data_width / strobe_unit_width - 1 downto 0) :=
      (others => '1');
    --# {{}}
    -- Optionally, the consuming and checking of data can be disabled.
    -- Can be done between or in the middle of packets.
    enable : in std_ulogic := '1';
    -- Counter for the number of packets that have been consumed and checked against reference data.
    num_packets_checked : out natural := 0
  );
end entity;

architecture a of axi_stream_slave is

  constant bytes_per_beat : positive := data_width / 8;
  constant bytes_per_strobe_unit : positive := strobe_unit_width / 8;

  signal strobe_byte : std_ulogic_vector(data_width / 8 - 1 downto 0) := (others => '0');

  signal checker_is_ready, data_is_ready : std_ulogic := '0';

begin

  assert data_width mod 8 = 0
    report "This entity works on a byte-by-byte basis. Data width must be a multiple of bytes.";

  assert data_width mod strobe_unit_width = 0
    report "A whole number of strobes must fit in each beat.";

  assert data_width >= strobe_unit_width report "Strobe unit can not be greater than data width.";

  assert strobe_unit_width mod 8 = 0 report "Strobe unit must be a byte multiple";

  assert strobe_unit_width >= 8 report "Strobe unit must be one byte or wider";


  ------------------------------------------------------------------------------
  main : process
    variable reference_id : natural := 0;
    variable reference_data : integer_array_t := null_integer_array;
    variable packet_length_bytes, packet_length_beats : positive := 1;

    variable byte_lane_idx : natural := 0;
    variable is_last_beat : boolean := false;
  begin
    while is_empty(reference_data_queue) or enable /= '1' loop
      wait until rising_edge(clk);
    end loop;
    reference_data := pop_ref(reference_data_queue);

    packet_length_bytes := length(reference_data);
    packet_length_beats := (packet_length_bytes + bytes_per_beat - 1) / bytes_per_beat;

    assert packet_length_bytes mod bytes_per_strobe_unit = 0
      report "Packet length must be a multiple of strobe unit";

    checker_is_ready <= '1';

    for byte_idx in 0 to packet_length_bytes - 1 loop
      byte_lane_idx := byte_idx mod bytes_per_beat;
      is_last_beat := byte_idx / bytes_per_beat = packet_length_beats - 1;

      if byte_lane_idx = 0 then
        wait until ready and valid and rising_edge(clk);

        -- Pop reference ID once for this packet, if applicable.
        if id'length > 0 and byte_idx = 0 then
          reference_id := pop(reference_id_queue);
        end if;

        if not disable_last_check then
          check_equal(
            last,
            is_last_beat,
            "'last' check at packet_idx=" & to_string(num_packets_checked)
              & ",byte_idx=" & to_string(byte_idx)
          );
        end if;

        if id'length > 0 then
          check_equal(
            unsigned(id),
            reference_id,
            "'id' check at packet_idx="
              & to_string(num_packets_checked) & ", byte_idx=" & to_string(byte_idx)
          );
        end if;
      end if;

      check_equal(
        strobe_byte(byte_lane_idx),
        '1',
        "'strobe' check at packet_idx=" & to_string(num_packets_checked)
          & ", byte_idx=" & to_string(byte_idx)
      );
      check_equal(
        unsigned(data((byte_lane_idx + 1) * 8 - 1 downto byte_lane_idx * 8)),
        get(arr=>reference_data, idx=>byte_idx),
        "'data' check at packet_idx="
          & to_string(num_packets_checked) & ", byte_idx=" & to_string(byte_idx)
      );
    end loop;

    -- Check strobe for last data beat. If packet length aligns with the bus width, all lanes will
    -- have been checked as '1' above. If packet is not aligned, one or more byte lanes at the top
    -- shall be strobed out.
    for byte_idx in byte_lane_idx + 1 to bytes_per_beat - 1 loop
      check_equal(
        strobe_byte(byte_idx),
        '0',
        "'strobe' check at packet_idx=" & to_string(num_packets_checked)
          & ", byte_idx=" & to_string(byte_idx)
      );
    end loop;

    -- Deallocate after we are done with the data.
    deallocate(reference_data);

    -- Default: Signal "not ready" to handshake BFM before next packet.
    -- If queue is not empty, it will instantly be raised again (no bubble cycle).
    checker_is_ready <= '0';

    num_packets_checked <= num_packets_checked + 1;
  end process;


  data_is_ready <= checker_is_ready and enable;


  ------------------------------------------------------------------------------
  assign_byte_strobe : if strobe_unit_width = 8 generate

    strobe_byte <= strobe;

  else generate

    ------------------------------------------------------------------------------
    assign : process(all)
    begin
      for byte_idx in strobe_byte'range loop
        strobe_byte(byte_idx) <= strobe(byte_idx / bytes_per_strobe_unit);
      end loop;
    end process;

  end generate;


  ------------------------------------------------------------------------------
  handshake_slave_block : block
    signal last_int : std_ulogic := '0';
  begin

    -- The VUnit protocol checker will give an error about "packet completion" unless 'last' arrives
    -- for each packet. Hence when the master does not set 'last', we set it for each beat.
    last_int <= '1' when disable_last_check else last;


    ------------------------------------------------------------------------------
    handshake_slave_inst : entity bfm.handshake_slave
      generic map(
        stall_config => stall_config,
        seed => seed,
        logger_name_suffix => logger_name_suffix,
        well_behaved_stall => well_behaved_stall,
        data_width => data'length,
        id_width => id'length
      )
      port map(
        clk => clk,
        --
        data_is_ready => data_is_ready,
        --
        ready => ready,
        valid => valid,
        last => last_int,
        id => id,
        data => data,
        strobe => strobe_byte
      );

    end block;

end architecture;
