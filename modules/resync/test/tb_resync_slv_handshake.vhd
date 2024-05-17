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


entity tb_resync_slv_handshake is
  generic (
    seed : natural;
    data_width : positive;
    input_clock_is_faster : boolean;
    result_clock_is_faster : boolean;
    runner_cfg : string
  );
end entity;

architecture tb of tb_resync_slv_handshake is

  signal input_clk, input_ready, input_valid : std_ulogic := '0';
  signal result_clk, result_ready, result_valid : std_ulogic := '0';
  signal input_data, result_data : std_ulogic_vector(data_width - 1 downto 0) := (others => '0');

  -- Testbench stuff
  constant stall_config : stall_configuration_t := (
    stall_probability => 0.2,
    min_stall_cycles => 1,
    -- Very high, so that level resync back and forth is guaranteed to happen.
    max_stall_cycles => 20
  );

  constant input_queue, result_queue : queue_t := new_queue;

begin

  test_runner_watchdog(runner, 2 ms);

  clocks_gen : if read_clock_is_faster generate
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
      data_width => input_data'length,
      data_queue => input_queue,
      stall_config => stall_config,
      seed => seed,
      logger_name_suffix => " - input"
    )
    port map (
      clk => input_clk,
      --
      ready => input_ready,
      valid => input_valid,
      data => input_data
    );


  ------------------------------------------------------------------------------
  axi_stream_slave_inst : entity bfm.axi_stream_slave
    generic map (
      data_width => result_data'length,
      reference_data_queue => result_queue,
      stall_config => stall_config,
      seed => seed,
      logger_name_suffix => " - result",
      disable_last_check => true
    )
    port map (
      clk => result_clk,
      --
      ready => result_ready,
      valid => result_valid,
      data => result_data,
      --
      num_packets_checked => num_packets_checked
    );


  ------------------------------------------------------------------------------
  dut : entity work.resync_slv_handshake
    generic map (
      data_width => data_width
    )
    port map (
      input_clk => input_clk,
      input_ready => input_ready,
      input_valid => input_valid,
      input_data => input_data,
      --
      result_clk => clk_write,
      result_ready => result_ready,
      result_valid => result_valid,
      result_data => result_data
    );

end architecture;
