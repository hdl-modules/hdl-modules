-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the hdl-modules project, a collection of reusable, high-quality,
-- peer-reviewed VHDL building blocks.
-- https://hdl-modules.com
-- https://github.com/hdl-modules/hdl-modules
-- -------------------------------------------------------------------------------------------------
-- TODO
-- TODO make this a wrapper around trail_bfm_master
-- -------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
use vunit_lib.axi_lite_master_pkg.all;
use vunit_lib.bus_master_pkg.address_length;
use vunit_lib.bus_master_pkg.bus_master_t;
use vunit_lib.bus_master_pkg.data_length;
use vunit_lib.com_pkg.net;
use vunit_lib.com_pkg.receive;
use vunit_lib.com_pkg.reply;
use vunit_lib.com_types_pkg.all;
use vunit_lib.log_levels_pkg.all;
use vunit_lib.logger_pkg.all;
use vunit_lib.queue_pkg.all;
use vunit_lib.sync_pkg.all;

library common;
use common.types_pkg.to_sl;

library register_file;
use register_file.register_operations_pkg.register_bus_master;

use work.trail_pkg.all;


entity trail_bfm_master_old is
  generic (
    bus_handle : bus_master_t := register_bus_master;
    -- Suffix for error log messages. Can be used to differentiate between multiple instances.
    logger_name_suffix : string := ""
  );
  port (
    clk : in std_ulogic;
    --# {{}}
    trail_operation : out trail_operation_t := trail_operation_init;
    trail_response : in trail_response_t
  );
end entity;

architecture a of trail_bfm_master_old is

  constant message_queue : queue_t := new_queue;
  signal idle : boolean := true;

  subtype address_range is natural range address_length(bus_handle) - 1 downto 0;
  subtype data_range is natural range data_length(bus_handle) - 1 downto 0;

begin

  ------------------------------------------------------------------------------
  trail_protocol_checker_inst : entity work.trail_protocol_checker
    generic map (
      address_width => address_length(bus_handle),
      data_width => data_length(bus_handle),
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
    variable request_msg : msg_t := null_msg;
    variable msg_type : msg_type_t := null_msg_type;
  begin
    receive(net, bus_handle.p_actor, request_msg);
    msg_type := message_type(request_msg);

    if is_read(msg_type) or is_write(msg_type) then
      push(message_queue, request_msg);

    elsif msg_type = wait_until_idle_msg then
      if not idle or not is_empty(message_queue) then
        wait until idle and is_empty(message_queue) and rising_edge(clk);
      end if;

      handle_wait_until_idle(net, msg_type, request_msg);

    else
      unexpected_msg_type(msg_type);
    end if;
  end process;


  ------------------------------------------------------------------------------
  -- Use separate process that is synchronous.
  bus_process : process
    procedure drive_operation_payload_invalid is
    begin
      trail_operation.address <= (others => 'X');
      trail_operation.write_enable <= 'X';
      trail_operation.write_data <= (others => 'X');
    end procedure;

    procedure check_response_status(expected : trail_response_status_t) is
      function describe(value : trail_response_status_t) return string is
      begin
        return "'" & to_string(value) & "'";
      end function;
      constant got : trail_response_status_t := trail_response.status;
    begin
      if got /= expected then
        failure(
          bus_handle.p_logger,
          "Got trail 'response.status' "
          & describe(got)
          & "', expected "
          & describe(expected)
          & "."
        );
      end if;
    end;

    variable request_msg, reply_msg : msg_t := null_msg;
    variable msg_type : msg_type_t := null_msg_type;

    variable address_this_transaction : std_logic_vector(address_range) := (others => '0');
    variable data_this_transaction : std_logic_vector(data_range) := (others => '0');
  begin
    -- Initialization
    drive_operation_payload_invalid;

    loop
      wait until rising_edge(clk) and not is_empty(message_queue);
      idle <= false;
      wait for 0 ps;

      request_msg := pop(message_queue);
      msg_type := message_type(request_msg);

      trail_operation.enable <= '1';

      address_this_transaction := pop_std_ulogic_vector(request_msg);
      trail_operation.address(address_this_transaction'range) <= unsigned(address_this_transaction);

      trail_operation.write_enable <= to_sl(is_write(msg_type));

      if is_write(msg_type) then
        data_this_transaction := pop_std_ulogic_vector(request_msg);
        trail_operation.write_data(data_this_transaction'range) <= data_this_transaction;
      end if;

      wait until rising_edge(clk);
      trail_operation.enable <= '0';

      wait until trail_response.enable = '1' and rising_edge(clk);

      drive_operation_payload_invalid;

      check_response_status(expected=>trail_response_status_okay);

      if is_read(msg_type) then
        data_this_transaction := trail_response.read_data(data_this_transaction'range);

        reply_msg := new_msg;
        push_std_ulogic_vector(reply_msg, data_this_transaction);
        reply(net, request_msg, reply_msg);
      end if;

      if is_visible(bus_handle.p_logger, debug) then
        if is_read(msg_type) then
          debug(bus_handle.p_logger,
            "Read 0x" & to_hstring(data_this_transaction)
            & " from address 0x" & to_hstring(address_this_transaction)
          );

        elsif is_write(msg_type) then
          debug(bus_handle.p_logger,
            "Wrote 0x" & to_hstring(data_this_transaction)
            & " to address 0x" & to_hstring(address_this_transaction)
          );
        end if;
      end if;

      delete(request_msg);

      idle <= true;
    end loop;
  end process;

end architecture;
