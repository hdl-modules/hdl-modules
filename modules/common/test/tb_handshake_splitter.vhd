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
use vunit_lib.check_pkg.all;
use vunit_lib.integer_array_pkg.all;
use vunit_lib.queue_pkg.all;
use vunit_lib.random_pkg.all;
use vunit_lib.run_pkg.all;

library bfm;
use bfm.stall_bfm_pkg.stall_configuration_t;

library common;

use work.types_pkg.all;


entity tb_handshake_splitter is
  generic (
    stall_probability_percent : natural;
    seed : natural;
    runner_cfg : string
  );
end entity;

architecture tb of tb_handshake_splitter is

  -- Generics
  constant num_interfaces : positive := 4;

  -- DUT connections
  signal clk : std_ulogic := '0';
  constant clk_period : time := 10 ns;

  signal input_ready, input_valid : std_ulogic := '0';
  signal input_data : std_ulogic_vector(8 - 1 downto 0) := (others => '0');

  signal output_ready, output_valid : std_ulogic_vector(0 to num_interfaces - 1) := (others => '0');

  -- Testbench stuff
  constant input_data_queue : queue_t := new_queue;
  constant output_data_queue : queue_vec_t(output_valid'range) := (others => new_queue);

  signal num_packets_checked : natural_vec_t(output_valid'range) := (others => 0);

  constant stall_config : stall_configuration_t := (
    stall_probability => real(stall_probability_percent) / 100.0,
    min_stall_cycles => 1,
    max_stall_cycles => 3
  );

begin

  test_runner_watchdog(runner, 1 ms);
  clk <= not clk after clk_period / 2;


  ------------------------------------------------------------------------------
  main : process
    variable rnd : RandomPType;

    procedure run_test(num_words : positive) is
      variable data, data_copy : integer_array_t := null_integer_array;
    begin
      random_integer_array(rnd=>rnd, integer_array=>data, width=>num_words, bits_per_word=>8);

      for output_index in output_data_queue'range loop
        data_copy := copy(data);
        push_ref(output_data_queue(output_index), data_copy);
      end loop;

      push_ref(input_data_queue, data);
    end procedure;

    procedure wait_until_done is
      -- All words in the test are sent in one packet. Hence when all slaves have checked one packet
      -- we are done.
      constant goal_num_packets_checked : natural_vec_t(num_packets_checked'range) := (others => 1);
    begin
      wait until num_packets_checked = goal_num_packets_checked and rising_edge(clk);
    end procedure;

    variable execution_time_cycles : positive := 1;

  begin
    test_runner_setup(runner, runner_cfg);
    rnd.InitSeed(seed);

    if run("test_random_data") then
      run_test(num_words => 2000);
      wait_until_done;

    elsif run("test_full_throughput") then
      run_test(num_words => 200);
      wait_until_done;

      execution_time_cycles := now / clk_period;
      check_relation(execution_time_cycles < 200 + 2);

    end if;

    test_runner_cleanup(runner);
  end process;


  ------------------------------------------------------------------------------
  axi_stream_master_inst : entity bfm.axi_stream_master
    generic map(
      data_width => input_data'length,
      data_queue => input_data_queue,
      stall_config => stall_config,
      seed => seed,
      logger_name_suffix => " - input"
    )
    port map(
      clk   => clk,
      --
      valid => input_valid,
      ready => input_ready,
      data  => input_data
    );


  ------------------------------------------------------------------------------
  output_gen : for output_index in output_valid'range generate

    ------------------------------------------------------------------------------
    axi_stream_slave_inst : entity bfm.axi_stream_slave
      generic map(
        data_width => input_data'length,
        reference_data_queue => output_data_queue(output_index),
        stall_config => stall_config,
        seed => seed,
        logger_name_suffix => " - output #" & to_string(output_index),
        disable_last_check => true
      )
      port map(
        clk   => clk,
        --
        valid => output_valid(output_index),
        ready => output_ready(output_index),
        data  => input_data,
        --
        num_packets_checked => num_packets_checked(output_index)
      );

  end generate;


  ------------------------------------------------------------------------------
  dut : entity work.handshake_splitter
    generic map (
      num_interfaces => num_interfaces
    )
    port map (
      clk => clk,
      --
      input_ready => input_ready,
      input_valid => input_valid,
      --
      output_ready => output_ready,
      output_valid => output_valid
    );

end architecture;
