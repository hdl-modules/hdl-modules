-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the tsfpga project.
-- https://tsfpga.com
-- https://gitlab.com/tsfpga/tsfpga
-- -------------------------------------------------------------------------------------------------
-- Test AXI clock domain crossing by running transactions through a
-- axi_read/write_cdc -> axi_read/write_throttle chain. The tests run are not very exhaustive,
-- it is more of a connectivity test.
-- -------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
use vunit_lib.memory_pkg.all;
context vunit_lib.vunit_context;
context vunit_lib.vc_context;

library osvvm;
use osvvm.RandomPkg.all;

library bfm;

use work.axi_pkg.all;


entity tb_axi_cdc is
  generic (
    input_clk_fast : boolean := false;
    output_clk_fast : boolean := false;
    max_burst_length_beats : positive;
    runner_cfg : string
  );
end entity;

architecture tb of tb_axi_cdc is

  constant id_width : natural := 5;
  constant addr_width : positive := 24;
  constant data_width : positive := 32;
  constant num_words : positive := 1000;

  constant clk_fast_period : time := 3 ns;
  constant clk_slow_period : time := 7 ns;

  signal clk_input, clk_output : std_logic := '0';

  signal input_read_m2s : axi_read_m2s_t := axi_read_m2s_init;
  signal input_read_s2m : axi_read_s2m_t := axi_read_s2m_init;

  signal input_write_m2s : axi_write_m2s_t := axi_write_m2s_init;
  signal input_write_s2m : axi_write_s2m_t := axi_write_s2m_init;

  constant axi_master : bus_master_t := new_bus(
    data_length => data_width,
    address_length => input_read_m2s.ar.addr'length
  );

  constant memory : memory_t := new_memory;
  constant axi_slave : axi_slave_t := new_axi_slave(
    memory => memory,
    address_fifo_depth => 4,
    write_response_fifo_depth => 4,
    address_stall_probability => 0.3,
    data_stall_probability => 0.3,
    write_response_stall_probability => 0.3,
    min_response_latency => 8 * clk_fast_period,
    max_response_latency => 16 * clk_slow_period,
    logger => get_logger("axi_slave")
  );

begin

  clk_input_gen : if input_clk_fast generate
    clk_input <= not clk_input after clk_fast_period / 2;
  else generate
    clk_input <= not clk_input after clk_slow_period / 2;
  end generate;

  clk_output_gen : if output_clk_fast generate
    clk_output <= not clk_output after clk_fast_period / 2;
  else generate
    clk_output <= not clk_output after clk_slow_period / 2;
  end generate;

  test_runner_watchdog(runner, 1 ms);


  ------------------------------------------------------------------------------
  main : process
    variable rnd : RandomPType;
    variable data : std_logic_vector(data_width - 1 downto 0);
    variable address : integer;
    variable buf : buffer_t;
  begin
    test_runner_setup(runner, runner_cfg);
    rnd.InitSeed(rnd'instance_name);

    buf := allocate(memory, 4 * num_words);

    if run("test_read") then
      for idx in 0 to num_words - 1 loop
        address := 4 * idx;
        data := rnd.RandSlv(data'length);
        write_word(memory, address, data);

        check_bus(net, axi_master, address, data);
      end loop;

    elsif run("test_write") then
      for idx in 0 to num_words - 1 loop
        address := 4 * idx;
        data := rnd.RandSlv(data'length);
        set_expected_word(memory, address, data);

        write_bus(net, axi_master, address, data);
      end loop;

      wait_until_idle(net, as_sync(axi_master));
      check_expected_was_written(memory);
    end if;

    test_runner_cleanup(runner);
  end process;


  ------------------------------------------------------------------------------
  axi_master_inst : entity bfm.axi_master
    generic map (
      bus_handle => axi_master
    )
    port map (
      clk => clk_input,
      --
      axi_read_m2s => input_read_m2s,
      axi_read_s2m => input_read_s2m,
      --
      axi_write_m2s => input_write_m2s,
      axi_write_s2m => input_write_s2m
    );


  ------------------------------------------------------------------------------
  read_block : block
    signal resynced_m2s, throttled_m2s : axi_read_m2s_t := axi_read_m2s_init;
    signal resynced_s2m, throttled_s2m : axi_read_s2m_t := axi_read_s2m_init;

    constant data_fifo_depth : positive := 1024;
    signal data_fifo_level : integer range 0 to data_fifo_depth := 0;
  begin

    ------------------------------------------------------------------------------
    axi_read_cdc_inst : entity work.axi_read_cdc
      generic map (
        id_width => id_width,
        addr_width => addr_width,
        data_width => data_width,
        enable_data_fifo_packet_mode => false,
        data_fifo_depth => data_fifo_depth,
        address_fifo_depth => 32
      )
      port map (
        clk_input => clk_input,
        input_m2s => input_read_m2s,
        input_s2m => input_read_s2m,
        --
        clk_output => clk_output,
        output_m2s => resynced_m2s,
        output_s2m => resynced_s2m,
        output_data_fifo_level => data_fifo_level
      );


    ------------------------------------------------------------------------------
    axi_read_throttle_inst : entity work.axi_read_throttle
      generic map (
        data_fifo_depth => data_fifo_depth,
        max_burst_length_beats => max_burst_length_beats,
        id_width => id_width,
        addr_width => addr_width,
        full_ar_throughput => false
      )
      port map (
        clk => clk_output,
        --
        data_fifo_level => data_fifo_level,
        --
        input_m2s => resynced_m2s,
        input_s2m => resynced_s2m,
        --
        throttled_m2s => throttled_m2s,
        throttled_s2m => throttled_s2m
      );


    ------------------------------------------------------------------------------
    axi_read_slave_wrapper_inst : entity bfm.axi_read_slave
      generic map (
        axi_slave => axi_slave,
        data_width => data_width,
        id_width => id_width
      )
      port map (
        clk => clk_output,
        --
        axi_read_m2s => throttled_m2s,
        axi_read_s2m => throttled_s2m
      );

  end block;


  ------------------------------------------------------------------------------
  write_block : block
    signal resynced_m2s, throttled_m2s : axi_write_m2s_t := axi_write_m2s_init;
    signal resynced_s2m, throttled_s2m : axi_write_s2m_t := axi_write_s2m_init;

    constant data_fifo_depth : positive := 1024;
    signal data_fifo_level : integer range 0 to data_fifo_depth := 0;
  begin

    ------------------------------------------------------------------------------
    axi_write_cdc_inst : entity work.axi_write_cdc
      generic map (
        id_width => id_width,
        addr_width => addr_width,
        data_width => data_width,
        enable_data_fifo_packet_mode => true,
        address_fifo_depth => 32,
        data_fifo_depth => data_fifo_depth,
        response_fifo_depth => 32
      )
      port map (
        clk_input => clk_input,
        input_m2s => input_write_m2s,
        input_s2m => input_write_s2m,
        --
        clk_output => clk_output,
        output_m2s => resynced_m2s,
        output_s2m => resynced_s2m,
        output_data_fifo_level => data_fifo_level
      );


    ------------------------------------------------------------------------------
    axi_write_throttle_inst : entity work.axi_write_throttle
      generic map (
        data_fifo_depth => data_fifo_depth,
        max_burst_length_beats => max_burst_length_beats,
        id_width => id_width,
        addr_width => addr_width,
        full_aw_throughput => false
      )
      port map (
        clk => clk_output,
        --
        data_fifo_level => data_fifo_level,
        --
        input_m2s => resynced_m2s,
        input_s2m => resynced_s2m,
        --
        throttled_m2s => throttled_m2s,
        throttled_s2m => throttled_s2m
      );


    ------------------------------------------------------------------------------
    axi_write_slave_wrapper_inst : entity bfm.axi_write_slave
      generic map (
        axi_slave => axi_slave,
        data_width => data_width,
        id_width => id_width
      )
      port map (
        clk => clk_output,
        --
        axi_write_m2s => throttled_m2s,
        axi_write_s2m => throttled_s2m
      );

  end block;

end architecture;
