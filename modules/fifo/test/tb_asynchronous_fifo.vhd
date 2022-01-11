-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the hdl_modules project.
-- https://hdl-modules.com
-- https://gitlab.com/tsfpga/hdl_modules
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

library common;
use common.types_pkg.all;


entity tb_asynchronous_fifo is
  generic (
    depth : integer;
    read_clock_is_faster : boolean;
    almost_empty_level : natural := 0;
    almost_full_level : natural := 0;
    read_stall_probability_percent : integer := 0;
    write_stall_probability_percent : integer := 0;
    enable_packet_mode : boolean := false;
    enable_last : boolean := false;
    enable_drop_packet : boolean := false;
    enable_output_register : boolean := false;
    runner_cfg : string
  );
end entity;

architecture tb of tb_asynchronous_fifo is

  constant width : integer := 8;

  signal clk_read, clk_write : std_logic := '0';

  signal read_ready, read_valid, read_last : std_logic := '0';
  signal write_ready, write_valid, write_last : std_logic := '0';
  signal read_data, write_data : std_logic_vector(width - 1 downto 0) := (others => '0');

  signal read_level, write_level : integer;
  signal read_almost_empty, write_almost_full : std_logic := '0';

  signal drop_packet : std_logic := '0';

  signal has_gone_full_times, has_gone_empty_times : integer := 0;

  constant read_stall_config : stall_config_t := new_stall_config(
    stall_probability => real(read_stall_probability_percent) / 100.0,
    min_stall_cycles => 1,
    max_stall_cycles => 4);
  constant read_slave : axi_stream_slave_t := new_axi_stream_slave(
    data_length => width,
    stall_config => read_stall_config,
    protocol_checker => new_axi_stream_protocol_checker(data_length => width,
                                                        logger => get_logger("read_slave")));

  constant write_stall_config : stall_config_t := new_stall_config(
    stall_probability => real(write_stall_probability_percent) / 100.0,
    min_stall_cycles => 1,
    max_stall_cycles => 4);
  constant write_master : axi_stream_master_t := new_axi_stream_master(
    data_length => width,
    stall_config => write_stall_config,
    protocol_checker => new_axi_stream_protocol_checker(data_length => width,
                                                        logger => get_logger("write_master")));

begin

  test_runner_watchdog(runner, 2 ms);

  clocks : if read_clock_is_faster generate
    clk_read  <= not clk_read after 2 ns;
    clk_write <= not clk_write after 3 ns;
  else  generate
    clk_read  <= not clk_read after 3 ns;
    clk_write <= not clk_write after 2 ns;
  end generate;


  ------------------------------------------------------------------------------
  main : process

    variable data_queue, last_queue, axi_stream_pop_reference_queue : queue_t := new_queue;
    variable rnd : RandomPType;

    procedure run_test(read_count, write_count : natural; set_last_flag : boolean := true) is
      variable data : std_logic_vector(write_data'range);
      variable last, last_expected : std_logic := '0';
      variable axi_stream_pop_reference : axi_stream_reference_t;
    begin
      for write_idx in 0 to write_count - 1 loop
        data := rnd.RandSLV(data'length);
        last := to_sl(write_idx = write_count - 1 and set_last_flag);

        push_axi_stream(net, write_master, data, last);

        push(data_queue, data);
        push(last_queue, last);
      end loop;

      -- Queue up reads in order to get full throughput
      for read_idx in 0 to read_count - 1 loop
        pop_axi_stream(net, read_slave, axi_stream_pop_reference);
        -- We need to keep track of the pop_reference when we read the reply later.
        -- Hence it is pushed to a queue.
        push(axi_stream_pop_reference_queue, axi_stream_pop_reference);
      end loop;

      for read_idx in 0 to read_count - 1 loop
        axi_stream_pop_reference := pop(axi_stream_pop_reference_queue);
        await_pop_axi_stream_reply(net, axi_stream_pop_reference, data, last);

        check_equal(data, pop_std_ulogic_vector(data_queue), "read_idx " & to_string(read_idx));
        last_expected := pop(last_queue);
        if enable_last then
          check_equal(last, last_expected, "read_idx " & to_string(read_idx));
        end if;
      end loop;

      wait_until_idle(net, as_sync(write_master));
      wait until rising_edge(clk_write);
    end procedure;

    procedure run_read(count : natural) is
    begin
      run_test(count, 0);
    end procedure;

    procedure run_write(count : natural) is
    begin
      run_test(0, count);
    end procedure;

    procedure wait_for_read_to_propagate is
    begin
      wait until rising_edge(clk_write);
      wait until rising_edge(clk_write);
    end procedure;

    procedure wait_for_write_to_propagate is
    begin
      wait until rising_edge(clk_read);
      wait until rising_edge(clk_read);
      wait until rising_edge(clk_read);
      wait until rising_edge(clk_read);

      -- takes one extra cycle if output register is used
      if enable_output_register then
        wait until rising_edge(clk_read);
      end if;
    end procedure;

    procedure wait_for_write_level_update_after_last_written_and_output_register_is_used is
    begin
      -- Wait for num_lasts_written to propagate to write side
      wait until rising_edge(clk_write);
      wait until rising_edge(clk_read);
      wait until rising_edge(clk_read);
      -- Wait for delay from num_lasts_written_resync to read_addr update
      wait until rising_edge(clk_read);
      wait until rising_edge(clk_read);
      -- Wait for read_addr to propagate to read side
      wait until rising_edge(clk_write);
      wait until rising_edge(clk_write);
      -- Lastly wait for it to propagate into write_level
      wait until rising_edge(clk_write);
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
      wait until rising_edge(clk_write);
      drop_packet <= '0';
    end procedure;

  begin
    test_runner_setup(runner, runner_cfg);
    rnd.InitSeed(rnd'instance_name);

    -- Decrease noise
    disable(get_logger("read_slave:rule 4"), warning);
    disable(get_logger("write_master:rule 4"), warning);
    -- Some tests leave data unread in the FIFO
    disable(get_logger("read_slave:rule 9"), error);

    if run("test_init_state") then
      check_equal(read_valid, '0');
      check_equal(write_ready, '1');
      check_equal(write_almost_full, '0');
      check_equal(read_almost_empty, '1');
      wait until
        read_valid'event
        or write_ready'event
        or write_almost_full'event
        or read_almost_empty'event
        for 1 us;
      check_equal(read_valid, '0');
      check_equal(write_ready, '1');
      check_equal(write_almost_full, '0');
      check_equal(read_almost_empty, '1');

    elsif run("test_write_faster_than_read") then
      run_test(3000, 3000);
      check_relation(has_gone_full_times > 200);
      check_true(is_empty(data_queue));

    elsif run("test_read_faster_than_write") then
      run_test(3000, 3000);
      check_relation(has_gone_empty_times > 200);
      check_true(is_empty(data_queue));

    elsif run("test_packet_mode") then
      -- Write and immediately read a small packet
      run_test(read_count=>1, write_count=>1);

      -- Write a few words, without setting last
      run_test(read_count=>0, write_count=>3, set_last_flag=>false);
      wait_for_write_to_propagate;
      check_relation(read_level > 0);
      check_equal(read_valid, False);

      -- Writing another word, with last set, shall enable read valid
      run_test(read_count=>0, write_count=>1);
      wait_for_write_to_propagate;
      check_equal(read_valid, True);

      -- Write further packets
      for i in 1 to 3 loop
        run_test(read_count=>0, write_count=>4);
        check_equal(read_valid, True);
      end loop;

      -- Read and check all the packets (will only work if read_valid is set properly)
      run_read(4 * 4);
      check_equal(read_valid, False);
      check_equal(read_level, 0);

      -- Write a few words, without setting last
      run_test(read_count=>0, write_count=>3, set_last_flag=>false);
      wait_for_write_to_propagate;
      check_relation(read_level > 0);
      check_equal(read_valid, False);

      -- Writing another word, with last set, shall enable read valid
      run_test(read_count=>0, write_count=>1);
      wait_for_write_to_propagate;
      check_equal(read_valid, True);

    elsif run("test_packet_mode_deep") then
      -- Show that the FIFO can be filled with lasts and that the last counters can wrap around.

      -- Fill the FIFO with lasts
      for i in 1 to depth loop
        run_test(read_count=>0, write_count=>1, set_last_flag=>true);
      end loop;
      check_equal(read_valid, True);

      run_read(1);
      check_equal(read_valid, True);

      run_write(1);
      wait_for_write_to_propagate;
      check_equal(read_valid, True);

      run_read(depth);
      check_equal(read_valid, False);

      -- Fill the FIFO with lasts again, making the write counter wrap around
      for i in 1 to depth loop
        run_test(read_count=>0, write_count=>1, set_last_flag=>true);
      end loop;
      check_equal(read_valid, True);

      run_read(depth - 1);
      check_equal(read_valid, True);

      run_read(1);
      check_equal(read_valid, False);

    elsif run("test_drop_packet_mode_read_level_should_be_zero") then
      -- Write a couple of packets
      run_write(4);
      run_write(4);
      run_write(4);
      wait_for_write_to_propagate;

      check_equal(read_level, 0);

    elsif run("test_drop_packet_random_data") then
      -- Write and read some data, to make the pointers advance a little.
      -- Note that this will set write_last on the last write, and some data will be left unread.
      run_test(read_count=>depth / 2, write_count=>depth * 3 / 4);
      wait_for_read_to_propagate;
      -- Note: If output register is used, one value will now have been be stored in it,
      --       The level in the memory is now therefore be depth / 4 - 1, but when the output
      --       register is used, we always add 1 to the write level to be sure that it
      --       is conservative
      check_equal(write_level, depth / 4);

      -- Write some data without setting last, simulating a packet in progress.
      -- Drop the packet, and then read out the remainder of the previous packet.
      -- Note that the counts chosen will make the pointers wraparound.
      run_test(read_count=>0, write_count=>depth / 2, set_last_flag=>false);
      pulse_drop_packet;
      run_read(depth / 4);

      wait_for_read_to_propagate;
      check_equal(read_valid, '0');
      -- If output register is used, write_level is always 1 as the lowest
      check_equal(write_level, to_int(enable_output_register));

      -- Clear the data in the reference queues. This will be the data that was written, and then
      -- cleared. Hence it was never read and therefore the data is left in the queues.
      clear_queue(data_queue);
      clear_queue(last_queue);

      -- Write and verify a packet. Should be the only thing remaining in the FIFO.
      run_write(4);
      if enable_output_register then
        -- When using the output register, the level will first rise to 5, and then
        -- go pack to to 4 after one value has been pushed into the output register
        check_equal(write_level, 5);
        wait_for_write_level_update_after_last_written_and_output_register_is_used;
      end if;
      check_equal(write_level, 4);

      run_read(4);
      check_equal(read_valid, '0');
      wait_for_read_to_propagate;
      check_equal(write_level, to_int(enable_output_register));

    elsif run("test_drop_packet_in_same_cycle_as_write_last_should_drop_the_packet") then
      -- Check empty status
      -- If output register is used, write_level is always 1 as the lowest
      check_equal(write_level, to_int(enable_output_register));

      push_axi_stream(net, write_master, tdata=>x"00", tlast=>'0');
      push_axi_stream(net, write_master, tdata=>x"00", tlast=>'1');

      -- Time the behavior of the AXI-Stream master. Appears to be a one cycle delay.
      wait until rising_edge(clk_write);

      -- The first write happens at this rising edge.
      wait until rising_edge(clk_write);

      -- Set drop signal on same cycle as the "last" write
      drop_packet <= '1';
      wait until rising_edge(clk_write);

      check_equal(write_level, 1 + to_int(enable_output_register));
      check_equal(write_ready and write_valid and write_last and drop_packet, '1');
      wait until rising_edge(clk_write);

      -- Make sure the packet was dropped
      check_equal(write_level, to_int(enable_output_register));
      wait_for_write_to_propagate;
      check_equal(read_valid, '0');

    elsif run("test_levels_full_range") then
      -- Check empty status
      -- If output register is used, write_level is always 1 as the lowest
      check_equal(write_level, to_int(enable_output_register));
      check_equal(read_level, 0);

      -- Fill the FIFO
      run_write(depth);

      -- Check full status. Must wait a while before all writes have propagated to read side.
      check_equal(write_level, depth);
      wait_for_write_to_propagate;
      check_equal(read_level, depth);

      -- Empty the FIFO
      run_read(depth);

      -- Check empty status. Must wait a while before all reads have propagated to write side.
      check_equal(read_level, 0);
      wait_for_read_to_propagate;
      check_equal(write_level, to_int(enable_output_register));

    elsif run("test_write_almost_full") then
      check_equal(write_almost_full, '0');

      run_write(almost_full_level - 1);
      check_equal(write_almost_full, '0');

      run_write(1);
      check_equal(write_almost_full, '1');

      run_read(1);
      wait_for_read_to_propagate;
      check_equal(write_almost_full, '0');

    elsif run("test_read_almost_empty") then
      check_equal(read_almost_empty, '1');

      run_write(almost_empty_level);
      check_equal(read_almost_empty, '1');

      run_write(1);
      wait_for_write_to_propagate;
      check_equal(read_almost_empty, '0');

      run_read(1);
      check_equal(read_almost_empty, '1');
    end if;

    test_runner_cleanup(runner, allow_disabled_errors=>true);
  end process;


  ------------------------------------------------------------------------------
  read_status_tracking : process
    variable read_transaction : std_logic := '0';
  begin
    wait until rising_edge(clk_read);

    -- If there was a read transaction last clock cycle, and we now want to read but there is no
    -- data available.
    if read_transaction and read_ready and not read_valid then
      has_gone_empty_times <= has_gone_empty_times + 1;
    end if;

    read_transaction := read_ready and read_valid;
  end process;


  ------------------------------------------------------------------------------
  write_status_tracking : process
    variable write_transaction : std_logic := '0';
  begin
    wait until rising_edge(clk_write);

    -- If there was a write transaction last clock cycle, and we now want to write but the fifo
    -- is full.
    if write_transaction and write_valid and not write_ready then
      has_gone_full_times <= has_gone_full_times + 1;
    end if;

    write_transaction := write_ready and write_valid;
  end process;


  ------------------------------------------------------------------------------
  axi_stream_slave_inst : entity vunit_lib.axi_stream_slave
    generic map(
      slave => read_slave
    )
    port map(
      aclk => clk_read,
      tvalid => read_valid,
      tready => read_ready,
      tdata => read_data,
      tlast => read_last
    );


  ------------------------------------------------------------------------------
  axi_stream_master_inst : entity vunit_lib.axi_stream_master
    generic map(
      master => write_master)
    port map(
      aclk => clk_write,
      tvalid => write_valid,
      tready => write_ready,
      tdata => write_data,
      tlast => write_last
    );


  ------------------------------------------------------------------------------
  check_no_bubble_cycles_in_packet_mode : if enable_packet_mode or enable_drop_packet generate
    signal start_event, end_event, en : std_logic := '0';
  begin
    -- These inputs must be signals (not constants), so assign them here instead of the port
    -- map directly
    start_event <= read_valid and not read_last;
    end_event <= (read_ready and read_valid and read_last);
    en <= '1';

    check_stable(
      clock=>clk_read,
      en=>en,
      -- Start check when valid arrives
      start_event=>read_valid,
      -- End check when last arrives
      end_event=>end_event,
      -- Assert that valid is always asserted until last arrives
      expr=>read_valid,
      msg=>"There was a bubble in read_valid!"
    );
  end generate;


  ------------------------------------------------------------------------------
  dut : entity work.asynchronous_fifo
    generic map (
      width => width,
      depth => depth,
      almost_full_level => almost_full_level,
      almost_empty_level => almost_empty_level,
      -- Enable packet mode when we test drop_packet
      -- This way, we don't need to include redundant information in the test name
      enable_packet_mode => enable_packet_mode or enable_drop_packet,
      enable_last => enable_last,
      enable_drop_packet => enable_drop_packet,
      enable_output_register => enable_output_register
    )
    port map (
      clk_read => clk_read,
      read_ready   => read_ready,
      read_valid   => read_valid,
      read_data    => read_data,
      read_last    => read_last,
      --
      read_level => read_level,
      read_almost_empty => read_almost_empty,
      --
      clk_write => clk_write,
      write_ready => write_ready,
      write_valid => write_valid,
      write_data  => write_data,
      write_last  => write_last,
      --
      write_level => write_level,
      write_almost_full => write_almost_full,
      --
      drop_packet => drop_packet
    );

end architecture;
