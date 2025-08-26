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
use vunit_lib.queue_pkg.all;
use vunit_lib.run_pkg.all;

library bfm;
use bfm.stall_bfm_pkg.all;

library common;
use common.time_pkg.all;

use work.trail_pkg.all;
use work.trail_sim_pkg.all;


entity tb_trail_cdc is
  generic (
    address_width : trail_address_width_t;
    data_width : trail_data_width_t;
    use_lutram : boolean;
    -- TODO remove
    use_lutram_output_register : boolean;
    runner_cfg : string
  );
end entity;

architecture tb of tb_trail_cdc is

  -- Generic constants.
  shared variable rnd : RandomPType;

  impure function get_random_frequency_mhz return real is
  begin
    return rnd.RandReal(1.0, 100.0);
  end function;

  impure function initialize_and_get_random_frequency_mhz return real is
  begin
    -- This is the first function that is called, so we initialize the random number generator here.
    rnd.InitSeed(get_string_seed(runner_cfg));

    return get_random_frequency_mhz;
  end function;

  -- Initialize random seed in the first call.
  -- Should give us a random sequence for each test run.
  constant input_frequency_hz : real := initialize_and_get_random_frequency_mhz * 1.0e6;
  constant result_frequency_hz : real := get_random_frequency_mhz * 1.0e6;

  constant input_period : time := to_period(frequency_hz=>input_frequency_hz);
  constant result_period : time := to_period(frequency_hz=>result_frequency_hz);

  -- DUT connections.
  signal input_clk, result_clk : std_ulogic := '0';

  signal input_operation, result_operation : trail_operation_t := trail_operation_init;
  signal input_response, result_response : trail_response_t := trail_response_init;

  -- Testbench stuff.
  constant stall_config : stall_configuration_t := (
    stall_probability=>0.2, min_stall_cycles=>1, max_stall_cycles=>10
  );

  constant master_command_queue, slave_command_queue : queue_t := new_queue;

  signal master_num_processed : natural := 0;

begin

  input_clk <= not input_clk after input_period / 2;
  result_clk <= not result_clk after result_period / 2;

  test_runner_watchdog(runner, 100 ms);


  ------------------------------------------------------------------------------
  main : process

    procedure test_random_transactions is
      variable command : trail_bfm_command_t := trail_bfm_command_init;
    begin
      get_random_trail_bfm_command(
        address_width=>address_width, data_width=>data_width, rnd=>rnd, command=>command
      );

      push(master_command_queue, to_slv(command));
      push(slave_command_queue, to_slv(command));
    end procedure;

  begin
    test_runner_setup(runner, runner_cfg);

    report "input_frequency_hz = " & to_string(input_frequency_hz);
    report "result_frequency_hz = " & to_string(result_frequency_hz);

    if run("test_random_transactions") then
      for idx in 0 to 100 - 1 loop
        test_random_transactions;
      end loop;

      wait until master_num_processed = 100 and rising_edge(input_clk);
    end if;

    test_runner_cleanup(runner);
  end process;


  ------------------------------------------------------------------------------
  trail_bfm_master_inst : entity work.trail_bfm_master
    generic map (
      address_width => address_width,
      data_width => data_width,
      command_queue => master_command_queue,
      stall_config => stall_config,
      logger_name_suffix => " - input side"
    )
    port map (
      clk => input_clk,
      --
      trail_operation => input_operation,
      trail_response => input_response,
      --
      num_processed => master_num_processed
    );


  ------------------------------------------------------------------------------
  trail_bfm_slave_inst : entity work.trail_bfm_slave
    generic map (
      address_width => address_width,
      data_width => data_width,
      command_queue => slave_command_queue,
      stall_config => stall_config,
      logger_name_suffix => " - result side"
    )
    port map (
      clk => result_clk,
      --
      trail_operation => result_operation,
      trail_response => result_response
    );


  ------------------------------------------------------------------------------
  dut : entity work.trail_cdc
    generic map (
      address_width => address_width,
      data_width => data_width,
      use_lutram => use_lutram,
      use_lutram_output_register => use_lutram_output_register
    )
    port map (
      input_clk => input_clk,
      input_operation => input_operation,
      input_response => input_response,
      --
      result_clk => result_clk,
      result_operation => result_operation,
      result_response => result_response
    );

end architecture;
