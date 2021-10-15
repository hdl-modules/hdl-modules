-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the tsfpga project.
-- https://tsfpga.com
-- https://gitlab.com/tsfpga/tsfpga
-- -------------------------------------------------------------------------------------------------

library ieee;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;

library vunit_lib;
use vunit_lib.random_pkg.all;
context vunit_lib.vunit_context;
context vunit_lib.vc_context;

library osvvm;
use osvvm.RandomPkg.all;

library bfm;

use work.types_pkg.all;


entity tb_handshake_pipeline is
  generic (
    full_throughput : boolean;
    allow_poor_input_ready_timing : boolean;
    data_jitter : boolean := false;
    runner_cfg : string
  );
end entity;

architecture tb of tb_handshake_pipeline is

  signal clk : std_logic := '0';
  constant clk_period : time := 10 ns;

  constant data_width : positive := 16;
  constant bytes_per_beat : positive := data_width / 8;

  signal input_ready, input_valid, input_last : std_logic := '0';
  signal output_ready, output_valid, output_last : std_logic := '0';

  signal input_data, output_data : std_logic_vector(data_width - 1 downto 0) := (others => '0');
  signal input_strobe, output_strobe : std_logic_vector(data_width / 8 - 1 downto 0) :=
    (others => '0');

  constant input_data_queue, output_data_queue : queue_t := new_queue;

  constant stall_config : stall_config_t := (
    stall_probability => 0.5 * real(to_int(data_jitter)),
    min_stall_cycles => 1,
    max_stall_cycles => 2
  );

  signal num_output_bursts_checked : natural := 0;

  constant full_throughput_num_beats : positive := 1024;

begin

  test_runner_watchdog(runner, 2 ms);
  clk <= not clk after clk_period / 2;


  ------------------------------------------------------------------------------
  main : process
    variable rnd : RandomPType;
    variable num_output_bursts_expected : natural := 0;

    procedure run_test(fixed_length_beats : natural := 0) is
      variable burst_length_bytes : positive := 1;
      variable data_in, data_out : integer_array_t := null_integer_array;
    begin
      if fixed_length_beats /= 0 then
        burst_length_bytes := fixed_length_beats * bytes_per_beat;

      else
        -- Set a random length, up to a number of words
        burst_length_bytes := rnd.RandInt(1, 5 * bytes_per_beat);
      end if;

      random_integer_array(
        rnd => rnd,
        integer_array => data_in,
        width => burst_length_bytes,
        bits_per_word => 8,
        is_signed => false
      );
      data_out := copy(data_in);

      push_ref(input_data_queue, data_in);
      push_ref(output_data_queue, data_out);

      num_output_bursts_expected := num_output_bursts_expected + 1;
    end procedure;

    procedure wait_until_done is
    begin
      wait until
        is_empty(input_data_queue)
        and is_empty(output_data_queue)
        and num_output_bursts_checked = num_output_bursts_expected
        and rising_edge(clk);
      wait until rising_edge(clk);
    end procedure;

    variable start_time, time_diff : time;

  begin
    test_runner_setup(runner, runner_cfg);
    rnd.InitSeed(rnd'instance_name);

    -- Decrease noise
    disable(get_logger("input_master:rule 4"), warning);
    disable(get_logger("output_slave:rule 4"), warning);

    if run("test_random_data") then
      for idx in 0 to 300 loop
        run_test;
      end loop;

      wait_until_done;

    elsif run("test_full_throughput") then
      start_time := now;

      run_test(fixed_length_beats=>full_throughput_num_beats);
      wait_until_done;

      time_diff := now - start_time;
      check_relation(time_diff < (full_throughput_num_beats + 4) * clk_period);
    end if;

    test_runner_cleanup(runner);
  end process;


  ------------------------------------------------------------------------------
  axi_stream_master_inst : entity bfm.axi_stream_master
    generic map (
      data_width_bits => input_data'length,
      data_queue => input_data_queue,
      stall_config => stall_config,
      logger_name_suffix => "_input",
      strobe_unit_width_bits => input_data'length / input_strobe'length
    )
    port map (
      clk => clk,
      --
      ready => input_ready,
      valid => input_valid,
      last => input_last,
      data => input_data,
      strobe => input_strobe
    );


  ------------------------------------------------------------------------------
  axi_stream_slave_inst : entity bfm.axi_stream_slave
    generic map (
      data_width_bits => output_data'length,
      reference_data_queue => output_data_queue,
      stall_config => stall_config,
      logger_name_suffix => "_output"
    )
    port map (
      clk => clk,
      --
      ready => output_ready,
      valid => output_valid,
      last => output_last,
      data => output_data,
      strobe => output_strobe,
      --
      num_bursts_checked => num_output_bursts_checked
    );


  ------------------------------------------------------------------------------
  dut : entity work.handshake_pipeline
    generic map (
      data_width => data_width,
      full_throughput => full_throughput,
      allow_poor_input_ready_timing => allow_poor_input_ready_timing,
      strobe_unit_width => input_data'length / input_strobe'length
    )
    port map (
      clk => clk,
      --
      input_ready => input_ready,
      input_valid => input_valid,
      input_last => input_last,
      input_data => input_data,
      input_strobe => input_strobe,
      --
      output_ready => output_ready,
      output_valid => output_valid,
      output_last => output_last,
      output_data => output_data,
      output_strobe => output_strobe
    );

end architecture;
