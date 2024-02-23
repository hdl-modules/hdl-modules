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
use ieee.numeric_std.all;

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


entity tb_asynchronous_fifo is
  generic (
    seed : natural;
    depth : positive;
    read_clock_is_faster : boolean;
    almost_empty_level : natural := 0;
    almost_full_level : natural := 0;
    read_stall_probability_percent : natural := 20;
    write_stall_probability_percent : natural := 20;
    enable_packet_mode : boolean := false;
    enable_last : boolean := false;
    enable_drop_packet : boolean := false;
    enable_output_register : boolean := false;
    runner_cfg : string
  );
end entity;

architecture tb of tb_asynchronous_fifo is

  -- Generic constants
  constant width : positive := 8;

  -- DUT ports
  signal clk_read, clk_write : std_ulogic := '0';

  signal read_ready, read_valid, read_last : std_ulogic := '0';
  signal write_ready, write_valid, write_last : std_ulogic := '0';
  signal read_data, write_data : std_ulogic_vector(width - 1 downto 0) := (others => '0');

  signal read_level, write_level : natural range 0 to depth := 0;
  signal read_almost_empty, write_almost_full : std_ulogic := '0';

  signal drop_packet : std_ulogic := '0';

  -- Testbench stuff
  constant read_stall_config : stall_configuration_t := (
    stall_probability => real(read_stall_probability_percent) / 100.0,
    min_stall_cycles => 1,
    max_stall_cycles => 4
  );

  constant write_stall_config : stall_configuration_t := (
    stall_probability => real(write_stall_probability_percent) / 100.0,
    min_stall_cycles => 1,
    max_stall_cycles => 4
  );

  constant write_queue, read_queue : queue_t := new_queue;

  signal num_beats_written, num_packets_written, num_packets_read : natural := 0;
  signal has_gone_full_times, has_gone_empty_times : natural := 0;

  signal enable_read : std_ulogic := '1';

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

    variable rnd : RandomPType;

    variable expected_num_packets_written, expected_num_packets_read : natural := 0;

    procedure run_test(
      num_beats : natural;
      push_packet_to_checker_times : natural := 1
    ) is
      constant num_bytes : natural := num_beats * width / 8;
      variable data, data_copy : integer_array_t := null_integer_array;
    begin
      if num_beats > 0 then
        random_integer_array(
          rnd => rnd,
          integer_array => data,
          width => num_bytes,
          bits_per_word => 8,
          is_signed => false
        );

        for packet_check_idx in 0 to push_packet_to_checker_times - 1 loop
          data_copy := copy(data);
          push_ref(read_queue, data_copy);

          expected_num_packets_read := expected_num_packets_read + 1;
        end loop;

        push_ref(write_queue, data);

        expected_num_packets_written := expected_num_packets_written + 1;
      end if;
    end procedure;

    procedure wait_until_write_done is
    begin
      wait until num_packets_written = expected_num_packets_written and rising_edge(clk_write);
    end procedure;

    procedure wait_until_done is
    begin
      wait until num_packets_written = expected_num_packets_written
        and num_packets_read = expected_num_packets_read
        and rising_edge(clk_read);
    end procedure;

    procedure wait_for_read_to_propagate is
    begin
      wait until rising_edge(clk_write);
      wait until rising_edge(clk_write);
      wait until rising_edge(clk_write);
      wait until rising_edge(clk_write);
    end procedure;

    procedure wait_for_write_to_propagate is
    begin
      wait until rising_edge(clk_read);
      wait until rising_edge(clk_read);
      wait until rising_edge(clk_read);
      wait until rising_edge(clk_read);

      if enable_output_register then
        wait until rising_edge(clk_read);
      end if;
    end procedure;

    procedure pulse_drop_packet is
    begin
      drop_packet <= '1';
      wait until rising_edge(clk_write);
      drop_packet <= '0';
    end procedure;

  begin
    test_runner_setup(runner, runner_cfg);
    rnd.InitSeed(seed);

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
      for packet_idx in 0 to 1000 loop
        run_test(num_beats=>rnd.Uniform(1, 5));
      end loop;

      wait_until_done;
      check_relation(has_gone_full_times > 200, "Got " & to_string(has_gone_full_times));

    elsif run("test_read_faster_than_write") then
      for packet_idx in 0 to 1000 loop
        run_test(num_beats=>rnd.Uniform(1, 5));
      end loop;

      wait_until_done;
      check_relation(has_gone_empty_times > 200, "Got " & to_string(has_gone_empty_times));

    elsif run("test_packet_mode_random_data") then
      for packet_idx in 0 to 1000 loop
        run_test(num_beats=>rnd.Uniform(1, 5));
      end loop;

    elsif run("test_packet_mode_status") then
      -- Start writing a packet and check status is the middle
      enable_read <= '0';
      run_test(num_beats=>depth - 1);

      wait until num_beats_written = depth - 2 and rising_edge(clk_write);
      check_relation(write_level > 0);
      check_equal(read_valid, False);

      -- Allow the test to finish
      enable_read <= '1';

    elsif run("test_packet_mode_deep") then
      -- Show that the FIFO can be filled with lasts

      -- Fill the FIFO with lasts
      enable_read <= '0';

      for beat_idx in 1 to depth loop
        run_test(num_beats=>1);
      end loop;
      wait_until_write_done;

      enable_read <= '1';
      wait until read_ready and read_valid and rising_edge(clk_read);
      enable_read <= '0';

      run_test(num_beats=>1);
      wait_until_write_done;

      enable_read <= '1';
      wait_until_done;

      -- Fill the FIFO with lasts again
      enable_read <= '0';
      for i in 1 to depth loop
        run_test(num_beats=>1);
      end loop;
      wait_until_write_done;

      enable_read <= '1';
      wait_until_done;

      wait until rising_edge(clk_read);
      check_equal(read_valid, '0');

    elsif run("test_drop_packet_mode_read_level_should_be_zero") then
      run_test(num_beats=>4);
      wait_until_write_done;
      wait_for_write_to_propagate;

      check_equal(read_level, 0);

    elsif run("test_drop_packet_random_data") then
      -- Write and read some data, to make the pointers advance a little.
      run_test(num_beats=>depth * 3 / 4);
      -- Write another packet, which we will drop so it is not pushed to checker.
      -- Note that the length chosen will make the write pointer wraparound.
      run_test(num_beats=>depth / 2, push_packet_to_checker_times=>0);

      -- Wait until the first packet is fully written
      wait until write_ready and write_valid and write_last and rising_edge(clk_write);
      wait until rising_edge(clk_write);
      -- Set drop_packet on the very last beat of the second packet.
      -- The whole second packet should be dropped.
      wait until write_ready and write_valid and write_last;
      pulse_drop_packet;

      -- Write and verify a clean packet. Should be the only thing remaining in the FIFO.
      wait_until_done;
      enable_read <= '0';
      run_test(num_beats=>4);
      wait_until_write_done;

      if enable_output_register then
        -- With output register enabled, write level is pessimistic when there is nothing currently
        -- in the output register.
        check_equal(write_level, 5);
        -- When output register is enabled, it is a long roundtrip before the actual level value
        -- gets presented on the write side.
        -- The write address is resynced to read domain, which triggers a read from RAM into output
        -- register, then the updated read address is resynced back to write domain, which then
        -- updates the level.
        wait_for_read_to_propagate;
        wait_for_write_to_propagate;
      end if;
      -- Level should be correct.
      check_equal(write_level, 4);

      enable_read <= '1';
      wait_until_done;
      check_equal(read_valid, '0');
      wait_for_read_to_propagate;
      check_equal(write_level, to_int(enable_output_register));

    elsif run("test_levels_full_range") then
      -- Check empty status
      -- If output register is used, write_level is always 1 as the lowest
      check_equal(write_level, to_int(enable_output_register));
      check_equal(read_level, 0);

      -- Fill the FIFO
      enable_read <= '0';
      run_test(num_beats=>depth);
      wait_until_write_done;

      -- Check full status. Must wait a while before all writes have propagated to read side.
      check_equal(write_level, depth);
      wait_for_write_to_propagate;
      check_equal(read_level, depth);

      -- Empty the FIFO
      enable_read <= '1';
      wait_until_done;

      -- Check empty status. Must wait a while before all reads have propagated to write side.
      check_equal(read_level, 0);
      wait_for_read_to_propagate;
      check_equal(write_level, to_int(enable_output_register));

    elsif run("test_write_almost_full") then
      check_equal(write_almost_full, '0');

      enable_read <= '0';
      run_test(num_beats=>almost_full_level - 1);
      wait_until_write_done;
      check_equal(write_almost_full, '0');

      run_test(num_beats=>1);
      wait_until_write_done;
      check_equal(write_almost_full, '1');

      enable_read <= '1';
      wait until read_ready and read_valid and rising_edge(clk_read);
      wait_for_read_to_propagate;
      check_equal(write_almost_full, '0');

    elsif run("test_read_almost_empty") then
      check_equal(read_almost_empty, '1');

      enable_read <= '0';
      run_test(num_beats=>almost_empty_level);
      wait_until_write_done;
      wait_for_write_to_propagate;
      wait_for_write_to_propagate;
      check_equal(read_almost_empty, '1');

      run_test(num_beats=>1);
      wait_until_write_done;
      wait_for_write_to_propagate;
      check_equal(read_almost_empty, '0');

      enable_read <= '1';
      wait until read_ready and read_valid and rising_edge(clk_read);
      wait until rising_edge(clk_read);
      check_equal(read_almost_empty, '1');

    end if;

    wait_until_done;

    test_runner_cleanup(runner);
  end process;


  ------------------------------------------------------------------------------
  read_status_tracking : process
    variable read_transaction : std_ulogic := '0';
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
    variable write_transaction : std_ulogic := '0';
  begin
    wait until rising_edge(clk_write);

    num_beats_written <= num_beats_written + to_int(write_ready and write_valid);

    -- If there was a write transaction last clock cycle, and we now want to write but the fifo
    -- is full.
    if write_transaction and write_valid and not write_ready then
      has_gone_full_times <= has_gone_full_times + 1;
    end if;

    write_transaction := write_ready and write_valid;
  end process;


  ------------------------------------------------------------------------------
  axi_stream_master_inst : entity bfm.axi_stream_master
    generic map (
      data_width => write_data'length,
      data_queue => write_queue,
      stall_config => write_stall_config,
      seed => seed,
      logger_name_suffix => " - write"
    )
    port map (
      clk => clk_write,
      --
      ready => write_ready,
      valid => write_valid,
      last => write_last,
      data => write_data,
      --
      num_packets_sent => num_packets_written
    );


  ------------------------------------------------------------------------------
  axi_stream_slave_inst : entity bfm.axi_stream_slave
    generic map (
      data_width => read_data'length,
      reference_data_queue => read_queue,
      stall_config => read_stall_config,
      seed => seed,
      logger_name_suffix => " - read",
      disable_last_check => not enable_last
    )
    port map (
      clk => clk_read,
      --
      ready => read_ready,
      valid => read_valid,
      last => read_last,
      data => read_data,
      --
      num_packets_checked => num_packets_read,
      enable => enable_read
    );


  ------------------------------------------------------------------------------
  check_no_bubble_cycles_in_packet_mode : if enable_packet_mode or enable_drop_packet generate
    signal start_event, end_event, en : std_ulogic := '0';
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
