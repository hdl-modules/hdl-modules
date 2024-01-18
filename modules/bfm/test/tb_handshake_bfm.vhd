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
use osvvm.RandomPkg.all;

library vunit_lib;
context vunit_lib.vc_context;
context vunit_lib.vunit_context;

library common;
use common.types_pkg.all;


entity tb_handshake_bfm is
  generic (
    master_stall_probability_percent : natural;
    slave_stall_probability_percent : natural;
    data_width : natural;
    seed : natural;
    runner_cfg : string
  );
end entity;

architecture tb of tb_handshake_bfm is

  constant master_stall_config : stall_config_t := (
    stall_probability => real(master_stall_probability_percent) / 100.0,
    min_stall_cycles => 1,
    max_stall_cycles => 5
  );

  constant slave_stall_config : stall_config_t := (
    stall_probability => real(slave_stall_probability_percent) / 100.0,
    min_stall_cycles => 1,
    max_stall_cycles => 5
  );

  signal clk : std_ulogic := '0';
  constant clk_period : time := 10 ns;

  signal input_ready, input_valid, result_ready, result_valid, input_last, result_last : std_ulogic
    := '0';
  signal input_data, result_data : std_ulogic_vector(data_width - 1 downto 0) := (others => '0');
  signal input_strobe, result_strobe : std_ulogic_vector(data_width / 8 - 1 downto 0) :=
    (others => '0');

  signal result_is_ready, input_is_valid : std_ulogic := '0';

  constant reference_data_queue, reference_last_queue : queue_t := new_queue;

begin

  test_runner_watchdog(runner, 2 ms);
  clk <= not clk after clk_period / 2;


  ------------------------------------------------------------------------------
  main : process
    variable rnd : RandomPType;

    variable stimuli_data : std_ulogic_vector(input_data'range) := (others => '0');
    variable stimuli_last : std_ulogic := '0';
  begin
    test_runner_setup(runner, runner_cfg);

    rnd.InitSeed(seed);

    wait until rising_edge(clk);

    if run("test_full_master_throughput") then
      input_is_valid <= '1';

      -- Wait one clock for 'input_valid' to be asserted, and one clock for in to propagate through
      -- the handshake pipeline
      wait until rising_edge(clk);
      wait until rising_edge(clk);
      check_equal(result_valid, '1');

      wait until result_valid'event for 100 * clk_period;
      check_equal(result_valid, '1');

      -- Should still be full throughput even when we start popping words
      result_is_ready <= '1';
      wait until result_valid'event for 100 * clk_period;
      check_equal(result_valid, '1');

    elsif run("test_full_slave_throughput") then
      result_is_ready <= '1';

      wait until rising_edge(clk);
      check_equal(input_ready, '1');

      wait until input_ready'event for 100 * clk_period;
      check_equal(input_ready, '1');

      -- Should still be full throughput even when we start popping words
      input_is_valid <= '1';
      wait until input_ready'event for 100 * clk_period;
      check_equal(input_ready, '1');

    elsif run("test_random_data") then
      result_is_ready <= '1';
      input_is_valid <= '1';

      for idx in 0 to 1000 loop
        stimuli_last := rnd.RandSlv(1)(1) or to_sl(idx = 1000);
        push(reference_last_queue, stimuli_last);

        stimuli_data := rnd.RandSlv(stimuli_data'length);
        push(reference_data_queue, stimuli_data);

        input_last <= stimuli_last;
        input_data <= stimuli_data;
        input_strobe <= rnd.RandSlv(input_strobe'length);
        wait until input_ready and input_valid and rising_edge(clk);
      end loop;

      input_is_valid <= '0';

      wait until
        is_empty(reference_data_queue)
        and is_empty(reference_last_queue)
        and rising_edge(clk);
    end if;

    test_runner_cleanup(runner);
  end process;


  ------------------------------------------------------------------------------
  -- Show that it can be instantiated with or without data/generics
  instantiate_dut : if data_width > 0 generate

    ------------------------------------------------------------------------------
    handshake_master_inst : entity work.handshake_master
      generic map (
        stall_config => master_stall_config,
        seed => seed,
        data_width => input_data'length,
        logger_name_suffix => " - input"
      )
      port map (
        clk => clk,
        --
        data_is_valid => input_is_valid,
        --
        ready => input_ready,
        valid => input_valid,
        last => input_last,
        data => input_data,
        strobe => input_strobe
      );


    ------------------------------------------------------------------------------
    handshake_slave_inst : entity work.handshake_slave
      generic map (
        stall_config => slave_stall_config,
        seed => seed,
        data_width => result_data'length,
        logger_name_suffix => " - result"
      )
      port map (
        clk => clk,
        --
        data_is_ready => result_is_ready,
        --
        ready => result_ready,
        valid => result_valid,
        last => result_last,
        data => result_data,
        strobe => result_strobe
      );


    ------------------------------------------------------------------------------
    data_check : process
      variable expected_data : std_ulogic_vector(result_data'range) := (others => '0');
      variable expected_last : std_ulogic := '0';
    begin
      wait until result_ready and result_valid and rising_edge(clk);

      expected_data := pop(reference_data_queue);
      check_equal(result_data, expected_data);

      expected_last := pop(reference_last_queue);
      check_equal(result_last, expected_last);
    end process;

  else generate

    ------------------------------------------------------------------------------
    handshake_master_inst : entity work.handshake_master
      generic map (
        stall_config => master_stall_config,
        seed => seed
      )
      port map (
        clk => clk,
        --
        data_is_valid => input_is_valid,
        --
        ready => input_ready,
        valid => input_valid
      );


    ------------------------------------------------------------------------------
    handshake_slave_inst : entity work.handshake_slave
      generic map (
        stall_config => slave_stall_config,
        seed => seed
      )
      port map (
        clk => clk,
        --
        ready => result_ready,
        valid => result_valid
      );

  end generate;


  ------------------------------------------------------------------------------
  -- Pass data and control signals through something that performs proper handshaking
  handshake_pipeline_inst : entity common.handshake_pipeline
    generic map (
      data_width => data_width
    )
    port map (
      clk => clk,
      --
      input_ready => input_ready,
      input_valid => input_valid,
      input_last => input_last,
      input_data => input_data,
      --
      output_ready => result_ready,
      output_valid => result_valid,
      output_last => result_last,
      output_data => result_data
    );

end architecture;
