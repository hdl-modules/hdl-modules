-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the tsfpga project.
-- https://tsfpga.com
-- https://gitlab.com/tsfpga/tsfpga
-- -------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library osvvm;
use osvvm.RandomPkg.all;

library vunit_lib;
use vunit_lib.axi_stream_pkg.all;
use vunit_lib.sync_pkg.all;
context vunit_lib.com_context;
context vunit_lib.vunit_context;

library bfm;

library common;
use common.types_pkg.all;


entity tb_fifo is
  generic (
    depth : integer;
    almost_full_level : integer := 0;
    almost_empty_level : integer := 0;
    read_stall_probability_percent : integer := 0;
    write_stall_probability_percent : integer := 0;
    enable_last : boolean := false;
    enable_packet_mode : boolean := false;
    enable_drop_packet : boolean := false;
    enable_peek_mode : boolean := false;
    runner_cfg : string
  );
end entity;

architecture tb of tb_fifo is

  constant width : integer := 8;

  signal clk : std_logic := '0';
  signal level : integer;

  signal read_ready, read_valid, read_last, read_peek_mode, almost_empty : std_logic := '0';
  signal write_ready, write_valid, write_last, almost_full : std_logic := '0';
  signal read_data, write_data : std_logic_vector(width - 1 downto 0) := (others => '0');
  signal drop_packet : std_logic := '0';

  signal has_gone_full_times, has_gone_empty_times : integer := 0;

  constant read_stall_config : stall_config_t := new_stall_config(
    stall_probability => real(read_stall_probability_percent) / 100.0,
    min_stall_cycles => 1,
    max_stall_cycles => 3
  );
  constant write_stall_config : stall_config_t := new_stall_config(
    stall_probability => real(write_stall_probability_percent) / 100.0,
    min_stall_cycles => 1,
    max_stall_cycles => 3
  );

  constant write_data_queue, write_last_queue, read_data_queue, read_last_queue : queue_t :=
    new_queue;

  signal stimuli_inactive, read_is_ready : std_logic := '0';

begin

  test_runner_watchdog(runner, 1 ms);
  clk <= not clk after 2 ns;


  ------------------------------------------------------------------------------
  main : process

    variable rnd : RandomPType;

    procedure run_read(count : natural; wait_for_status_to_update : boolean := true) is
      variable last_expected : std_logic := '0';
    begin
      for read_idx in 0 to count - 1 loop
        read_is_ready <= '1';
        wait until (read_ready and read_valid) = '1' and rising_edge(clk);

        check_equal(read_data, pop_std_ulogic_vector(read_data_queue), "read_idx=" & to_string(read_idx));

        last_expected := pop(read_last_queue);
        if enable_last then
          check_equal(read_last, last_expected, "read_idx=" & to_string(read_idx));
        end if;
      end loop;
      read_is_ready <= '0';

      if wait_for_status_to_update then
        -- Wait one cycle for read_valid to fall and counters to update
        wait until rising_edge(clk);
      end if;
    end procedure;

    procedure run_write(
      count : natural;
      set_last_flag : boolean := true;
      wait_until_done : boolean := true
    ) is
      variable data : std_logic_vector(write_data'range);
      variable last : std_logic := '0';
    begin
      for write_idx in 0 to count - 1 loop
        data := rnd.RandSLV(data'length);
        last := to_sl(write_idx = count - 1 and set_last_flag);

        push(write_data_queue, data);
        push(write_last_queue, last);

        push(read_data_queue, data);
        push(read_last_queue, last);
      end loop;

      if wait_until_done then
        wait until is_empty(write_data_queue) and rising_edge(clk);
        wait until stimuli_inactive = '1' and rising_edge(clk);
      end if;
    end procedure;

    procedure run_test(read_count, write_count : natural) is
    begin
      run_write(count=>write_count, wait_until_done=>false);
      run_read(read_count);
    end procedure;

    procedure clear_queue(queue : queue_t) is
      variable dummy : character;
    begin
      while not is_empty(queue) loop
        dummy := unsafe_pop(queue);
      end loop;
    end procedure;

    procedure pulse_drop_packet is
    begin
      drop_packet <= '1';
      wait until rising_edge(clk);
      drop_packet <= '0';
    end procedure;

    constant null_data : std_logic_vector(width - 1 downto 0) := (others => '0');
    constant one : std_logic := '1';
    constant zero : std_logic := '0';

    -- For peek mode test, which is handled differently than the other tests
    constant num_packets : positive := 12;
    variable num_peek_iterations : positive := 1;
    variable num_words : positive := 1;
    variable data : std_logic_vector(write_data'range);
    variable last : std_logic := '0';

  begin
    test_runner_setup(runner, runner_cfg);
    rnd.InitSeed(rnd'instance_name);

    -- Some tests leave data unread in the FIFO
    disable(get_logger("handshake_slave:rule 9"), error);


    if run("test_init_state") then
      check_equal(read_valid, '0');
      check_equal(write_ready, '1');
      check_equal(almost_full, '0');
      check_equal(almost_empty, '1');

      wait until
        read_valid'event or write_ready'event or almost_full'event or almost_empty'event
        for 1 us;

      check_equal(read_valid, '0');
      check_equal(write_ready, '1');
      check_equal(almost_full, '0');
      check_equal(almost_empty, '1');

    elsif run("test_write_faster_than_read") then
      run_test(5000, 5000);
      check_true(is_empty(read_data_queue));
      check_relation(has_gone_full_times > 500, "Got " & to_string(has_gone_full_times));

    elsif run("test_read_faster_than_write") then
      run_test(5000, 5000);
      check_true(is_empty(read_data_queue));
      check_relation(has_gone_empty_times > 500, "Got " & to_string(has_gone_empty_times));

    elsif run("test_packet_mode") then
      -- Write and immediately read a short packet
      run_test(read_count=>1, write_count=>1);

      -- Write a few words, without setting last
      run_write(count=>3, set_last_flag=>false);
      check_relation(level > 0);
      check_equal(read_valid, False);

      -- Writing another word, with last set, shall enable read valid.
      run_write(count=>1);
      -- Takes one cycle extra to propagate in packet mode.
      wait until rising_edge(clk);
      check_equal(read_valid, True);

      -- Write further packets
      for i in 1 to 3 loop
        run_test(read_count=>0, write_count=>4);
        check_equal(read_valid, True);
      end loop;

      -- Read and check all the packets (will only work if read_valid is set properly)
      run_read(4 * 4);
      check_equal(read_valid, False);
      check_equal(level, 0);

      -- Write a few words, without setting last
      run_write(count=>3, set_last_flag=>false);
      check_relation(level > 0);
      check_equal(read_valid, False);

      -- Writing another word, with last set, shall enable read valid.
      run_write(count=>1);
      -- Takes one cycle extra to propagate in packet mode.
      wait until rising_edge(clk);
      check_equal(read_valid, True);

      -- Read the last word to finish test
      run_read(4);

    elsif run("test_packet_mode_deep") then
      -- Show that the FIFO can be filled with lasts

      -- Fill the FIFO with lasts
      for i in 1 to depth loop
        run_write(count=>1, set_last_flag=>true);
      end loop;
      check_equal(read_valid, True);

      run_read(1);
      check_equal(read_valid, True);

      run_write(1);
      check_equal(read_valid, True);

      run_read(depth);
      check_equal(read_valid, False);

      -- Fill the FIFO with lasts again
      for i in 1 to depth loop
        run_write(count=>1, set_last_flag=>true);
      end loop;
      check_equal(read_valid, True);

      run_read(depth - 1);
      check_equal(read_valid, True);

      run_read(1);
      check_equal(read_valid, False);

    elsif run("test_drop_packet_random_data") then
      -- Write and read some data, to make the pointers advance a little.
      -- Note that this will set write_last on the last write, and some data will be left unread.
      run_test(read_count=>depth / 2, write_count=>depth * 3 / 4);
      check_equal(level, depth / 4);

      -- Write some data without setting last, simulating a packet in progress.
      -- Drop the packet, and then read out the remainder of the previous packet.
      -- Note that the counts chosen will make the pointers wraparound.
      run_write(count=>depth / 2, set_last_flag=>false);
      pulse_drop_packet;
      run_read(depth / 4);

      check_equal(read_valid, '0');
      check_equal(level, 0);

      -- Clear the data in the reference queues. This will be the data that was written, and then
      -- cleared. Hence it was never read and therefore the data is left in the queues.
      clear_queue(read_data_queue);
      clear_queue(read_last_queue);

      -- Write and verify a packet. Should be the only thing remaining in the FIFO.
      run_write(4);
      check_equal(level, 4);

      run_read(4);
      check_equal(read_valid, '0');
      check_equal(level, 0);

    elsif run("test_drop_packet_in_same_cycle_as_write_last_should_drop_the_packet") then
      check_equal(level, 0);

      push(write_data_queue, null_data);
      push(write_last_queue, zero);
      push(write_data_queue, null_data);
      push(write_last_queue, one);

      -- Time the behavior of the handshake master. Appears to be a one cycle delay.
      wait until rising_edge(clk);

      -- The first write happens at this rising edge.
      wait until rising_edge(clk);

      -- Set drop signal on same cycle as the "last" write
      drop_packet <= '1';
      wait until rising_edge(clk);

      check_equal(level, 1);
      check_equal(write_ready and write_valid and write_last and drop_packet, '1');
      wait until rising_edge(clk);

      -- Make sure the packet was dropped
      check_equal(level, 0);
      check_equal(read_valid, '0');
      wait until rising_edge(clk);
      check_equal(read_valid, '0');

    elsif run("test_almost_full") then
      check_equal(almost_full, '0');

      run_write(almost_full_level - 1);
      check_equal(almost_full, '0');

      run_write(1);
      check_equal(almost_full, '1');

      run_read(1);
      if almost_full_level = depth then
        -- One cycle more latency in this configuration
        check_equal(almost_full, '1');
        wait until rising_edge(clk);
      end if;
      check_equal(almost_full, '0');

    elsif run("test_almost_empty") then
      check_equal(almost_empty, '1');

      run_write(almost_empty_level);
      check_equal(almost_empty, '1');

      run_write(1);
      if almost_empty_level = 0 then
        -- One cycle more latency in this configuration
        check_equal(almost_empty, '1');
        wait until rising_edge(clk);
      end if;
      check_equal(almost_empty, '0');

      run_read(1);
      check_equal(almost_empty, '1');

    elsif run("test_peek_mode") then
      for packet_idx in 0 to num_packets - 1 loop
        num_words := depth / 4 + packet_idx;

        -- Push stimuli data to write queue.
        rnd.InitSeed(rnd'instance_name & to_string(packet_idx));

        for write_idx in 0 to num_words - 1 loop
          data := rnd.RandSLV(data'length);
          last := to_sl(write_idx = num_words - 1);

          push(write_data_queue, data);
          push(write_last_queue, last);
        end loop;

        -- Push the same data to read reference queue a couple of times. One time extra for each
        -- time we will read the packet with peek mode.
        num_peek_iterations := 1 + (packet_idx mod 3);
        for peek_iteration in 0 to num_peek_iterations - 1 loop
          -- Set known seed to get same data as is pushed to write queue.
          rnd.InitSeed(rnd'instance_name & to_string(packet_idx));

          for write_idx in 0 to num_words - 1 loop
            data := rnd.RandSlv(data'length);
            last := to_sl(write_idx = num_words - 1);

            push(read_data_queue, data);
            push(read_last_queue, last);
          end loop;
        end loop;
      end loop;

      -- Read out all the data
      for packet_idx in 0 to num_packets - 1 loop
        num_words := depth / 4 + packet_idx;

        -- Read each packet a number of times. But actually pop data only on the last iteration.
        num_peek_iterations := 1 + (packet_idx mod 3);
        for peek_iteration in 0 to num_peek_iterations - 1 loop
          report "peek_iteration=" & to_string(peek_iteration) ;
          read_peek_mode <= to_sl(peek_iteration /= num_peek_iterations - 1);
          run_read(num_words, wait_for_status_to_update=>rnd.RandInt(1) = 0);
        end loop;
      end loop;

    end if;

    test_runner_cleanup(runner, allow_disabled_errors=>true);
  end process;


  ------------------------------------------------------------------------------
  stimuli_block : block
    signal data_is_valid : std_logic := '0';
  begin

    stimuli_inactive <= not data_is_valid;

    ------------------------------------------------------------------------------
    write_data_stimuli : process
    begin
      while is_empty(write_data_queue) loop
        wait until rising_edge(clk);
      end loop;

      data_is_valid <= '1';

      write_data <= pop(write_data_queue);
      write_last <= pop(write_last_queue);
      wait until (write_ready and write_valid) = '1' and rising_edge(clk);

      data_is_valid <= '0';
    end process;


    ------------------------------------------------------------------------------
    handshake_master_inst : entity bfm.handshake_master
      generic map (
        stall_config => write_stall_config
      )
      port map (
        clk => clk,
        --
        data_is_valid => data_is_valid,
        --
        ready => write_ready,
        valid => write_valid
      );

  end block;


  ------------------------------------------------------------------------------
  handshake_slave_inst : entity bfm.handshake_slave
    generic map (
      stall_config => read_stall_config,
      data_width => read_data'length
    )
    port map (
      clk => clk,
      --
      data_is_ready => read_is_ready,
      --
      ready => read_ready,
      valid => read_valid,
      last => read_last or to_sl(not enable_last),
      data => read_data
    );


  ------------------------------------------------------------------------------
  status_tracking : process
    variable read_transaction, write_transaction : std_logic := '0';
  begin
    wait until rising_edge(clk);

    -- If there was a read transaction last clock cycle, and we now want to read but there is no
    -- data available.
    if read_transaction and read_ready and not read_valid then
      has_gone_empty_times <= has_gone_empty_times + 1;
    end if;

    -- If there was a write transaction last clock cycle, and we now want to write but the fifo
    -- is full.
    if write_transaction and write_valid and not write_ready then
      has_gone_full_times <= has_gone_full_times + 1;
    end if;

    read_transaction := read_ready and read_valid;
    write_transaction := write_ready and write_valid;
  end process;


  ------------------------------------------------------------------------------
  dut : entity work.fifo
    generic map (
      width => width,
      depth => depth,
      almost_full_level => almost_full_level,
      almost_empty_level => almost_empty_level,
      enable_last => enable_last,
      enable_packet_mode => enable_packet_mode,
      enable_drop_packet => enable_drop_packet,
      enable_peek_mode => enable_peek_mode
    )
    port map (
      clk => clk,
      level => level,

      read_ready => read_ready,
      read_valid => read_valid,
      read_data => read_data,
      read_last => read_last,
      read_peek_mode => read_peek_mode,
      almost_empty => almost_empty,

      write_ready => write_ready,
      write_valid => write_valid,
      write_data => write_data,
      write_last => write_last,
      almost_full => almost_full,
      drop_packet => drop_packet
    );

end architecture;
