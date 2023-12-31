-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the hdl-modules project, a collection of reusable, high-quality,
-- peer-reviewed VHDL building blocks.
-- https://hdl-modules.com
-- https://github.com/hdl-modules/hdl-modules
-- -------------------------------------------------------------------------------------------------
-- BFM for sending data on an AXI-Stream interface.
--
-- Data is pushed to the ``data_queue`` :doc:`VUnit queue <vunit:data_types/queue>` as a
-- :doc:`VUnit integer_array <vunit:data_types/integer_array>`.
-- Each element in the integer array should be an unsigned byte.
-- Little endian byte order is assumed.
--
-- The byte length of the packets (as indicated by the length of the ``data_queue`` arrays)
-- does not need to be aligned with the ``data_width`` of the bus.
-- If unaligned, the last data beat will not have all byte lanes set to valid
-- ``data`` and ``strobe``.
--
-- .. note::
--
--   This BFM will inject random handshake jitter/stalling for good verification coverage.
--   Modify the ``stall_config`` generic to change the behavior.
--   You can also set ``seed`` to something unique in order to vary the randomization in each
--   simulation run.
--   This can be done conveniently with the
--   :meth:`add_vunit_config() <tsfpga.module.BaseModule.add_vunit_config>` method if using tsfpga.
-- -------------------------------------------------------------------------------------------------

library ieee;
context ieee.ieee_std_context;

library vunit_lib;
context vunit_lib.vc_context;
context vunit_lib.vunit_context;

library bfm;

library common;
use common.types_pkg.all;


entity axi_stream_master is
  generic (
    -- Set the desired width of the 'data' field.
    data_width : positive;
    -- Push data (integer_array_t with push_ref()) to this queue.
    -- The integer arrays will be deallocated after this BFM is done with them.
    data_queue : queue_t;
    -- Assign non-zero to randomly insert jitter/stalling in the data stream.
    stall_config : stall_config_t := null_stall_config;
    -- Random seed for handshaking stall/jitter.
    -- Set to something unique in order to vary the random sequence.
    seed : natural := 0;
    -- Suffix for the VUnit logger name.
    logger_name_suffix : string := "";
    -- The 'strobe' is usually a "byte strobe", but the strobe unit width can be modified for cases
    -- when the strobe lanes are wider than bytes.
    strobe_unit_width : positive := 8;
    -- When 'valid' is zero, the associated output ports will be driven with this value.
    -- This is to avoid a DUT sampling the values in the wrong clock cycle.
    drive_invalid_value : std_ulogic := 'X'
  );
  port (
    clk : in std_ulogic;
    --# {{}}
    ready : in std_ulogic;
    valid : out std_ulogic := '0';
    last : out std_ulogic := drive_invalid_value;
    data : out std_ulogic_vector(data_width - 1 downto 0) := (others => drive_invalid_value);
    strobe : out std_ulogic_vector(data_width / strobe_unit_width - 1 downto 0) := (
      others => drive_invalid_value
    );
    --# {{}}
    num_packets_sent : out natural := 0
  );
end entity;

architecture a of axi_stream_master is

  constant bytes_per_beat : positive := data_width / 8;
  constant bytes_per_strobe_unit : positive := strobe_unit_width / 8;

  signal last_int : std_ulogic := drive_invalid_value;
  signal data_int : std_ulogic_vector(data'range) := (others => drive_invalid_value);
  signal strobe_byte : std_ulogic_vector(data_width / 8 - 1 downto 0) := (others => '0');
  signal strobe_int : std_ulogic_vector(data_width / strobe_unit_width - 1 downto 0) := (
    others => '0'
  );

  signal data_is_valid : std_ulogic := '0';

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
    variable data_packet : integer_array_t := null_integer_array;
    variable packet_length_bytes : positive := 1;
    variable data_value : natural := 0;

    variable byte_lane_idx : natural := 0;
    variable is_last_byte : boolean := false;
  begin
    while is_empty(data_queue) loop
      wait until rising_edge(clk);
    end loop;

    data_packet := pop_ref(data_queue);
    packet_length_bytes := length(data_packet);

    assert packet_length_bytes mod bytes_per_strobe_unit = 0
      report "Packet length must be a multiple of strobe unit";

    data_is_valid <= '1';

    for byte_idx in 0 to packet_length_bytes - 1 loop
      byte_lane_idx := byte_idx mod bytes_per_beat;

      data_value := get(arr=>data_packet, idx=>byte_idx);
      data_int((byte_lane_idx + 1) * 8 - 1 downto byte_lane_idx * 8) <=
        std_logic_vector(to_unsigned(data_value, 8));

      strobe_byte(byte_lane_idx) <= '1';

      is_last_byte := byte_idx = packet_length_bytes - 1;

      if byte_lane_idx = bytes_per_beat - 1 or is_last_byte then
        last_int <= to_sl(is_last_byte);

        wait until ready and valid and rising_edge(clk);

        -- Default for next beat. We will fill in the byte lanes that are used.
        data_int <= (others => drive_invalid_value);
        strobe_byte <= (others => '0');
      end if;
    end loop;

    -- Deallocate after we are done with the data.
    deallocate(data_packet);

    -- Default: Signal "not valid" to handshake BFM before next packet.
    -- If queue is not empty, it will instantly be raised again (no bubble cycle).
    data_is_valid <= '0';

    num_packets_sent <= num_packets_sent + 1;
  end process;


  ------------------------------------------------------------------------------
  handshake_master_inst : entity bfm.handshake_master
    generic map(
      stall_config => stall_config,
      seed => seed,
      logger_name_suffix => logger_name_suffix
    )
    port map(
      clk => clk,
      --
      data_is_valid => data_is_valid,
      --
      ready => ready,
      valid => valid
    );


  ------------------------------------------------------------------------------
  assign_byte_strobe : if strobe_unit_width = 8 generate

    strobe_int <= strobe_byte;

  else generate

    ------------------------------------------------------------------------------
    assign : process(all)
    begin
      for strobe_idx in strobe'range loop
        strobe_int(strobe_idx) <= strobe_byte(strobe_idx * bytes_per_strobe_unit);
      end loop;
    end process;

  end generate;


  ------------------------------------------------------------------------------
  assign_invalid : process(all)
  begin
    -- We should drive the 'invalid' value when bus is not valid

    if valid then
      last <= last_int;
      data <= data_int;
      strobe <= strobe_int;
    else
      last <= drive_invalid_value;
      data <= (others => drive_invalid_value);
      strobe <= (others => drive_invalid_value);
    end if;
  end process;

end architecture;
