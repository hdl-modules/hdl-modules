-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the tsfpga project.
-- https://tsfpga.com
-- https://gitlab.com/tsfpga/tsfpga
-- -------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
use vunit_lib.random_pkg.all;
context vunit_lib.vc_context;
context vunit_lib.vunit_context;

library osvvm;
use osvvm.RandomPkg.all;

library bfm;

use work.types_pkg.all;


entity tb_width_conversion is
  generic (
    input_width : positive;
    output_width : positive;
    enable_strobe : boolean;
    enable_last : boolean;
    support_unaligned_burst_length : boolean := false;
    enable_jitter : boolean := true;
    runner_cfg : string
  );
end entity;

architecture tb of tb_width_conversion is

  constant input_bytes_per_beat : positive := input_width / 8;
  constant output_bytes_per_beat : positive := output_width / 8;
  constant minimum_width_bytes : positive := minimum(input_bytes_per_beat, output_bytes_per_beat);
  constant maximum_width_bytes : positive := maximum(input_bytes_per_beat, output_bytes_per_beat);

  constant is_upconversion : boolean := output_width > input_width;
  constant is_downconversion : boolean := output_width < input_width;

  signal clk : std_logic := '0';
  constant clk_period : time := 10 ns;

  signal input_ready, input_valid, input_last : std_logic := '0';
  signal output_ready, output_valid, output_last : std_logic := '0';

  signal input_data : std_logic_vector(input_width - 1 downto 0);
  signal output_data : std_logic_vector(output_width - 1 downto 0);

  constant strobe_unit_width : positive := 8;
  signal input_strobe : std_logic_vector(input_width / strobe_unit_width - 1 downto 0) :=
    (others => '0');
  signal output_strobe : std_logic_vector(output_width / strobe_unit_width - 1 downto 0) :=
    (others => '0');

  constant input_data_queue, output_data_queue : queue_t := new_queue;

  constant stall_config : stall_config_t := (
    stall_probability => 0.2 * to_real(enable_jitter),
    min_stall_cycles => 1,
    max_stall_cycles => 4
  );

  signal num_output_bursts_checked : natural := 0;

begin

  test_runner_watchdog(runner, 200 us);
  clk <= not clk after clk_period / 2;


  ------------------------------------------------------------------------------
  main : process
    variable rnd : RandomPType;
    variable num_output_bursts_expected : natural := 0;

    procedure run_test(fixed_length_bytes : natural := 0) is
      variable burst_length_bytes : positive := 1;
      variable num_input_bytes_to_remove : natural := 0;

      variable data_in, data_out : integer_array_t := null_integer_array;
    begin
      if fixed_length_bytes /= 0 then
        burst_length_bytes := fixed_length_bytes;

      else
        -- Set a random length that will fill up whole input and output words
        burst_length_bytes := rnd.RandInt(1, 5) * maximum_width_bytes;

        if support_unaligned_burst_length then
          -- In this case we can unstrobe/remove more than a whole word.
          -- If upconverting, and we remove more than one whole input word, the entity will pad.
          -- If downconverting, and we remove more than one whole output word, the entity
          -- will strip.
          num_input_bytes_to_remove := rnd.RandInt(0, maximum_width_bytes - 1);

        elsif enable_strobe then
          -- Unstrobe a number of byte lanes on the last input beat.
          -- We must still be aligned in terms of number of output beats.
          num_input_bytes_to_remove := rnd.RandInt(0, minimum_width_bytes - 1);
        end if;

        burst_length_bytes := maximum(1, burst_length_bytes - num_input_bytes_to_remove);
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

    variable start_time, time_diff : time;

    constant full_throughput_num_bytes : positive := maximum_width_bytes * 100 * 10;

    constant full_throughput_num_input_beats : positive :=
      full_throughput_num_bytes / input_bytes_per_beat;
    constant full_throughput_num_output_beats : positive :=
      full_throughput_num_bytes / output_bytes_per_beat;

    constant full_throughput_num_cycles : positive :=
      maximum(full_throughput_num_input_beats, full_throughput_num_output_beats);

    procedure wait_until_done is
    begin
      wait until
        is_empty(input_data_queue)
        and is_empty(output_data_queue)
        and num_output_bursts_checked = num_output_bursts_expected
        and rising_edge(clk);
      wait until rising_edge(clk);
    end procedure;

  begin
    test_runner_setup(runner, runner_cfg);
    rnd.InitSeed(rnd'instance_name);

    if run("test_data") then
      for idx in 0 to 200 loop
        run_test;
      end loop;

      wait_until_done;

    elsif run("test_full_throughput") then
      start_time := now;

      for idx in 0 to 10 - 1 loop
        run_test(fixed_length_bytes=>full_throughput_num_bytes / 10);
      end loop;
      wait_until_done;

      time_diff := now - start_time;
      check_relation(
        time_diff < (full_throughput_num_cycles + 4) * clk_period
      );
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
  output_block : block
    signal strobe : std_logic_vector(output_strobe'range) := (others => '0');
  begin

    strobe <= output_strobe when enable_strobe else (others => '1');


    ------------------------------------------------------------------------------
    axi_stream_slave_inst : entity bfm.axi_stream_slave
      generic map (
        data_width_bits => output_data'length,
        reference_data_queue => output_data_queue,
        stall_config => stall_config,
        logger_name_suffix => "_output",
        disable_last_check => not enable_last
      )
      port map (
        clk => clk,
        --
        ready => output_ready,
        valid => output_valid,
        last => output_last,
        data => output_data,
        strobe => strobe,
        --
        num_bursts_checked => num_output_bursts_checked
      );

  end block;


  ------------------------------------------------------------------------------
  dut : entity work.width_conversion
    generic map (
      input_width => input_width,
      output_width => output_width,
      enable_strobe => enable_strobe,
      strobe_unit_width => strobe_unit_width,
      enable_last => enable_last,
      support_unaligned_burst_length => support_unaligned_burst_length
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
