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
use common.time_pkg.all;


entity tb_resync_slv_handshake is
  generic (
    seed : natural;
    data_width : positive := 8;
    stall_probability_percent : natural := 20;
    result_clock_is_greatly_faster : boolean := false;
    result_clock_is_mildly_faster : boolean := false;
    clocks_are_same : boolean := false;
    result_clock_is_mildly_slower : boolean := false;
    result_clock_is_greatly_slower : boolean := false;
    runner_cfg : string
  );
end entity;

architecture tb of tb_resync_slv_handshake is

  -- DUT connections.
  signal input_clk, input_ready, input_valid : std_ulogic := '0';
  signal result_clk, result_ready, result_valid : std_ulogic := '0';
  signal input_data, result_data : std_ulogic_vector(data_width - 1 downto 0) := (others => '0');

  -- Testbench stuff.

  -- Big difference, so that erroneous level resync back or forth could happen.
  constant clock_period_greatly_fast : time := 2 ns;
  constant clock_period_mildly_fast : time := clock_period_greatly_fast * 20;
  constant clock_period_medium : time := clock_period_mildly_fast + 1 ns;
  constant clock_period_mildly_slow : time := clock_period_medium + 1 ns;
  constant clock_period_greatly_slow : time := clock_period_medium * 20 + 1 ns;

  function get_result_period return time is
  begin
    if result_clock_is_greatly_faster then
      return clock_period_greatly_fast;
    end if;

    if result_clock_is_mildly_faster then
      return clock_period_mildly_fast;
    end if;

    if result_clock_is_mildly_slower then
      return clock_period_mildly_slow;
    end if;

    if result_clock_is_greatly_slower then
      return clock_period_greatly_slow;
    end if;

    if clocks_are_same then
      return clock_period_medium;
    end if;

    return clock_period_medium;
  end function;
  constant input_clk_period : time := clock_period_medium;
  constant result_clk_period : time := get_result_period;

  constant stall_config : stall_configuration_t := (
    stall_probability => real(stall_probability_percent) / 100.0,
    min_stall_cycles => 1,
    -- Very high, so that erroneous level resync back or forth could happen.
    max_stall_cycles => 50
  );

  constant input_queue, result_queue : queue_t := new_queue;

  signal num_beats_checked : natural := 0;

begin

  input_clk <= not input_clk after input_clk_period / 2;
  result_clk <= not result_clk after result_clk_period / 2;

  test_runner_watchdog(runner, 100 ms);


  ------------------------------------------------------------------------------
  main : process
    variable rnd : RandomPType;

    constant num_beats : positive := 1000;

    procedure run_test is
      constant num_bytes : natural := num_beats * data_width / 8;
      variable data, data_copy : integer_array_t := null_integer_array;
    begin
      random_integer_array(
        rnd => rnd,
        integer_array => data,
        width => num_bytes,
        bits_per_word => 8,
        is_signed => false
      );

      data_copy := copy(data);
      push_ref(input_queue, data_copy);
      push_ref(result_queue, data);

      wait until num_beats_checked = num_beats and rising_edge(result_clk);
    end procedure;

    variable time_start, time_diff : time := 0 fs;
    constant expected_time_diff : time := (
      num_beats * (3 * input_clk_period + 3 * result_clk_period)
    );

  begin
    test_runner_setup(runner, runner_cfg);
    rnd.InitSeed(seed);

    if run("test_init_state") then
      check_equal(input_ready, '1');
      check_equal(result_valid, '0');

      wait until input_ready'event or result_valid'event for 100 * clock_period_greatly_slow;

      check_equal(input_ready, '1');
      check_equal(result_valid, '0');

    elsif run("test_random_data") then
      run_test;

    elsif run("test_count_sampling_period") then
      time_start := now;
      run_test;
      time_diff := now - time_start;

      report to_string(to_real_s(time_diff) / to_real_s(expected_time_diff));

      check_relation(time_diff < 1.001 * expected_time_diff);
      check_relation(time_diff > 0.80 * expected_time_diff);
    end if;

    test_runner_cleanup(runner);
  end process;


  ------------------------------------------------------------------------------
  count_result : process
  begin
    wait until rising_edge(result_clk);

    num_beats_checked <= num_beats_checked + to_int(result_ready and result_valid);
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
      data => result_data
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
      result_clk => result_clk,
      result_ready => result_ready,
      result_valid => result_valid,
      result_data => result_data
    );

end architecture;
