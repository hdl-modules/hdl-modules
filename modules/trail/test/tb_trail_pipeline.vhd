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

use work.trail_pkg.all;
use work.trail_sim_pkg.all;


entity tb_trail_pipeline is
  generic (
    address_width : trail_address_width_t;
    data_width : trail_data_width_t;
    runner_cfg : string
  );
end entity;

architecture tb of tb_trail_pipeline is

  -- Generic constants.
  shared variable rnd : RandomPType;

  impure function get_random_bool return boolean is
  begin
    return rnd.RandBool;
  end function;

  impure function initialize_and_get_random_bool return boolean is
  begin
    -- This is the first function that is called, so we initialize the random number generator here.
    rnd.InitSeed(get_string_seed(runner_cfg));

    return get_random_bool;
  end function;

  -- Initialize random seed in the first call.
  -- Should give us a random sequence for each test run.
  constant pipeline_operation_enable : boolean := initialize_and_get_random_bool;
  constant pipeline_operation_address : boolean := get_random_bool;
  constant pipeline_operation_write_enable : boolean := get_random_bool;
  constant pipeline_operation_write_data : boolean := get_random_bool;
  constant pipeline_response_enable : boolean := get_random_bool;
  constant pipeline_response_status : boolean := get_random_bool;
  constant pipeline_response_read_data : boolean := get_random_bool;

  -- DUT connections.
  signal clk : std_ulogic := '0';

  signal operation, pipelined_operation : trail_operation_t := trail_operation_init;
  signal response, pipelined_response : trail_response_t := trail_response_init;

  -- Testbench stuff.
  constant stall_config : stall_configuration_t := (
    stall_probability=>0.2, min_stall_cycles=>1, max_stall_cycles=>10
  );

  constant master_command_queue, slave_command_queue : queue_t := new_queue;

  signal master_num_processed : natural := 0;

begin

  clk <= not clk after 5 ns;
  test_runner_watchdog(runner, 100 us);


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

    report "pipeline_operation_enable = " & to_string(pipeline_operation_enable);
    report "pipeline_operation_address = " & to_string(pipeline_operation_address);
    report "pipeline_operation_write_enable = " & to_string(pipeline_operation_write_enable);
    report "pipeline_operation_write_data = " & to_string(pipeline_operation_write_data);
    report "pipeline_response_enable = " & to_string(pipeline_response_enable);
    report "pipeline_response_status = " & to_string(pipeline_response_status);
    report "pipeline_response_read_data = " & to_string(pipeline_response_read_data);

    if run("test_random_transactions") then
      for idx in 0 to 100 - 1 loop
        test_random_transactions;
      end loop;

      wait until master_num_processed = 100 and rising_edge(clk);
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
      clk => clk,
      --
      trail_operation => operation,
      trail_response => pipelined_response,
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
      clk => clk,
      --
      trail_operation => pipelined_operation,
      trail_response => response
    );


  ------------------------------------------------------------------------------
  dut : entity work.trail_pipeline
    generic map (
      address_width => address_width,
      data_width => data_width,
      pipeline_operation_enable => pipeline_operation_enable,
      pipeline_operation_address => pipeline_operation_address,
      pipeline_operation_write_enable => pipeline_operation_write_enable,
      pipeline_operation_write_data => pipeline_operation_write_data,
      pipeline_response_enable => pipeline_response_enable,
      pipeline_response_status => pipeline_response_status,
      pipeline_response_read_data => pipeline_response_read_data
    )
    port map (
      clk => clk,
      --
      operation => operation,
      pipelined_operation => pipelined_operation,
      --
      response => response,
      pipelined_response => pipelined_response
    );

end architecture;
