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

library common;
use common.types_pkg.all;


entity tb_axi_write_throttle is
  generic (
    include_slave_w_fifo : boolean;
    seed : natural;
    runner_cfg : string
  );
end entity;

architecture tb of tb_axi_write_throttle is

  -- DUT connections
  signal clk : std_ulogic := '0';

  signal input_m2s, throttled_m2s : axi_write_m2s_t := axi_write_m2s_init;
  signal input_s2m, throttled_s2m : axi_write_s2m_t := axi_write_s2m_init;

  -- Testbench stuff
  constant id_width : natural := 5;
  constant data_width : positive := 32;

  -- Set low in order to keep simulation time down.
  constant max_burst_length_beats : positive := 16;
  constant max_burst_length_bytes : positive := data_width / 8 * max_burst_length_beats;

  constant clk_period : time := 5 ns;

  shared variable rnd : RandomPType;

  constant job_queue, data_queue : queue_t := new_queue;

  constant memory : memory_t := new_memory;
  constant axi_slave : axi_slave_t := new_axi_slave(
    memory => memory,
    address_fifo_depth => 4,
    address_stall_probability => 0.3,
    data_stall_probability => 0.5,
    min_response_latency => 12 * clk_period,
    max_response_latency => 20 * clk_period,
    logger => get_logger("axi_slave")
  );

  signal num_bursts_written : natural := 0;

begin

  clk <= not clk after clk_period / 2;
  test_runner_watchdog(runner, 100 us);


  ------------------------------------------------------------------------------
  main : process
    variable num_bursts_expected : natural := 0;

    procedure send_random_burst is
      constant burst_length_bytes : positive := rnd.RandInt(1, max_burst_length_bytes);

      variable random_data : integer_array_t := null_integer_array;
      variable buf : buffer_t := null_buffer;
      variable job : axi_master_bfm_job_t := axi_master_bfm_job_init;
    begin
      buf := allocate(
        memory=>memory,
        num_bytes=>burst_length_bytes,
        name=>"write_buffer_" & to_string(num_bursts_expected),
        alignment=>4096,
        permissions=>write_only
      );

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

      set_expected_integer_array(
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

    wait until num_bursts_written = num_bursts_expected and rising_edge(clk);
    check_expected_was_written(memory);

    test_runner_cleanup(runner);
  end process;


  ----------------------------------------------------------------------------
  check_well_behaved : process
    variable num_aw_done, num_w_done : natural := 0;
    variable awvalid_p1 : std_ulogic := '0';
  begin
    wait until rising_edge(clk);

    if throttled_m2s.aw.valid and not awvalid_p1 then
      assert throttled_m2s.w.valid report "Got new AWVALID without WVALID";
    end if;

    if throttled_m2s.w.valid then
      assert throttled_m2s.aw.valid = '1' or num_aw_done > num_w_done
        report "Got WVALID before corresponding AW transaction";
    end if;

    -- W burst can finish before or after the AW transaction occurs (before AW happens if AWREADY
    -- stalls). But they should never go more out of sync than that.
    assert
      num_aw_done = num_w_done
      or num_aw_done = num_w_done + 1
      or num_aw_done = num_w_done - 1
      report "Queued up too many AW";

    num_aw_done := num_aw_done + to_int(throttled_s2m.aw.ready and throttled_m2s.aw.valid);
    num_w_done :=
      num_w_done + to_int(throttled_s2m.w.ready and throttled_m2s.w.valid and throttled_m2s.w.last);

    awvalid_p1 := throttled_m2s.aw.valid;
  end process;


  ------------------------------------------------------------------------------
  axi_write_master_inst : entity bfm.axi_write_master
    generic map (
      id_width => id_width,
      data_width => data_width,
      job_queue => job_queue,
      data_queue => data_queue,
      seed => seed
    )
    port map (
      clk => clk,
      --
      axi_write_m2s => input_m2s,
      axi_write_s2m => input_s2m,
      --
      num_bursts_done => num_bursts_written
    );


  ------------------------------------------------------------------------------
  axi_write_slave_inst : entity bfm.axi_write_slave
    generic map (
      axi_slave => axi_slave,
      data_width => data_width,
      id_width => id_width,
      -- Enabling a slave W FIFO means that WREADY can be raised before AWREADY.
      -- The DUT should still be well behaved.
      w_fifo_depth => 2 * max_burst_length_beats * to_int(include_slave_w_fifo)
    )
    port map (
      clk => clk,
      --
      axi_write_m2s => throttled_m2s,
      axi_write_s2m => throttled_s2m
    );


  ------------------------------------------------------------------------------
  dut : entity work.axi_write_throttle
    port map (
      clk => clk,
      --
      input_m2s => input_m2s,
      input_s2m => input_s2m,
      --
      throttled_m2s => throttled_m2s,
      throttled_s2m => throttled_s2m
    );

end architecture;
