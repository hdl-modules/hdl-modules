-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the hdl-modules project, a collection of reusable, high-quality,
-- peer-reviewed VHDL building blocks.
-- https://hdl-modules.com
-- https://github.com/hdl-modules/hdl-modules
-- -------------------------------------------------------------------------------------------------

library ieee;
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


entity tb_clean_packet_dropper is
  generic (
    seed : natural;
    data_width : positive;
    runner_cfg : string
  );
end entity;

architecture tb of tb_clean_packet_dropper is

  ------------------------------------------------------------------------------
  -- Generic constants
  constant bytes_per_beat : positive := data_width / 8;

  -- Have a shallow FIFO in relation to the packet length, so that we test the scenario when FIFO
  -- goes full.
  constant fifo_depth : positive := 16;

  ------------------------------------------------------------------------------
  -- DUT connections
  signal clk : std_ulogic := '0';
  constant clk_period : time := 10 ns;

  signal drop : std_ulogic := '0';

  signal input_ready, input_valid, input_last : std_ulogic := '0';
  signal result_ready, result_valid, result_last : std_ulogic := '0';

  signal input_data, result_data : std_ulogic_vector(data_width - 1 downto 0) := (others => '0');
  signal input_strobe, result_strobe : std_ulogic_vector(data_width / 8 - 1 downto 0) :=
    (others => '0');

  ------------------------------------------------------------------------------
  -- Testbench stuff
  type drop_behavior_t is (
    no_drop,
    set_before_or_in_frame,
    pulse_in_frame
  );
  constant input_data_queue, reference_data_queue, drop_queue, packet_length_bytes_queue : queue_t
    := new_queue;

  signal drop_explicit : std_ulogic := '0';
  signal drop_count : natural := 0;

  shared variable rnd : RandomPType;
  signal num_packets_checked : natural := 0;

begin

  test_runner_watchdog(runner, 100 us);
  clk <= not clk after clk_period / 2;


  ------------------------------------------------------------------------------
  main : process

    variable num_packets_expected : natural := 0;

    procedure run_test_packet (
      -- When 'false', will drop at random. When 'true', will not drop.
      explicitly_do_not_drop : boolean := false
    ) is
      -- No need to run long packets
      constant packet_length_bytes : positive := rnd.FavorSmall(1, 5 * bytes_per_beat);

      variable data_in, reference_data_out : integer_array_t := null_integer_array;
      variable drop_behavior_int : natural := 0;
    begin
      random_integer_array(
        rnd => rnd,
        integer_array => data_in,
        width => packet_length_bytes,
        bits_per_word => 8,
        is_signed => false
      );

      push(packet_length_bytes_queue, packet_length_bytes);

      if explicitly_do_not_drop then
        drop_behavior_int := drop_behavior_t'pos(no_drop);
      else
        drop_behavior_int := rnd.Uniform(
          drop_behavior_t'pos(drop_behavior_t'low),
          drop_behavior_t'pos(drop_behavior_t'high)
        );
      end if;
      push(drop_queue, drop_behavior_int);

      if drop_behavior_int = drop_behavior_t'pos(no_drop) then
        reference_data_out := copy(data_in);
        push_ref(reference_data_queue, reference_data_out);

        num_packets_expected := num_packets_expected + 1;
      end if;

      push_ref(input_data_queue, data_in);
    end procedure;

    procedure wait_until_done is
    begin
      wait until num_packets_checked = num_packets_expected and rising_edge(clk);
    end procedure;

  begin
    test_runner_setup(runner, runner_cfg);
    rnd.InitSeed(seed);

    if run("test_random_data") then
      for packet_idx in 0 to 500 loop
        run_test_packet;
      end loop;

    elsif run("test_drop_between_frames_should_not_affect_upcoming_packets") then
      -- Run a couple of frames
      for packet_idx in 0 to 5 loop
        run_test_packet;
      end loop;
      run_test_packet(explicitly_do_not_drop=>true);
      wait_until_done;

      wait until rising_edge(clk);
      wait until rising_edge(clk);
      drop_explicit <= '1';
      wait until rising_edge(clk);
      wait until rising_edge(clk);
      drop_explicit <= '0';

      -- Run some further frames, just as usual. Should behave normally.
      for packet_idx in 0 to 5 loop
        run_test_packet;
      end loop;

    end if;

    wait_until_done;

    -- Lots of logic for the 'drop' condition.
    -- Make sure we have actually dropped something in this tb.
    check_relation(drop_count > 0);

    test_runner_cleanup(runner);
  end process;


  ------------------------------------------------------------------------------
  set_drop_block : block
    signal drop_behavior : drop_behavior_t := no_drop;

    signal packet_beat_counter, beat_index_to_set_drop : natural := 0;
    signal packet_is_ongoing : std_ulogic := '0';
    signal drop_has_been_high_this_packet : std_ulogic := '0';
  begin

    ------------------------------------------------------------------------------
    set_drop_for_packet : process
      variable packet_length_bytes, packet_length_beats : natural := 0;
    begin
      while is_empty(drop_queue) loop
        wait until rising_edge(clk);
      end loop;

      packet_length_bytes := pop(packet_length_bytes_queue);
      packet_length_beats := (packet_length_bytes + bytes_per_beat - 1) / bytes_per_beat;

      drop_behavior <= drop_behavior_t'val(pop_integer(drop_queue));

      -- Not used in all drop modes, but we can set the signal always
      beat_index_to_set_drop <= rnd.Uniform(0, packet_length_beats - 1);

      wait until input_ready and input_valid and input_last and rising_edge(clk);
      drop_behavior <= no_drop;
    end process;


    ------------------------------------------------------------------------------
    set_packet_status : process
      variable packet_is_ongoing_next : std_ulogic := '0';
    begin
      wait until rising_edge(clk);

      drop_count <= drop_count + to_int(drop);

      packet_beat_counter <= packet_beat_counter + to_int(input_ready and input_valid);

      packet_is_ongoing_next := packet_is_ongoing or input_valid;
      packet_is_ongoing <= packet_is_ongoing_next;

      drop_has_been_high_this_packet <=
        drop_has_been_high_this_packet or (drop and packet_is_ongoing_next);

      if input_ready and input_valid and input_last then
        packet_beat_counter <= 0;
        packet_is_ongoing <= '0';
        drop_has_been_high_this_packet <= '0';
      end if;
    end process;


    ------------------------------------------------------------------------------
    set_drop : process(all)
      variable drop_int : std_logic := '0';
    begin
      case drop_behavior is
        when no_drop =>
          -- Keep 'drop' low the whole packet.
          drop_int := '0';

        when set_before_or_in_frame =>
          -- Raise 'drop' and keep it high for the whole frame.
          -- Note that this can occur before the first 'valid' if 'beat_index_to_set_drop' is 0.
          drop_int := to_sl(packet_beat_counter >= beat_index_to_set_drop);

        when pulse_in_frame =>
          if beat_index_to_set_drop = 0 then
            -- When we are to pulse 'drop' on the first beat, we have wait for the packet
            -- to actually start.
            -- A pulse before a packet should not drop anything.
            drop_int := (
              input_valid
              and to_sl(packet_beat_counter = 0)
              and not drop_has_been_high_this_packet
            );

          else
            -- When 'drop' should be pulsed in the middle of a packet however, we do not
            -- look at 'valid'.
            -- A pulse anywhere when a packet has been started should drop it.
            drop_int := (
              to_sl(packet_beat_counter >= beat_index_to_set_drop)
              and not drop_has_been_high_this_packet
            );
          end if;

      end case;

      drop <= drop_int or drop_explicit;
    end process;

  end block;


  ------------------------------------------------------------------------------
  input_block : block
    constant stall_config : stall_configuration_t := (
      stall_probability => 0.2,
      min_stall_cycles => 1,
      max_stall_cycles => 4
    );
  begin

    ------------------------------------------------------------------------------
    axi_stream_master_inst : entity bfm.axi_stream_master
      generic map (
        data_width => input_data'length,
        data_queue => input_data_queue,
        stall_config => stall_config,
        logger_name_suffix => " - input",
        seed => seed
      )
      port map (
        clk => clk,
        --
        ready => input_ready,
        valid => input_valid,
        last => input_last,
        data => input_data,
        strobe => input_strobe
      );

  end block;


  ------------------------------------------------------------------------------
  result_block : block
    -- Use more stalling on the result side, so it is likely that there will be some packet
    -- build up in the FIFO.
    -- This will tests that packets that have already been written will not be dropped.
    constant stall_config : stall_configuration_t := (
      stall_probability => 0.5,
      min_stall_cycles => 2,
      max_stall_cycles => 8
    );
  begin

    ------------------------------------------------------------------------------
    axi_stream_slave_inst : entity bfm.axi_stream_slave
      generic map (
        data_width => result_data'length,
        reference_data_queue => reference_data_queue,
        stall_config => stall_config,
        logger_name_suffix => " - result",
        seed => seed
      )
      port map (
        clk => clk,
        --
        ready => result_ready,
        valid => result_valid,
        last => result_last,
        data => result_data,
        strobe => result_strobe,
        --
        num_packets_checked => num_packets_checked
      );

  end block;


  ------------------------------------------------------------------------------
  dut : entity work.clean_packet_dropper
    generic map (
      data_width => data_width,
      fifo_depth => fifo_depth
    )
    port map (
      clk => clk,
      --
      drop => drop,
      --
      input_ready => input_ready,
      input_valid => input_valid,
      input_last => input_last,
      input_data => input_data,
      input_strobe => input_strobe,
      --
      result_ready => result_ready,
      result_valid => result_valid,
      result_last => result_last,
      result_data => result_data,
      result_strobe => result_strobe
    );

end architecture;
