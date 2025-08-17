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

library common;
use common.types_pkg.is_01;

use work.trail_pkg.all;


entity trail_protocol_checker is
  generic (
    address_width : trail_address_width_t;
    data_width : trail_data_width_t;
    -- Suffix for error log messages. Can be used to differentiate between multiple instances.
    logger_name_suffix : string := ""
  );
  port (
    clk : in std_ulogic;
    --# {{}}
    trail_operation : in trail_operation_t;
    trail_response : in trail_response_t
  );
end entity;

architecture a of trail_protocol_checker is

  constant num_unaligned_address_bits : natural := trail_num_unaligned_address_bits(
    data_width=>data_width
  );
  subtype aligned_address_range is
    natural range address_width - 1 downto num_unaligned_address_bits;

  subtype data_range is natural range data_width - 1 downto 0;

  constant base_error_message : string := "trail_protocol_checker" & logger_name_suffix & ": ";

begin

  ------------------------------------------------------------------------------
  assert sanity_check_trail_widths(address_width=>address_width, data_width=>data_width)
    report base_error_message & "Invalid TRAIL bus width(s), see printout above."
    severity failure;


  ------------------------------------------------------------------------------
  operation_enable_well_defined_block : block
    constant error_message : string := (
      base_error_message & "'operation.enable' has undefined value."
    );
  begin

    ------------------------------------------------------------------------------
    operation_enable_well_defined_check : process
    begin
      wait until rising_edge(clk);

      assert is_01(trail_operation.enable) report error_message;
    end process;

  end block;


  ------------------------------------------------------------------------------
  operation_well_defined_when_enabled_block : block
    constant address_error_message : string := (
      base_error_message & "'operation.address' has undefined value."
    );
    constant write_enable_error_message : string := (
      base_error_message & "'operation.write_enable' has undefined value."
    );
    constant write_data_error_message : string := (
      base_error_message & "'operation.write_data' has undefined value."
    );
  begin

    ------------------------------------------------------------------------------
    operation_well_defined_when_enabled_check : process
    begin
      wait until trail_operation.enable = '1' and rising_edge(clk);

      assert is_01(trail_operation.address(aligned_address_range)) report address_error_message;
      assert is_01(trail_operation.write_enable) report write_enable_error_message;

      if trail_operation.write_enable then
        assert is_01(trail_operation.write_data(data_range)) report write_data_error_message;
      end if;
    end process;

  end block;


  ------------------------------------------------------------------------------
  operation_address_aligned_when_enabled_gen : if num_unaligned_address_bits > 0 generate
    subtype address_unaligned_range is natural range num_unaligned_address_bits - 1 downto 0;
    constant address_unaligned_error_message : string := (
      base_error_message
      & "'operation.address' is not aligned with "
      & to_string(data_width / 8)
      & "-byte data."
    );
  begin

    ------------------------------------------------------------------------------
    operation_address_aligned_when_enabled_check : process
    begin
      wait until trail_operation.enable = '1' and rising_edge(clk);

      assert trail_operation.address(address_unaligned_range) = 0
        report address_unaligned_error_message;
    end process;

  end generate;


  ------------------------------------------------------------------------------
  response_enable_well_defined_block : block
    constant error_message : string := (
      base_error_message & "'response.enable' has undefined value."
    );
  begin

    ------------------------------------------------------------------------------
    response_enable_well_defined_check : process
    begin
      wait until rising_edge(clk);

      assert is_01(trail_response.enable) report error_message;
    end process;

  end block;


  ------------------------------------------------------------------------------
  response_well_defined_when_enabled_block : block
    constant read_data_error_message : string := (
      base_error_message & "'response.read_data' has undefined value."
    );
  begin

    ------------------------------------------------------------------------------
    response_well_defined_when_enabled_check : process
    begin
      wait until trail_response.enable = '1' and rising_edge(clk);

      if (
        trail_operation.write_enable = '0' and trail_response.status = trail_response_status_okay
      ) then
        assert is_01(trail_response.read_data(data_range)) report read_data_error_message;
      end if;
    end process;

  end block;


  ------------------------------------------------------------------------------
  handshaking_block : block
    type state_t is (wait_for_operation, wait_for_response);
    signal state : state_t := wait_for_operation;
  begin

    ------------------------------------------------------------------------------
    not_out_of_sync_check : process
      constant operation_error_message : string := (
        base_error_message & "Got 'response' before a corresponding 'operation'."
      );
      constant response_error_message : string := (
        base_error_message
        & "Got 'operation' while waiting for "
        & "'response' to a previous 'operation'."
      );
      constant at_the_same_time_error_message : string := (
        base_error_message & "Got 'operation' and 'response' at the same time."
      );
    begin
      wait until rising_edge(clk);

      case state is
        when wait_for_operation =>
          assert not trail_response.enable report operation_error_message;

          if trail_operation.enable then
            state <= wait_for_response;
          end if;

        when wait_for_response =>
          assert not trail_operation.enable report response_error_message;

          if trail_response.enable then
            state <= wait_for_operation;
          end if;

      end case;

      assert not (trail_operation.enable and trail_response.enable)
        report at_the_same_time_error_message;
    end process;

  end block;


  ------------------------------------------------------------------------------
  enabled_operation_does_not_change_until_response_check : process
    constant address_error_message : string := (
      base_error_message & "Enabled 'operation.address' changed value before 'response'."
    );
    constant write_enable_error_message : string := (
      base_error_message & "Enabled 'operation.write_enable' changed value before 'response'."
    );
    constant write_data_error_message : string := (
      base_error_message & "Enabled 'operation.write_data' changed value before 'response'."
    );

    variable expected_operation : trail_operation_t := trail_operation_init;
  begin
    wait until trail_operation.enable = '1' and rising_edge(clk);

    expected_operation := trail_operation;

    check_loop : loop
      wait until rising_edge(clk);

      assert (
          trail_operation.address(aligned_address_range)
          = expected_operation.address(aligned_address_range)
        )
        report address_error_message;

      assert trail_operation.write_enable = expected_operation.write_enable
        report write_enable_error_message;

      if trail_operation.write_enable then
        assert trail_operation.write_data(data_range) = expected_operation.write_data(data_range)
          report write_data_error_message;
      end if;

      -- When a 'response' comes, we should stop checking.
      if trail_response.enable then
        exit check_loop;
      end if;
    end loop;
  end process;


  ------------------------------------------------------------------------------
  enabled_response_does_not_change_until_next_operation_check : process
    constant status_error_message : string := (
      base_error_message & "Enabled 'response.status' changed value before next 'operation'."
    );
    constant read_data_error_message : string := (
      base_error_message & "Enabled 'response.read_data' changed value before 'operation'."
    );

    variable expected_response : trail_response_t := trail_response_init;
  begin
    wait until trail_response.enable = '1' and rising_edge(clk);

    expected_response := trail_response;

    check_loop : loop
      wait until rising_edge(clk);

      assert trail_response.status = expected_response.status report status_error_message;

      if not trail_operation.write_enable then
        assert trail_response.read_data(data_range) = expected_response.read_data(data_range)
          report read_data_error_message;
      end if;

      -- When new 'operation' comes, we should stop checking.
      if trail_operation.enable then
        exit check_loop;
      end if;
    end loop;
  end process;

end architecture;
