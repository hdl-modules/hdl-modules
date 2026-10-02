-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the hdl-modules project, a collection of reusable, high-quality,
-- peer-reviewed VHDL building blocks.
-- https://hdl-modules.com
-- https://github.com/hdl-modules/hdl-modules
-- -------------------------------------------------------------------------------------------------
-- TODO will use minimal mask. Explain what that means.
-- TODO think about naming of the ports
-- -------------------------------------------------------------------------------------------------

library ieee;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;

library common;
use common.addr_pkg.all;
use common.types_pkg.all;

use work.trail_pkg.all;


entity trail_splitter is
  generic (
    -- The number of bits that are utilized on the TRAIL bus.
    address_width : trail_address_width_t;
    -- The data width of the TRAIL bus.
    data_width : trail_data_width_t;
    -- The base addresses to split the operations on.
    base_addresses : addr_vec_t
  );
  port (
    clk : in std_ulogic;
    --# {{}}
    input_operation : in trail_operation_t;
    input_response : out trail_response_t;
    --# {{}}
    result_operations : out trail_operation_vec_t(base_addresses'range) := (
      others => trail_operation_init
    );
    result_responses : in trail_response_vec_t(base_addresses'range)
  );
end entity;

architecture a of trail_splitter is

  subtype data_range is natural range data_width - 1 downto 0;

  constant base_addresses_and_mask : addr_and_mask_vec_t := calculate_minimal_mask(base_addresses);

  signal operation_select, response_select : natural range result_operations'range := 0;

  -- Pass on only the address bits that are below the base address.
  function get_port_address_width return positive is
    variable result : positive := base_addresses(0)'length;
  begin
    for address_idx in base_addresses'range loop
      for bit_idx in base_addresses(0)'range loop
        if base_addresses(address_idx)(bit_idx) then
          result := minimum(result, bit_idx);
        end if;
      end loop;
    end loop;

    return result;
  end function;
  constant port_address_width : positive := get_port_address_width;

begin

  assert base_addresses'low = 0
    report "'base_addresses' range must start at 0 for the logic to work"
    severity failure;

  assert address_width <= base_addresses(0)'length
    report "Address decode supports only widths up to " & integer'image(base_addresses(0)'length)
    severity failure;


  ------------------------------------------------------------------------------
  print_info : process
  begin
    report (
        "trail_splitter: Passing on only the lowest "
        & integer'image(port_address_width)
        & " bits of the address."
      )
      severity note;

    wait;
  end process;


  ------------------------------------------------------------------------------
  select_operation : process(all)
    variable address : u_unsigned(address_width - 1 downto 0) := (others => '0');
  begin
    address := input_operation.address(address'range);

    -- Default assignment.
    -- Will never happen unless we don't have a valid 'operation'.
    -- In which case, no response will be 'enable'd.
    -- So it's fine to have this default assignment, we don't need a special "nothing active" state.
    operation_select <= 0;

    for port_idx in result_operations'range loop
      if match(addr=>address, addr_and_mask=>base_addresses_and_mask(port_idx)) then
        operation_select <= port_idx;
      end if;
    end loop;
  end process;


  ------------------------------------------------------------------------------
  assign_operation : process(all)
  begin
    for port_idx in result_operations'range loop
      result_operations(port_idx).enable <= (
        input_operation.enable and to_sl(port_idx = operation_select)
      );

      result_operations(port_idx).address(
        port_address_width - 1 downto 0
      ) <= input_operation.address(port_address_width - 1 downto 0);

      result_operations(port_idx).write_enable <= input_operation.write_enable;

      result_operations(port_idx).write_data(data_range) <= input_operation.write_data(
        data_range
      );
    end loop;
  end process;


  ------------------------------------------------------------------------------
  select_response : process
  begin
    wait until rising_edge(clk);

    if input_operation.enable then
      response_select <= operation_select;
    end if;
  end process;

  input_response.enable <= result_responses(response_select).enable;
  input_response.status <= result_responses(response_select).status;
  input_response.read_data(data_range) <= result_responses(response_select).read_data(data_range);

end architecture;
