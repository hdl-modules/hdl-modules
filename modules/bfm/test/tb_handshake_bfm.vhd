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
use vunit_lib.queue_pkg.all;
use vunit_lib.run_pkg.all;

library bfm;
use bfm.stall_bfm_pkg.stall_configuration_t;

library common;
use common.types_pkg.all;


entity tb_handshake_bfm is
  generic (
    master_stall_probability_percent : natural;
    slave_stall_probability_percent : natural;
    seed : natural;
    runner_cfg : string
  );
end entity;

architecture tb of tb_handshake_bfm is

  constant master_stall_config : stall_configuration_t := (
    stall_probability => real(master_stall_probability_percent) / 100.0,
    min_stall_cycles => 1,
    max_stall_cycles => 5
  );

  constant slave_stall_config : stall_configuration_t := (
    stall_probability => real(slave_stall_probability_percent) / 100.0,
    min_stall_cycles => 1,
    max_stall_cycles => 5
  );

  signal clk : std_ulogic := '0';
  constant clk_period : time := 10 ns;

  signal input_ready, input_valid, result_ready, result_valid, input_last, result_last : std_ulogic
    := '0';
  signal input_data, result_data : std_ulogic_vector(8 - 1 downto 0) := (others => '0');

  signal result_is_ready, input_is_valid : std_ulogic := '0';

  signal transaction_count : natural := 0;

begin

  test_runner_watchdog(runner, 2 ms);
  clk <= not clk after clk_period / 2;


  ------------------------------------------------------------------------------
  main : process
    variable rnd : RandomPType;
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

      wait until result_valid'event for 1000 * clk_period;
      check_equal(result_valid, '1');

      -- Should still be full throughput even when we start popping words
      result_is_ready <= '1';
      wait until result_valid'event for 1000 * clk_period;
      check_equal(result_valid, '1');

    elsif run("test_full_slave_throughput") then
      result_is_ready <= '1';

      wait until rising_edge(clk);
      check_equal(input_ready, '1');

      wait until input_ready'event for 1000 * clk_period;
      check_equal(input_ready, '1');

      -- Should still be full throughput even when we start popping words
      input_is_valid <= '1';
      wait until input_ready'event for 1000 * clk_period;
      check_equal(input_ready, '1');

    end if;

    check_relation(transaction_count > 50);

    test_runner_cleanup(runner);
  end process;


  ------------------------------------------------------------------------------
  count : process
  begin
    wait until rising_edge(clk);

    transaction_count <= transaction_count + to_int(input_ready and input_valid);
  end process;


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
  input_axi_stream_protocol_checker_inst : entity common.axi_stream_protocol_checker
    generic map (
      logger_name_suffix => " - input"
    )
    port map (
      clk => clk,
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


  ------------------------------------------------------------------------------
  result_axi_stream_protocol_checker_inst : entity common.axi_stream_protocol_checker
    generic map (
      data_width => result_data'length,
      logger_name_suffix => " - result"
    )
    port map (
      clk => clk,
      --
      ready => result_ready,
      valid => result_valid,
      last => result_last,
      data => result_data
    );


  ------------------------------------------------------------------------------
  -- Pass data and control signals through something that performs proper handshaking
  handshake_pipeline_inst : entity common.handshake_pipeline
    generic map (
      data_width => input_data'length
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
