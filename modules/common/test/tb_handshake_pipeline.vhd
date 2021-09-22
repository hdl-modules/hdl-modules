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

  constant data_width : integer := 16;

  signal input_ready, input_valid, input_last : std_logic := '0';
  signal output_ready, output_valid, output_last : std_logic := '0';
  signal input_data, output_data : std_logic_vector(data_width - 1 downto 0) := (others => '0');

  constant num_words : integer := 1024;

  constant stall_config : stall_config_t := (
    stall_probability => 0.5 * real(to_int(data_jitter)),
    min_stall_cycles => 1,
    max_stall_cycles => 2
  );

  constant input_master : axi_stream_master_t := new_axi_stream_master(
    data_length => input_data'length,
    protocol_checker => new_axi_stream_protocol_checker(
      logger => get_logger("input_master"),
      data_length => input_data'length
    ),
    stall_config => stall_config
  );

  constant output_slave : axi_stream_slave_t := new_axi_stream_slave(
    data_length => input_data'length,
    protocol_checker => new_axi_stream_protocol_checker(
      logger => get_logger("output_slave"),
      data_length => output_data'length
    ),
    stall_config => stall_config
  );

  signal start, stimuli_done, data_check_done : boolean := false;

begin

  test_runner_watchdog(runner, 2 ms);
  clk <= not clk after clk_period / 2;


  ------------------------------------------------------------------------------
  main : process
    variable rnd : RandomPType;

    procedure run_test is
      variable data : integer_array_t := null_integer_array;

      variable reference_data, got_data : std_logic_vector(input_data'range) := (others => '0');
      variable got_last : std_logic := '0';

      variable axi_stream_pop_reference : axi_stream_reference_t;
      variable axi_stream_pop_reference_queue : queue_t := new_queue;
    begin
      report "Starting test";
      data := random_integer_array(width=>num_words, bits_per_word=>data_width, is_signed=>false);

      for word_idx in 0 to length(data) - 1 loop
        reference_data := std_logic_vector(to_unsigned(get(data, word_idx), reference_data'length));
        push_axi_stream(
          net,
          input_master,
          tdata=>reference_data,
          tlast=>to_sl(word_idx=length(data) - 1)
        );
      end loop;

      -- Queue up reads in order to get full throughput. We need to keep track of
      -- the pop_reference when we read the reply later. Hence it is pushed to a queue.
      for word_idx in 0 to length(data) - 1 loop
        pop_axi_stream(net, output_slave, axi_stream_pop_reference);
        push(axi_stream_pop_reference_queue, axi_stream_pop_reference);
      end loop;

      for word_idx in 0 to length(data) - 1 loop
        axi_stream_pop_reference := pop(axi_stream_pop_reference_queue);
        await_pop_axi_stream_reply(
          net,
          axi_stream_pop_reference,
          tdata=>got_data,
          tlast=>got_last
        );

        reference_data := std_logic_vector(to_unsigned(get(data, word_idx), reference_data'length));
        check_equal(got_data, reference_data, "word_idx=" & to_string(word_idx));
        check_equal(got_last, word_idx = num_words - 1);
      end loop;
    end procedure;

    variable start_time, time_diff : time;

  begin
    test_runner_setup(runner, runner_cfg);
    rnd.InitSeed(rnd'instance_name);

    -- Decrease noise
    disable(get_logger("input_master:rule 4"), warning);
    disable(get_logger("output_slave:rule 4"), warning);

    if run("test_random_data") then
      run_test;
      run_test;
      run_test;
      run_test;

    elsif run("test_full_throughput") then
      start_time := now;
      run_test;
      time_diff := now - start_time;

      check_relation(time_diff < (num_words + 3) * clk_period);
    end if;

    test_runner_cleanup(runner);
  end process;


  ------------------------------------------------------------------------------
  axi_stream_master_inst : entity vunit_lib.axi_stream_master
    generic map(
      master => input_master
    )
    port map(
      aclk => clk,
      tvalid => input_valid,
      tready => input_ready,
      tdata => input_data,
      tlast => input_last
    );


  ------------------------------------------------------------------------------
  axi_stream_slave_inst : entity vunit_lib.axi_stream_slave
    generic map(
      slave => output_slave
    )
    port map(
      aclk => clk,
      tvalid => output_valid,
      tready => output_ready,
      tdata => output_data,
      tlast => output_last
    );


  ------------------------------------------------------------------------------
  dut : entity work.handshake_pipeline
    generic map (
      data_width => data_width,
      full_throughput => full_throughput,
      allow_poor_input_ready_timing => allow_poor_input_ready_timing
    )
    port map (
      clk => clk,
      --
      input_ready => input_ready,
      input_valid => input_valid,
      input_last => input_last,
      input_data => input_data,
      --
      output_ready => output_ready,
      output_valid => output_valid,
      output_last => output_last,
      output_data => output_data
    );

end architecture;
