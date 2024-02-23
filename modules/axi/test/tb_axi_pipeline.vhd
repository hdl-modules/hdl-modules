-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the hdl-modules project, a collection of reusable, high-quality,
-- peer-reviewed VHDL building blocks.
-- https://hdl-modules.com
-- https://github.com/hdl-modules/hdl-modules
-- -------------------------------------------------------------------------------------------------
-- Test of AXI read/write pipelines
-- -------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

library osvvm;
use osvvm.RandomPkg.RandomPType;

library vunit_lib;
use vunit_lib.axi_slave_pkg.all;
use vunit_lib.integer_array_pkg.all;
use vunit_lib.logger_pkg.all;
use vunit_lib.memory_pkg.all;
use vunit_lib.queue_pkg.all;
use vunit_lib.random_pkg.all;
use vunit_lib.run_pkg.all;

library axi;
use axi.axi_pkg.all;

library bfm;
use bfm.axi_bfm_pkg.all;

library common;
use common.types_pkg.all;


entity tb_axi_pipeline is
  generic (
    seed : natural;
    runner_cfg : string
  );
end entity;

architecture tb of tb_axi_pipeline is

  -- DUT connections
  signal clk : std_ulogic := '0';

  signal pipelined_write_m2s : axi_write_m2s_t := axi_write_m2s_init;
  signal pipelined_write_s2m : axi_write_s2m_t := axi_write_s2m_init;

  -- Testbench stuff
  constant clk_period : time := 5 ns;

  shared variable rnd : RandomPType;

  impure function get_addr_width return positive is
  begin
    -- This function sets the init random seed. Must be called first.
    rnd.InitSeed(seed);
    return rnd.RandInt(20, 24);
  end function;
  constant addr_width : positive := get_addr_width;

  impure function get_id_width return natural is
  begin
    return rnd.RandInt(0, 4);
  end function;
  constant id_width : natural := get_id_width;

  impure function get_data_width return positive is
  begin
    return 8 * 2 ** rnd.RandInt(0, 3);
  end function;
  constant data_width : positive := get_data_width;

  constant bytes_per_beat : positive := data_width / 8;

  constant read_job_queue, read_data_queue : queue_t := new_queue;
  constant write_job_queue, write_data_queue : queue_t := new_queue;

  constant memory : memory_t := new_memory;

  signal num_read_bursts_checked : natural := 0;

begin

  clk <= not clk after clk_period / 2;
  test_runner_watchdog(runner, 100 us);


  ------------------------------------------------------------------------------
  main : process
    variable num_bursts_expected : natural := 0;

    procedure send_random_burst is
      constant burst_length_beats : positive := rnd.RandInt(1, axi_max_burst_length_beats);
      constant burst_length_bytes : positive := burst_length_beats * bytes_per_beat;

      variable buf : buffer_t := null_buffer;
      variable job : axi_master_bfm_job_t := axi_master_bfm_job_init;
      variable random_write_data, random_read_data : integer_array_t := null_integer_array;
    begin
      buf := allocate(
        memory=>memory,
        num_bytes=>burst_length_bytes,
        name=>"buffer_" & to_string(num_bursts_expected),
        alignment=>4096,
        permissions=>read_and_write
      );

      job.address := base_address(buf);
      job.length_bytes := burst_length_bytes;

      job.id := rnd.RandInt(2 ** id_width - 1);
      push(write_job_queue, to_slv(job));

      random_integer_array(
        rnd=>rnd,
        integer_array=>random_write_data,
        width=>burst_length_bytes,
        bits_per_word=>8
      );
      random_read_data := copy(random_write_data);

      push_ref(write_data_queue, random_write_data);

      -- The two pushes above initiate the write operation. Once that is done we start the
      -- read operation.
      wait until pipelined_write_m2s.b.ready and pipelined_write_s2m.b.valid and rising_edge(clk);

      -- Can set a different ID for the read than for the write
      job.id := rnd.RandInt(2 ** id_width - 1);
      push(read_job_queue, to_slv(job));
      push_ref(read_data_queue, random_read_data);

      num_bursts_expected := num_bursts_expected + 1;
    end procedure;

  begin
    test_runner_setup(runner, runner_cfg);

    if run("test_random_transactions") then
      for i in 0 to 20 loop
        send_random_burst;
      end loop;
    end if;

    wait until num_read_bursts_checked = num_bursts_expected and rising_edge(clk);

    test_runner_cleanup(runner);
  end process;


  ------------------------------------------------------------------------------
  read_block : block
    constant axi_slave : axi_slave_t := new_axi_slave(
      memory => memory,
      address_fifo_depth => 4,
      address_stall_probability => 0.2,
      data_stall_probability => 0.2,
      min_response_latency => clk_period,
      max_response_latency => 8 * clk_period,
      logger => get_logger("read_axi_slave")
    );

    signal raw_m2s, pipelined_m2s : axi_read_m2s_t := axi_read_m2s_init;
    signal raw_s2m, pipelined_s2m : axi_read_s2m_t := axi_read_s2m_init;
  begin

    ------------------------------------------------------------------------------
    axi_read_master_inst : entity bfm.axi_read_master
      generic map (
        id_width => id_width,
        data_width => data_width,
        job_queue => read_job_queue,
        reference_data_queue => read_data_queue,
        seed => seed
      )
      port map (
        clk => clk,
        --
        axi_read_m2s => raw_m2s,
        axi_read_s2m => raw_s2m,
        --
        num_bursts_checked => num_read_bursts_checked
      );


    ------------------------------------------------------------------------------
    dut : entity work.axi_read_pipeline
      generic map (
        addr_width => addr_width,
        id_width => id_width,
        data_width => data_width
      )
      port map (
        clk => clk,
        --
        left_m2s => raw_m2s,
        left_s2m => raw_s2m,
        --
        right_m2s => pipelined_m2s,
        right_s2m => pipelined_s2m
      );


    ------------------------------------------------------------------------------
    axi_read_slave_inst : entity bfm.axi_read_slave
      generic map (
        axi_slave => axi_slave,
        data_width => data_width,
        id_width => id_width
      )
      port map (
        clk => clk,
        --
        axi_read_m2s => pipelined_m2s,
        axi_read_s2m => pipelined_s2m
      );

  end block;


  ------------------------------------------------------------------------------
  write_block : block
    constant axi_slave : axi_slave_t := new_axi_slave(
      memory => memory,
      address_fifo_depth => 4,
      address_stall_probability => 0.2,
      data_stall_probability => 0.2,
      min_response_latency => clk_period,
      max_response_latency => 8 * clk_period,
      logger => get_logger("write_axi_slave")
    );

    signal raw_m2s : axi_write_m2s_t := axi_write_m2s_init;
    signal raw_s2m : axi_write_s2m_t := axi_write_s2m_init;
  begin

    ------------------------------------------------------------------------------
    axi_write_master_inst : entity bfm.axi_write_master
      generic map (
        id_width => id_width,
        data_width => data_width,
        job_queue => write_job_queue,
        data_queue => write_data_queue,
        seed => seed
      )
      port map (
        clk => clk,
        --
        axi_write_m2s => raw_m2s,
        axi_write_s2m => raw_s2m
      );


    ------------------------------------------------------------------------------
    dut : entity work.axi_write_pipeline
      generic map (
        addr_width => addr_width,
        id_width => id_width,
        data_width => data_width
      )
      port map (
        clk => clk,
        --
        left_m2s => raw_m2s,
        left_s2m => raw_s2m,
        --
        right_m2s => pipelined_write_m2s,
        right_s2m => pipelined_write_s2m
      );


    ------------------------------------------------------------------------------
    axi_write_slave_inst : entity bfm.axi_write_slave
      generic map (
        axi_slave => axi_slave,
        data_width => data_width,
        id_width => id_width
      )
      port map (
        clk => clk,
        --
        axi_write_m2s => pipelined_write_m2s,
        axi_write_s2m => pipelined_write_s2m
      );

  end block;


end architecture;
