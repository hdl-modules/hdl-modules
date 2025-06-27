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
use bfm.queue_bfm_pkg.all;
use bfm.stall_bfm_pkg.all;

library common;
use common.addr_pkg.all;

use work.trail_pkg.all;
use work.trail_sim_pkg.all;


entity tb_trail_splitter is
  generic (
    runner_cfg : string
  );
end entity;

architecture tb of tb_trail_splitter is

  -- Generic constants.
  constant address_width : trail_address_width_t := 24;
  constant data_width : trail_data_width_t := trail_max_data_width;
  constant bytes_per_beat : positive := data_width / 8;

  shared variable rnd : RandomPType;

  constant max_num_ports : positive := 32;
  impure function initialize_and_get_num_ports return positive is
  begin
    -- This is the first function that is called, so we initialize the random number generator here.
    rnd.InitSeed(get_string_seed(runner_cfg));

    return rnd.Uniform(1, max_num_ports);
  end function;

  constant num_ports : positive := initialize_and_get_num_ports;

  function check_addresses_valid(
    addresses : addr_vec_t(0 to num_ports - 1); num_to_test : natural
  ) return boolean is
  begin
    for port_idx in 0 to num_to_test - 1 loop
      for test_idx in 0 to num_to_test - 1 loop
        if port_idx /= test_idx then
          if addresses(port_idx) = addresses(test_idx) then
            return false;
          end if;
        end if;
      end loop;
    end loop;

    return true;
  end function;

  impure function get_base_address_alignment return positive is
  begin
    return 1024 * 2 ** rnd.Uniform(0, 3);
  end function;
  constant base_address_alignment : positive := get_base_address_alignment;

  impure function get_base_addresses return addr_vec_t is
    variable result : addr_vec_t(0 to num_ports - 1) := (others => (others => '0'));
    variable address : natural := 0;
  begin
    for port_idx in 0 to num_ports - 1 loop
      assign_end_check_if_valid : loop
        address := base_address_alignment * rnd.Uniform(0, 1337);
        result(port_idx) := to_unsigned(address, result(0)'length);

        if check_addresses_valid(addresses=>result, num_to_test=>port_idx + 1) then
          exit assign_end_check_if_valid;
        end if;
      end loop;
    end loop;
    return result;
  end function;
  constant base_addresses : addr_vec_t(0 to num_ports - 1) := get_base_addresses;

  -- DUT connections.
  signal clk : std_ulogic := '0';

  signal input_operation : trail_operation_t := trail_operation_init;
  signal input_response : trail_response_t := trail_response_init;

  signal result_operations : trail_operation_vec_t(base_addresses'range) := (
    others => trail_operation_init
  );
  signal result_responses : trail_response_vec_t(base_addresses'range) := (
    others => trail_response_init
  );

  -- Testbench stuff.
  constant stall_config : stall_configuration_t := (
    stall_probability=>0.2, min_stall_cycles=>1, max_stall_cycles=>10
  );

  constant input_command_queue : queue_t := new_queue;
  constant result_command_queue : queue_vec_t(result_operations'range) := get_new_queues(
    count=>result_operations'length
  );

  signal master_num_processed : natural := 0;

begin

  clk <= not clk after 5 ns;
  test_runner_watchdog(runner, 100 us);


  ------------------------------------------------------------------------------
  main : process

    procedure test_random_transactions is
      variable port_idx : natural := 0;
      variable address : addr_t := (others => '0');
      variable command : trail_bfm_command_t := trail_bfm_command_init;
    begin
      get_random_trail_bfm_command(
        address_width=>address_width, data_width=>data_width, rnd=>rnd, command=>command
      );

      port_idx := rnd.Uniform(base_addresses'low, base_addresses'high);
      address := (
        base_addresses(port_idx)
        + (rnd.Uniform(0, base_address_alignment - 1) / bytes_per_beat) * bytes_per_beat
      );

      command.address := (address'range => address, others => '0');
      push(input_command_queue, to_slv(command));

      command.address := command.address mod base_address_alignment;
      push(result_command_queue(port_idx), to_slv(command));
    end procedure;

  begin
    test_runner_setup(runner, runner_cfg);

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
      command_queue => input_command_queue,
      stall_config => stall_config,
      logger_name_suffix => " - input"
    )
    port map (
      clk => clk,
      --
      trail_operation => input_operation,
      trail_response => input_response,
      --
      num_processed => master_num_processed
    );


  ------------------------------------------------------------------------------
  trail_bfm_slave_gen : for port_idx in result_operations'range generate

    ------------------------------------------------------------------------------
    trail_bfm_slave_inst : entity work.trail_bfm_slave
      generic map (
        address_width => address_width,
        data_width => data_width,
        command_queue => result_command_queue(port_idx),
        stall_config => stall_config,
        logger_name_suffix => " - result port " & to_string(port_idx)
      )
      port map (
        clk => clk,
        --
        trail_operation => result_operations(port_idx),
        trail_response => result_responses(port_idx)
      );

  end generate;


  ------------------------------------------------------------------------------
  dut : entity work.trail_splitter
    generic map (
      data_width => data_width,
      address_width => address_width,
      base_addresses => base_addresses
    )
    port map (
      clk => clk,
      --
      input_operation => input_operation,
      input_response => input_response,
      --
      result_operations => result_operations,
      result_responses => result_responses
    );

end architecture;
