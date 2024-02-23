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
use vunit_lib.axi_slave_pkg.all;
use vunit_lib.integer_array_pkg.all;
use vunit_lib.logger_pkg.all;
use vunit_lib.memory_pkg.all;
use vunit_lib.memory_utils_pkg.all;
use vunit_lib.queue_pkg.all;
use vunit_lib.random_pkg.all;
use vunit_lib.run_pkg.all;

library axi;
use axi.axi_pkg.all;

library bfm;
use bfm.axi_bfm_pkg.all;


entity tb_axi_read_throttle is
  generic (
    max_burst_length_beats : positive;
    full_ar_throughput : boolean;
    seed : natural;
    runner_cfg : string
  );
end entity;

architecture tb of tb_axi_read_throttle is

  -- Generic constants
  constant data_fifo_depth : positive := 2 * max_burst_length_beats;

  -- DUT connections
  signal clk : std_ulogic := '0';

  signal data_fifo_level : natural range 0 to data_fifo_depth;

  signal input_m2s, throttled_m2s : axi_read_m2s_t := axi_read_m2s_init;
  signal input_s2m, throttled_s2m : axi_read_s2m_t := axi_read_s2m_init;

  -- Testbench stuff
  constant addr_width : positive := 24;
  constant id_width : natural := 5;
  constant data_width : positive := 32;
  constant bytes_per_beat : positive := data_width / 8;

  constant max_burst_length_bytes : positive := bytes_per_beat * max_burst_length_beats;

  constant clk_period : time := 5 ns;

  shared variable rnd : RandomPType;

  constant job_queue, data_queue : queue_t := new_queue;

  constant memory : memory_t := new_memory;
  constant axi_slave : axi_slave_t := new_axi_slave(
    memory => memory,
    address_fifo_depth => 4,
    address_stall_probability => 0.3,
    data_stall_probability => 0.5,
    -- Set unusually low response latency, to fill the R FIFO as soon as possible after
    -- AR transaction.
    min_response_latency => 1 * clk_period,
    max_response_latency => 1 * clk_period,
    logger => get_logger("axi_slave")
  );

  signal num_bursts_checked : natural := 0;

  signal buffered_r_m2s : axi_m2s_r_t := axi_m2s_r_init;
  signal buffered_r_s2m : axi_s2m_r_t := axi_s2m_r_init;

begin

  clk <= not clk after clk_period / 2;
  test_runner_watchdog(runner, 100 us);


  ------------------------------------------------------------------------------
  main : process
    variable num_bursts_expected : natural := 0;

    procedure send_random_burst is
      constant burst_length_bytes : positive := rnd.RandInt(1, max_burst_length_bytes);

      variable random_data : integer_array_t := null_integer_array;
      variable buf, buf_dummy : buffer_t := null_buffer;
      variable job : axi_master_bfm_job_t := axi_master_bfm_job_init;
    begin
      buf := allocate(
        memory=>memory,
        num_bytes=>burst_length_bytes,
        name=>"read_buffer_" & to_string(num_bursts_expected),
        alignment=>4096,
        permissions=>read_only
      );

      if burst_length_bytes mod bytes_per_beat /= 0 then
        buf_dummy := allocate(
          memory=>memory,
          num_bytes=>bytes_per_beat - (burst_length_bytes mod bytes_per_beat),
          name=>"dummy_buffer_to_avoid_reading_from_unallocated_area",
          alignment=>1,
          permissions=>read_only
        );
      end if;

      job.address := base_address(buf);
      job.length_bytes := burst_length_bytes;
      job.id := rnd.RandInt(2 ** id_width - 1);

      push(job_queue, to_slv(job));

      random_integer_array(
        rnd=>rnd,
        integer_array=>random_data,
        width=>burst_length_bytes,
        bits_per_word=>8
      );

      write_integer_array(
        memory=>memory,
        base_address=>base_address(buf),
        integer_array=>random_data
      );

      push_ref(data_queue, random_data);

      num_bursts_expected := num_bursts_expected + 1;
    end procedure;

  begin
    test_runner_setup(runner, runner_cfg);
    rnd.InitSeed(seed);

    if run("test_random_transactions") then
      for i in 0 to 50 loop
        send_random_burst;
      end loop;
    end if;

    wait until num_bursts_checked = num_bursts_expected and rising_edge(clk);

    test_runner_cleanup(runner);
  end process;


  ----------------------------------------------------------------------------
  check_well_behaved : process
  begin
    wait until rising_edge(clk);

    assert throttled_m2s.r.ready or not throttled_s2m.r.valid
      report "Should never stall";
  end process;


  ------------------------------------------------------------------------------
  axi_read_master_inst : entity bfm.axi_read_master
    generic map (
      id_width => id_width,
      data_width => data_width,
      job_queue => job_queue,
      reference_data_queue => data_queue,
      -- Stall a lot, to trigger the "block AR" condition in the DUT
      r_stall_config => (
        stall_probability => 0.5,
        min_stall_cycles => 4,
        max_stall_cycles => 20
      ),
      seed => seed
    )
    port map (
      clk => clk,
      --
      axi_read_m2s => input_m2s,
      axi_read_s2m => input_s2m,
      --
      num_bursts_checked => num_bursts_checked
    );


  ------------------------------------------------------------------------------
  axi_r_fifo_inst : entity work.axi_r_fifo
    generic map (
      asynchronous => false,
      id_width => id_width,
      data_width => data_width,
      depth => data_fifo_depth
    )
    port map (
      clk => clk,
      --
      input_m2s => input_m2s.r,
      input_s2m => input_s2m.r,
      --
      output_m2s => buffered_r_m2s,
      output_s2m => buffered_r_s2m,
      output_level => data_fifo_level
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
      axi_read_m2s => throttled_m2s,
      axi_read_s2m => throttled_s2m
    );


  ------------------------------------------------------------------------------
  dut : entity work.axi_read_throttle
    generic map (
      data_fifo_depth => data_fifo_depth,
      max_burst_length_beats => max_burst_length_beats,
      id_width => id_width,
      addr_width => addr_width,
      full_ar_throughput => full_ar_throughput
    )
    port map (
      clk => clk,
      --
      data_fifo_level => data_fifo_level,
      --
      input_m2s.ar => input_m2s.ar,
      input_m2s.r => buffered_r_m2s,
      input_s2m.ar => input_s2m.ar,
      input_s2m.r => buffered_r_s2m,
      --
      throttled_m2s => throttled_m2s,
      throttled_s2m => throttled_s2m
    );

end architecture;
