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

  -- Big difference, so that erroneous level resync back or forth could happen.
  constant slow_clock_period : time := 20 ns;
  constant fast_clock_period : time := 2 ns;

  constant stall_config : stall_configuration_t := (
    stall_probability => 0.2,
    min_stall_cycles => 1,
    -- Very high, so that erroneous level resync back or forth could happen.
    -- Note that the slow clock is ten times slower than the fast clock.
    max_stall_cycles => 50
  );

  constant input_queue, result_queue : queue_t := new_queue;

  signal num_beats_checked : natural := 0;

begin

  test_runner_watchdog(runner, 2 ms);

  clocks_gen : if input_clock_is_faster generate
    input_clk <= not input_clk after fast_clock_period / 2;
    result_clk <= not result_clk after slow_clock_period / 2;

  elsif result_clock_is_faster generate
    input_clk <= not input_clk after slow_clock_period / 2;
    result_clk <= not result_clk after fast_clock_period / 2;

  else generate
    input_clk <= not input_clk after fast_clock_period / 2;
    result_clk <= not result_clk after fast_clock_period / 2;

  end generate;


  ------------------------------------------------------------------------------
  main : process

    variable rnd : RandomPType;

    variable expected_num_beats : natural := 0;

    procedure run_test(num_beats : natural) is
      constant num_bytes : natural := num_beats * data_width / 8;
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

        data_copy := copy(data);
        push_ref(input_queue, data_copy);
        push_ref(result_queue, data);

        expected_num_beats := expected_num_beats + expected_num_beats;
      end if;
    end procedure;

  begin
    test_runner_setup(runner, runner_cfg);
    rnd.InitSeed(seed);

    if run("test_init_state") then
      check_equal(input_ready, '1');
      check_equal(result_valid, '0');

      wait until input_ready'event or result_valid'event for 100 * slow_clock_period;

      check_equal(input_ready, '0');
      check_equal(result_valid, '1');

    elsif run("test_random_data") then
      run_test(num_beats=>100);

    end if;

    wait until num_beats_checked = expected_num_beats and rising_edge(result_clk);

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
