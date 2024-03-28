-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the hdl-modules project, a collection of reusable, high-quality,
-- peer-reviewed VHDL building blocks.
-- https://hdl-modules.com
-- https://github.com/hdl-modules/hdl-modules
-- -------------------------------------------------------------------------------------------------

library ieee;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;

library osvvm;
use osvvm.RandomPkg.RandomPType;

library vunit_lib;
use vunit_lib.check_pkg.all;
use vunit_lib.integer_array_pkg.all;
use vunit_lib.queue_pkg.all;
use vunit_lib.random_pkg.all;
use vunit_lib.run_pkg.all;

library bfm;
use bfm.stall_bfm_pkg.stall_configuration_t;

library common;
use common.types_pkg.all;


entity tb_strobe_on_last is
  generic (
    data_width : positive;
    test_full_throughput : boolean;
    seed : natural;
    runner_cfg : string
  );
end entity;

architecture tb of tb_strobe_on_last is

  constant bytes_per_beat : positive := data_width / 8;

  signal clk : std_ulogic := '0';
  constant clk_period : time := 10 ns;

  signal input_ready, input_valid, input_last : std_ulogic := '0';
  signal output_ready, output_valid, output_last : std_ulogic := '0';

  signal input_data, output_data : std_ulogic_vector(data_width - 1 downto 0) := (others => '0');
  signal input_strobe, output_strobe :
    std_ulogic_vector(data_width / 8 - 1 downto 0) := (others => '0');

  constant input_data_queue, reference_data_queue : queue_t := new_queue;

  constant stall_config : stall_configuration_t := (
    stall_probability => 0.2 * to_real(not test_full_throughput),
    min_stall_cycles => 1,
    max_stall_cycles => 4
  );

  shared variable rnd : RandomPType;

  signal num_output_packets_checked : natural := 0;

begin

  test_runner_watchdog(runner, 100 us);
  clk <= not clk after clk_period / 2;


  ------------------------------------------------------------------------------
  main : process

    variable num_output_packets_expected : natural := 0;

    procedure run_test_packet is
      variable packet_length_beats, packet_length_bytes : natural := 0;
      variable data_in, reference_data_out : integer_array_t := null_integer_array;
    begin
      -- Random length. We want to run just a few words, since we want to exercise
      -- the 'last' behavior a lot. But set a max value that is higher than the pipeline depth.
      -- Note that it is possible to have zero length input packets.
      packet_length_beats := rnd.RandInt(0, 5);
      packet_length_bytes := packet_length_beats * bytes_per_beat;

      random_integer_array(
        rnd => rnd,
        integer_array => data_in,
        width => packet_length_bytes,
        bits_per_word => 8,
        is_signed => false
      );
      reference_data_out := copy(data_in);

      push_ref(input_data_queue, data_in);

      -- Zero length input packets are dropped by the entity
      if packet_length_bytes > 0 then
        push_ref(reference_data_queue, reference_data_out);
        num_output_packets_expected := num_output_packets_expected + 1;
      end if;
    end procedure;

    procedure wait_until_done is
    begin
      wait until
        is_empty(input_data_queue)
        and is_empty(reference_data_queue)
        and num_output_packets_checked = num_output_packets_expected
        and rising_edge(clk);
      wait until rising_edge(clk);
    end procedure;

  begin
    test_runner_setup(runner, runner_cfg);
    rnd.InitSeed(seed);

    if run("test_data") then
      for packet_idx in 0 to 500 loop
        run_test_packet;
      end loop;

      wait_until_done;
    end if;

    -- Note that full throughput check is done in another process, if the appropriate generic is set

    test_runner_cleanup(runner);
  end process;


  ------------------------------------------------------------------------------
  input_block : block
    signal data_is_valid : std_ulogic := '0';
  begin

    ------------------------------------------------------------------------------
    stimuli : process
      variable input_bytes : integer_array_t := null_integer_array;
      variable num_input_bytes : natural := 0;

      variable data_value : natural := 0;

      variable byte_lane_idx : natural := 0;
      variable is_last_byte : boolean := false;

      -- Do not have strobed out words in the data stream when testing for full throughput.
      -- The last word may be on a strobed out word however.
      constant may_insert_zero_words : boolean := not test_full_throughput;

      procedure send_input_word(
        data : std_ulogic_vector(input_data'range);
        strobe : std_ulogic_vector(input_strobe'range);
        last : std_ulogic
      ) is
      begin
        data_is_valid <= '1';

        input_data <= data;
        input_strobe <= strobe;
        input_last <= last;

        wait until input_ready and input_valid and rising_edge(clk);

        input_data <= (others => '0');
        input_strobe <= (others => '0');
        input_last <= '0';

        -- Default: Signal "not valid" to handshake BFM before next packet.
        -- If queue is not empty, it will instantly be raised again (no bubble cycle).
        data_is_valid <= '0';
      end procedure;

      procedure send_zero_input_word(last : std_ulogic) is
      begin
        send_input_word(data=>(others => '0'), strobe=>(others => '0'), last=>last);
      end procedure;

      variable data : std_ulogic_vector(input_data'range) := (others => '0');
      variable strobe : std_ulogic_vector(input_strobe'range) := (others => '0');
    begin
      while is_empty(input_data_queue) loop
        wait until rising_edge(clk);
      end loop;

      input_bytes := pop_ref(input_data_queue);
      num_input_bytes := length(input_bytes);

      if num_input_bytes = 0 then
        send_zero_input_word(last=>'1');
      end if;

      for byte_idx in 0 to num_input_bytes - 1 loop
        byte_lane_idx := byte_idx mod bytes_per_beat;

        data_value := get(arr=>input_bytes, idx=>byte_idx);
        data((byte_lane_idx + 1) * 8 - 1 downto byte_lane_idx * 8) :=
          std_logic_vector(to_unsigned(data_value, 8));

        strobe(byte_lane_idx) := '1';

        is_last_byte := byte_idx = num_input_bytes - 1;
        if is_last_byte or byte_lane_idx = bytes_per_beat - 1 then
          -- Randomly insert a random number of strobed out words before the data is sent
          if rnd.RandInt(1, 2) = 2 and may_insert_zero_words then
            for zero_word_idx in 1 to rnd.RandInt(1, 3) loop
              send_zero_input_word(last=>'0');
            end loop;
          end if;

          if is_last_byte then
            if rnd.RandInt(1, 2) = 2 then
              -- Send the data without setting 'last'
              send_input_word(data=>data, strobe=>strobe, last=>'0');

              -- Randomly insert a random number of strobed out words between the data and the
              -- 'last' transaction
              if rnd.RandInt(1, 2) = 2 and may_insert_zero_words then
                for zero_word_idx in 1 to rnd.RandInt(1, 3) loop
                  send_zero_input_word(last=>'0');
                end loop;
              end if;

              -- Send 'last' on a strobe out word
              send_zero_input_word(last=>'1');
            else
              send_input_word(data=>data, strobe=>strobe, last=>'1');
            end if;

          else
            -- This is a word in the middle of the packet. Send as normal.
            send_input_word(data=>data, strobe=>strobe, last=>'0');
          end if;
        end if;
      end loop;

      -- Deallocate after we are done with the data.
      deallocate(input_bytes);
    end process;


    ------------------------------------------------------------------------------
    handshake_master_inst : entity bfm.handshake_master
      generic map (
        stall_config => stall_config,
        seed => seed,
        logger_name_suffix => " - input"
      )
      port map (
        clk => clk,
        --
        data_is_valid => data_is_valid,
        --
        ready => input_ready,
        valid => input_valid
      );

  end block;


  ------------------------------------------------------------------------------
  axi_stream_slave_inst : entity bfm.axi_stream_slave
    generic map (
      data_width => output_data'length,
      reference_data_queue => reference_data_queue,
      stall_config => stall_config,
      seed => seed,
      logger_name_suffix => " - output"
    )
    port map (
      clk => clk,
      --
      ready => output_ready,
      valid => output_valid,
      last => output_last,
      data => output_data,
      strobe => output_strobe,
      --
      num_packets_checked => num_output_packets_checked
    );


  ------------------------------------------------------------------------------
  check_full_throughput : process
  begin
    wait until rising_edge(clk);

    if test_full_throughput then
      check_equal(
        input_ready,
        '1',
        "If there is full throughput without jitter, then input_ready should always be high"
      );
    end if;
  end process;


  ------------------------------------------------------------------------------
  dut : entity work.strobe_on_last
    generic map (
      data_width => data_width
    )
    port map (
      clk => clk,
      --
      input_ready => input_ready,
      input_valid => input_valid,
      input_last => input_last,
      input_data => input_data,
      input_strobe => input_strobe,
      --
      output_ready => output_ready,
      output_valid => output_valid,
      output_last => output_last,
      output_data => output_data,
      output_strobe => output_strobe
    );

end architecture;
