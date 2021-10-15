-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the tsfpga project.
-- https://tsfpga.com
-- https://gitlab.com/tsfpga/tsfpga
-- -------------------------------------------------------------------------------------------------
-- BFM for sending data on an AXI stream interface. Data is pushed as an integer array to a queue.
--
-- The byte length of the bursts (as indicated by the length of the data_queue arrays)
-- does not need to be aligned with the data width of the bus.
-- If unaligned, the last data beat will not have all byte lanes set to valid data and strobe.
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
    data_width_bits : positive;
    -- Push data (integer_array_t with push_ref()) to this queue.
    -- Each element should be an unsigned byte. Little endian byte order is assumed.
    -- The integer arrays will be deallocated after this BFM is done with them.
    data_queue : queue_t;
    stall_config : stall_config_t := null_stall_config;
    -- Is also used for the random seed for handshaking stall.
    -- Set to something unique in order to vary the random sequence.
    logger_name_suffix : string := "";
    -- The 'strobe' is usually a "byte strobe", but the strobe unit width can be modified for cases
    -- when the strobe lanes are wider than bytes.
    strobe_unit_width_bits : positive := 8
  );
  port (
    clk : in std_logic;
    --
    ready : in std_logic;
    valid : out std_logic := '0';
    last : out std_logic := '0';
    data : out std_logic_vector(data_width_bits - 1 downto 0) := (others => '0');
    strobe : out std_logic_vector(data_width_bits / strobe_unit_width_bits - 1 downto 0) :=
      (others => '0')
  );
end entity;

architecture a of axi_stream_master is

  constant bytes_per_beat : positive := data_width_bits / 8;
  constant bytes_per_strobe_unit : positive := strobe_unit_width_bits / 8;

  signal strobe_byte : std_logic_vector(data_width_bits / 8 - 1 downto 0) := (others => '0');

  signal data_is_valid : std_logic := '0';

begin

  ------------------------------------------------------------------------------
  main : process
    variable data_burst : integer_array_t := null_integer_array;
    variable burst_length_bytes : positive := 1;
    variable data_value : natural := 0;

    variable byte_lane_idx : natural := 0;
    variable is_last_byte : boolean := false;
  begin
    while is_empty(data_queue) loop
      wait until rising_edge(clk);
    end loop;

    data_burst := pop_ref(data_queue);
    burst_length_bytes := length(data_burst);

    assert burst_length_bytes mod bytes_per_strobe_unit = 0
      report "Burst length must be a multiple of strobe unit";

    data_is_valid <= '1';

    for byte_idx in 0 to burst_length_bytes - 1 loop
      byte_lane_idx := byte_idx mod bytes_per_beat;

      data_value := get(arr=>data_burst, idx=>byte_idx);
      data((byte_lane_idx + 1) * 8 - 1 downto byte_lane_idx * 8) <=
        std_logic_vector(to_unsigned(data_value, 8));

      strobe_byte(byte_lane_idx) <= '1';

      is_last_byte := byte_idx = burst_length_bytes - 1;
      if byte_lane_idx = bytes_per_beat - 1 or is_last_byte then
        last <= to_sl(is_last_byte);
        wait until (ready and valid) = '1' and rising_edge(clk);

        last <= '0';
        data <= (others => '0');
        strobe_byte <= (others => '0');
      end if;
    end loop;

    -- Deallocate after we are done with the data.
    deallocate(data_burst);

    -- Default: Signal "not valid" to handshake BFM before next packet.
    -- If queue is not empty, it will instantly be raised again (no bubble cycle).
    data_is_valid <= '0';
  end process;


  ------------------------------------------------------------------------------
  handshake_master_int : entity bfm.handshake_master
    generic map(
      stall_config => stall_config,
      logger_name_suffix => logger_name_suffix,
      data_width => data'length
    )
    port map(
      clk => clk,
      --
      data_is_valid => data_is_valid,
      --
      ready => ready,
      valid => valid,
      last => last,
      data => data,
      strobe => strobe_byte
    );


  ------------------------------------------------------------------------------
  assign_byte_strobe : if strobe_unit_width_bits = 8 generate

    strobe <= strobe_byte;

  else generate

    assert data'length mod strobe'length = 0 report "Data width must be a multiple of strobe width";
    assert data'length > 8 report "Strobe unit must be one byte or wider";
    assert data'length mod 8 = 0 report "Strobe unit must be a byte multiple";

    ------------------------------------------------------------------------------
    assign : process(all)
    begin
      for strobe_idx in strobe'range loop
        strobe(strobe_idx) <= strobe_byte(strobe_idx * bytes_per_strobe_unit);
      end loop;
    end process;

  end generate;

end architecture;
