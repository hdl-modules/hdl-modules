-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the hdl-modules project, a collection of reusable, high-quality,
-- peer-reviewed VHDL building blocks.
-- https://hdl-modules.com
-- https://github.com/hdl-modules/hdl-modules
-- -------------------------------------------------------------------------------------------------
-- Testbench for both synchronous and asynchronous hard FIFOs.
-- -------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library osvvm;
use osvvm.RandomPkg.RandomPType;

library vunit_lib;
use vunit_lib.check_pkg.all;
use vunit_lib.queue_pkg.all;
use vunit_lib.run_pkg.all;

library bfm;
use bfm.stall_bfm_pkg.stall_configuration_t;

library common;
use common.types_pkg.all;

use work.hard_fifo_pkg.all;


entity tb_hard_fifo is
  generic (
    data_width : positive;
    is_asynchronous : boolean;
    enable_output_register : boolean;
    read_clock_is_faster : boolean := false;
    read_stall_probability_percent : natural := 0;
    write_stall_probability_percent : natural := 0;
    runner_cfg : string
  );
end entity;

architecture tb of tb_hard_fifo is

  constant depth : positive := get_fifo_depth(target_width=>data_width);
  -- It appears that the synchronous FIFO can hold one extra word compared to asynchronous, in
  -- all configurations.
  constant fifo_capacity : positive :=
    depth + to_int(enable_output_register) + to_int(not is_asynchronous);

  signal clk_read, clk_write : std_ulogic := '0';

  signal read_ready, read_valid : std_ulogic := '0';
  signal write_ready, write_valid : std_ulogic := '0';
  signal read_data, write_data : std_ulogic_vector(data_width - 1 downto 0) := (others => '0');

  signal has_gone_full_times, has_gone_empty_times : natural := 0;

  constant read_stall_config : stall_configuration_t := (
    stall_probability => real(read_stall_probability_percent) / 100.0,
    min_stall_cycles => 1,
    max_stall_cycles => 3
  );
  constant write_stall_config : stall_configuration_t := (
    stall_probability => real(write_stall_probability_percent) / 100.0,
    min_stall_cycles => 1,
    max_stall_cycles => 3
  );

  constant write_data_queue, read_data_queue : queue_t := new_queue;

  signal stimuli_inactive, read_is_ready : std_ulogic := '0';

begin

  test_runner_watchdog(runner, 1 ms);


  ------------------------------------------------------------------------------
  clock_generation : if is_asynchronous generate

    clocks : if read_clock_is_faster generate
      clk_read  <= not clk_read after 2 ns;
      clk_write <= not clk_write after 3 ns;
    else  generate
      clk_read  <= not clk_read after 3 ns;
      clk_write <= not clk_write after 2 ns;
    end generate;

  else generate
    signal clk_base : std_ulogic := '0';
  begin

    assert not read_clock_is_faster report "Should not set this generic for synchronous test";

    clk_base <= not clk_base after 2 ns;

    clk_read <= clk_base;
    clk_write <= clk_base;

  end generate;


  ------------------------------------------------------------------------------
  main : process

    variable rnd : RandomPType;

    procedure wait_until_no_longer_in_reset is
    begin
      if is_asynchronous then
        wait until write_ready and rising_edge(clk_write);

        for extra_wait_cycle in 0 to 6 loop
          wait until rising_edge(clk_write);
        end loop;
      end if;
    end procedure;

    procedure run_read(count : natural) is
    begin
      read_is_ready <= '1';
      for read_idx in 0 to count - 1 loop
        wait until read_ready and read_valid and rising_edge(clk_read);
        check_equal(
          read_data,
          pop_std_ulogic_vector(read_data_queue),
          "read_idx=" & to_string(read_idx)
        );
      end loop;
      read_is_ready <= '0';
    end procedure;

    procedure run_write(count : natural; wait_until_done : boolean) is
      variable data : std_ulogic_vector(write_data'range);
    begin
      for write_idx in 0 to count - 1 loop
        data := rnd.RandSLV(data'length);
        push(write_data_queue, data);
        push(read_data_queue, data);
      end loop;

      if wait_until_done then
        wait until is_empty(write_data_queue) and rising_edge(clk_write);
        wait until stimuli_inactive and rising_edge(clk_write);
      end if;
    end procedure;

    procedure run_test(read_count, write_count : natural) is
    begin
      run_write(count=>write_count, wait_until_done=>false);
      run_read(read_count);
    end procedure;

  begin
    test_runner_setup(runner, runner_cfg);
    rnd.InitSeed(rnd'instance_name);

    if run("test_init_state") then
      -- read_valid is 'U' before the first rising edge
      wait until rising_edge(clk_read);

      check_equal(read_valid, '0');
      check_equal(write_ready, '0');

      -- write_ready rises after reset has finished
      wait until read_valid'event or write_ready'event for 1 us;
      check_equal(read_valid, '0');
      check_equal(write_ready, '1');

      -- After that nothing shall happen
      wait until read_valid'event or write_ready'event for 1 us;
      check_equal(read_valid, '0');
      check_equal(write_ready, '1');

    elsif run("test_depth") then
      wait_until_no_longer_in_reset;

      run_write(count=>fifo_capacity, wait_until_done=>true);
      check_equal(write_ready, false);
      run_read(count=>fifo_capacity);

    elsif run("test_fifo_full") then
      wait_until_no_longer_in_reset;

      -- Fill the FIFO
      run_write(count=>depth, wait_until_done=>true);
      -- Run a lot of reads and writes, with the FIFO going full a lot
      run_test(read_count=>depth + 2000, write_count=>2000);

      check_relation(has_gone_full_times > 500, "Got " & to_string(has_gone_full_times));

    elsif run("test_fifo_empty") then
      wait_until_no_longer_in_reset;

      -- Run a lot of reads and writes, with the FIFO going empty a lot
      run_test(2000, 2000);
      check_relation(has_gone_empty_times > 500, "Got " & to_string(has_gone_empty_times));

    end if;

    assert is_empty(write_data_queue);
    assert is_empty(read_data_queue);

    test_runner_cleanup(runner);
  end process;


  ------------------------------------------------------------------------------
  stimuli_block : block
    signal data_is_valid : std_ulogic := '0';
  begin

    stimuli_inactive <= not data_is_valid;

    ------------------------------------------------------------------------------
    write_data_stimuli : process
    begin
      while is_empty(write_data_queue) loop
        wait until rising_edge(clk_write);
      end loop;

      data_is_valid <= '1';

      write_data <= pop(write_data_queue);
      wait until write_ready and write_valid and rising_edge(clk_write);

      data_is_valid <= '0';
    end process;


    ------------------------------------------------------------------------------
    handshake_master_inst : entity bfm.handshake_master
      generic map (
        stall_config => write_stall_config
      )
      port map (
        clk => clk_write,
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
      stall_config => read_stall_config
    )
    port map (
      clk => clk_read,
      --
      data_is_ready => read_is_ready,
      --
      ready => read_ready,
      valid => read_valid
    );


  ------------------------------------------------------------------------------
  axi_stream_protocol_checker_inst : entity common.axi_stream_protocol_checker
    generic map (
      data_width => read_data'length
    )
    port map (
      clk => clk_read,
      --
      ready => read_ready,
      valid => read_valid,
      data => read_data
    );


  ------------------------------------------------------------------------------
  write_status_tracking : process
    variable transaction_occurred : std_ulogic := '0';
  begin
    wait until rising_edge(clk_write);

    -- If there was a write transaction last clock cycle, and we now want to write but the fifo
    -- is full.
    if transaction_occurred and write_valid and not write_ready then
      has_gone_full_times <= has_gone_full_times + 1;
    end if;

    transaction_occurred := write_ready and write_valid;
  end process;


  ------------------------------------------------------------------------------
  read_status_tracking : process
    variable transaction_occurred : std_ulogic := '0';
  begin
    wait until rising_edge(clk_read);

    -- If there was a read transaction last clock cycle, and we now want to read but there is no
    -- data available.
    if transaction_occurred and read_ready and not read_valid then
      has_gone_empty_times <= has_gone_empty_times + 1;
    end if;

    transaction_occurred := write_ready and write_valid;
  end process;


  ------------------------------------------------------------------------------
  dut_gen : if is_asynchronous generate

      ------------------------------------------------------------------------------
      dut : entity work.asynchronous_hard_fifo
        generic map (
          data_width => data_width,
          enable_output_register => enable_output_register,
          primitive_type => primitive_fifo36e2
        )
        port map (
          clk_read => clk_read,
          read_ready => read_ready,
          read_valid => read_valid,
          read_data => read_data,
          --
          clk_write => clk_write,
          write_ready => write_ready,
          write_valid => write_valid,
          write_data => write_data
        );


  else generate

    ------------------------------------------------------------------------------
    dut : entity work.hard_fifo
      generic map (
        data_width => data_width,
        enable_output_register => enable_output_register,
        primitive_type => primitive_fifo36e2
      )
      port map (
        -- read/write clock does not matter here since they are the same
        clk => clk_read,
        --
        read_ready => read_ready,
        read_valid => read_valid,
        read_data => read_data,
        --
        write_ready => write_ready,
        write_valid => write_valid,
        write_data => write_data
      );

  end generate;

end architecture;
