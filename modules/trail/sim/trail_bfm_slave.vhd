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


entity trail_bfm_slave is
  generic (
    address_width : trail_address_width_t;
    data_width : trail_data_width_t;
    -- Push commands (to_slv() of 'trail_bfm_command_t') to this queue.
    command_queue : queue_t;
    -- Assign non-zero to randomly insert a delay before the 'response' is sent.
    stall_config : stall_configuration_t := zero_stall_configuration;
    -- Suffix for error log messages. Can be used to differentiate between multiple instances.
    logger_name_suffix : string := ""
  );
  port (
    clk : in std_ulogic;
    --# {{}}
    trail_operation : in trail_operation_t;
    trail_response : out trail_response_t := trail_response_init;
    --# {{}}
    num_processed : out natural := 0
  );
end entity;

architecture a of trail_bfm_slave is

  constant num_unaligned_address_bits : natural := trail_num_unaligned_address_bits(
    data_width=>data_width
  );

  constant base_error_message : string := (
    "trail_bfm_slave" & logger_name_suffix & ": 'operation' #"
  );

begin

  ------------------------------------------------------------------------------
  trail_protocol_checker_inst : entity work.trail_protocol_checker
    generic map (
      address_width => address_width,
      data_width => data_width,
      logger_name_suffix => " - trail_bfm_slave" & logger_name_suffix
    )
    port map (
      clk => clk,
      --
      trail_operation => trail_operation,
      trail_response => trail_response
    );


  ------------------------------------------------------------------------------
  main : process
    procedure drive_response_payload_invalid is
    begin
      trail_response.status <= trail_response_status_error;
      trail_response.read_data <= (others => 'X');
    end procedure;

    variable seed : string_seed_t;
    variable rnd : RandomPType;

    variable command_slv : std_logic_vector(trail_bfm_command_width - 1 downto 0) := (
      others => '0'
    );
    variable command : trail_bfm_command_t := trail_bfm_command_init;

    variable got_address, expected_address : u_unsigned(
      address_width - 1 downto num_unaligned_address_bits
    ) := (others => '0');

    variable got_data, expected_data : std_ulogic_vector(data_width - 1 downto 0) := (
      others => '0'
    );
  begin
    -- Use salt so that parallel instances of this entity get unique random sequences.
    get_seed(seed, salt=>trail_bfm_slave'path_name);
    rnd.InitSeed(seed);

    drive_response_payload_invalid;

    loop
      wait until trail_operation.enable = '1' and rising_edge(clk);

      assert not is_empty(command_queue) report "Got 'operation' with no 'command' reference";
      command_slv := pop(command_queue);
      command := to_trail_bfm_command(command_slv);

      drive_response_payload_invalid;

      got_address := trail_operation.address(got_address'range);
      expected_address := command.address(expected_address'range);
      assert got_address = expected_address
        report (
          base_error_message
          & to_string(num_processed)
          & ": 'address' mismatch, got "
          & to_string(got_address)
          & " expected "
          & to_string(expected_address)
        );

      assert trail_operation.write_enable = command.write_enable
        report (
          base_error_message
          & to_string(num_processed)
          & ": 'write_enable' mismatch, got "
          & to_string(trail_operation.write_enable)
          & " expected "
          & to_string(command.write_enable)
        );

      if command.write_enable then
        got_data := trail_operation.write_data(got_data'range);
        expected_data := command.data(expected_data'range);

        assert got_data = expected_data
          report (
            base_error_message
            & to_string(num_processed)
            & ": 'write_data' mismatch, got "
            & to_string(got_data)
            & " expected "
            & to_string(expected_data)
          );
      end if;

      random_stall(stall_config=>stall_config, rnd=>rnd, clk=>clk);

      trail_response.enable <= '1';

      if command.expect_error then
        trail_response.status <= trail_response_status_error;
      else
        trail_response.status <= trail_response_status_okay;

        if not command.write_enable then
          trail_response.read_data(got_data'range) <= command.data(got_data'range);
        end if;
      end if;

      num_processed <= num_processed + 1;

      wait until rising_edge(clk);
      trail_response.enable <= '0';
    end loop;
  end process;

end architecture;
