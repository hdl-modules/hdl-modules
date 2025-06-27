-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the hdl-modules project, a collection of reusable, high-quality,
-- peer-reviewed VHDL building blocks.
-- https://hdl-modules.com
-- https://github.com/hdl-modules/hdl-modules
-- -------------------------------------------------------------------------------------------------
-- TODO
-- -------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library osvvm;
use osvvm.RandomPkg.RandomPType;

library vunit_lib;
use vunit_lib.queue_pkg.all;
use vunit_lib.run_pkg.all;
use vunit_lib.run_types_pkg.all;

library bfm;
use bfm.stall_bfm_pkg.all;

use work.trail_pkg.all;
use work.trail_sim_pkg.all;


entity trail_bfm_master is
  generic (
    address_width : trail_address_width_t;
    data_width : trail_data_width_t;
    -- Push commands (to_slv() of 'trail_bfm_command_t') to this queue.
    command_queue : queue_t;
    -- Assign non-zero to randomly insert a delay before the 'operation' is sent.
    stall_config : stall_configuration_t := zero_stall_configuration;
    -- Suffix for error log messages. Can be used to differentiate between multiple instances.
    logger_name_suffix : string := ""
  );
  port (
    clk : in std_ulogic;
    --# {{}}
    trail_operation : out trail_operation_t := trail_operation_init;
    trail_response : in trail_response_t;
    --# {{}}
    num_processed : out natural := 0
  );
end entity;

architecture a of trail_bfm_master is

  constant base_error_message : string := (
    "trail_bfm_master" & logger_name_suffix & ": 'operation' #"
  );

begin

  ------------------------------------------------------------------------------
  trail_protocol_checker_inst : entity work.trail_protocol_checker
    generic map (
      address_width => address_width,
      data_width => data_width,
      logger_name_suffix => " - trail_bfm_master" & logger_name_suffix
    )
    port map (
      clk => clk,
      --
      trail_operation => trail_operation,
      trail_response => trail_response
    );


  ------------------------------------------------------------------------------
  main : process
    variable seed : string_seed_t;
    variable rnd : RandomPType;

    variable command_slv : std_logic_vector(trail_bfm_command_width - 1 downto 0) := (
      others => '0'
    );
    variable command : trail_bfm_command_t := trail_bfm_command_init;

    variable expected_status : trail_response_status_t := trail_response_status_okay;

    variable got_data, expected_data : std_ulogic_vector(data_width - 1 downto 0) := (
      others => '0'
    );
  begin
    -- Use salt so that parallel instances of this entity get unique random sequences.
    get_seed(seed, salt=>trail_bfm_master'path_name);
    rnd.InitSeed(seed);

    loop
      -- Set 'operation' payload invalid.
      -- This happens initially and after each received 'response'.
      trail_operation.address <= (others => 'X');
      trail_operation.write_enable <= 'X';
      trail_operation.write_data <= (others => 'X');

      while is_empty(command_queue) loop
        wait until rising_edge(clk);
      end loop;
      command_slv := pop(command_queue);
      command := to_trail_bfm_command(command_slv);

      random_stall(stall_config=>stall_config, rnd=>rnd, clk=>clk);

      trail_operation.enable <= '1';
      trail_operation.address <= command.address;
      trail_operation.write_enable <= command.write_enable;
      if command.write_enable then
        trail_operation.write_data(data_width - 1 downto 0) <= command.data(
          data_width - 1 downto 0
        );
      end if;

      wait until rising_edge(clk);
      trail_operation.enable <= '0';

      wait until trail_response.enable = '1' and rising_edge(clk);

      if command.expect_error then
        expected_status := trail_response_status_error;
      else
        expected_status := trail_response_status_okay;
      end if;

      assert trail_response.status = expected_status
        report (
          base_error_message
          & to_string(num_processed)
          & ": 'status' mismatch, got "
          & to_string(trail_response.status)
          & " expected "
          & to_string(expected_status)
        );

      if (not command.write_enable) and (not command.expect_error) then
        got_data := trail_response.read_data(got_data'range);
        expected_data := command.data(data_width - 1 downto 0);
        assert got_data = expected_data
          report (
            base_error_message
            & to_string(num_processed)
            & ": 'read_data' mismatch, got "
            & to_string(got_data)
            & " expected "
            & to_string(expected_data)
          );
      end if;

      num_processed <= num_processed + 1;
    end loop;
  end process;

end architecture;
