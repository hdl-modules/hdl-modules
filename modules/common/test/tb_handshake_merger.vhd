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
use bfm.queue_bfm_pkg.get_new_queues;

use work.types_pkg.all;


entity tb_handshake_merger is
  generic (
    stall_probability_percent : natural;
    seed : natural;
    runner_cfg : string
  );
end entity;

architecture tb of tb_handshake_merger is

  -- Generic constants
  constant num_interfaces : positive := 4;

  -- DUT connections
  signal clk : std_ulogic := '0';
  constant clk_period : time := 10 ns;

  signal input_ready, input_valid, input_last : std_ulogic_vector(0 to num_interfaces - 1) := (
    others => '0'
  );
  signal input_data : slv_vec_t(input_valid'range)(8 - 1 downto 0) := (others => (others => '0'));

  signal result_ready, result_valid, result_last : std_ulogic := '0';

  -- Testbench stuff
  constant input_queues : queue_vec_t(input_valid'range) := get_new_queues(input_valid'length);
  constant result_queue : queue_t := new_queue;

  signal num_packets_checked : natural := 0;

  constant stall_config : stall_configuration_t := (
    stall_probability => real(stall_probability_percent) / 100.0,
    min_stall_cycles => 1,
    max_stall_cycles => 3
  );

begin

  test_runner_watchdog(runner, 100 us);
  clk <= not clk after clk_period / 2;


  ------------------------------------------------------------------------------
  main : process
    variable rnd : RandomPType;

    procedure run_test(num_words : positive) is
      variable data_inputs : integer_array_vec_t(input_valid'range) := (
        others => null_integer_array
      );
      variable data_result : integer_array_t := new_1d(
        length=>num_words * input_valid'length,
        bit_width=>8,
        is_signed=>false
      );
    begin
      for input_idx in input_valid'range loop
        random_integer_array(
          rnd=>rnd, integer_array=>data_inputs(input_idx), width=>num_words, bits_per_word=>8
        );
      end loop;

      for word_idx in 0 to num_words - 1 loop
        for input_idx in input_valid'range loop
          -- Each result beat consists of the corresponding data from each input concatenated.
          set(
            arr=>data_result,
            idx=>word_idx * input_valid'length + input_idx,
            value=>get(
              arr=>data_inputs(input_idx),
              idx=>word_idx
            )
          );
        end loop;
      end loop;

      for input_idx in input_valid'range loop
        push_ref(input_queues(input_idx), data_inputs(input_idx));
      end loop;
      push_ref(result_queue, data_result);
    end procedure;

    procedure wait_until_done is
    begin
      wait until num_packets_checked = 1 and rising_edge(clk);
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
  input_gen : for input_idx in input_valid'range generate

    ------------------------------------------------------------------------------
    axi_stream_master_inst : entity bfm.axi_stream_master
      generic map(
        data_width => input_data(0)'length,
        data_queue => input_queues(input_idx),
        stall_config => stall_config,
        seed => seed,
        logger_name_suffix => " - input #" & to_string(input_idx)
      )
      port map(
        clk   => clk,
        --
        ready => input_ready(input_idx),
        valid => input_valid(input_idx),
        last => input_last(input_idx),
        data => input_data(input_idx)
      );

  end generate;


  ------------------------------------------------------------------------------
  result_block : block
    signal result_data : std_ulogic_vector(input_data'length * input_data(0)'length - 1 downto 0)
      := (others => '0');
  begin

    ------------------------------------------------------------------------------
    axi_stream_slave_inst : entity bfm.axi_stream_slave
      generic map(
        data_width => result_data'length,
        reference_data_queue => result_queue,
        stall_config => stall_config,
        seed => seed,
        logger_name_suffix => " - result"
      )
      port map(
        clk   => clk,
        --
        ready => result_ready,
        valid => result_valid,
        last => result_last,
        data  => result_data,
        --
        num_packets_checked => num_packets_checked
      );

      -- Hard coded for 4 interfaces...
      result_data <= input_data(3) & input_data(2) & input_data(1) & input_data(0);

  end block;


  ------------------------------------------------------------------------------
  dut : entity work.handshake_merger
    generic map (
      num_interfaces => num_interfaces
    )
    port map (
      clk => clk,
      --
      input_ready => input_ready,
      input_valid => input_valid,
      input_last => input_last,
      --
      result_ready => result_ready,
      result_valid => result_valid,
      result_last => result_last
    );

end architecture;
