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
use common.addr_pkg.all;

library math;
use math.math_pkg.all;

library trail;
use trail.trail_pkg.all;

use work.register_file_pkg.all;


entity trail_register_file is
  generic (
    registers : register_definition_vec_t;
    default_values : register_vec_t(registers'range) := (others => (others => '0'))
  );
  port (
    clk : in std_ulogic;
    --# {{}}
    --# Register control bus
    trail_operation : in trail_operation_t;
    trail_response : out trail_response_t := trail_response_init;
    --# {{}}
    -- Register values
    regs_up : in register_vec_t(registers'range) := default_values;
    regs_down : out register_vec_t(registers'range) := default_values;
    --# {{}}
    -- Each bit is pulsed for one cycle when the corresponding register is read/written.
    reg_was_read : out std_ulogic_vector(registers'range) := (others => '0');
    reg_was_written : out std_ulogic_vector(registers'range) := (others => '0')
  );
end entity;

architecture a of trail_register_file is

  constant num_addr_bits : positive := num_bits_needed(get_highest_index(registers));
  subtype addr_range is natural range num_addr_bits + 2 - 1 downto 2;

  signal reg_values : register_vec_t(registers'range) := default_values;

  signal is_read_operation, is_write_operation : boolean := false;
  signal operation_index : u_unsigned(num_addr_bits - 1 downto 0) := (others => '0');

begin

  ------------------------------------------------------------------------------
  assign_down : process(all)
  begin
    -- Assign only the bits that are marked as utilized, so there is no risk of confusion/misuse.
    for reg_idx in registers'range loop
      if is_write_mode(registers(reg_idx).mode) then
        regs_down(reg_idx)(registers(reg_idx).utilized_width - 1 downto 0) <= reg_values(reg_idx)(
          registers(reg_idx).utilized_width - 1 downto 0
        );
      end if;
    end loop;
  end process;

  is_read_operation <= trail_operation.enable = '1' and trail_operation.write_enable = '0';
  is_write_operation <= trail_operation.enable = '1' and trail_operation.write_enable = '1';

  operation_index <= trail_operation.address(addr_range);


  ------------------------------------------------------------------------------
  set_reg_was_read : process(all)
  begin
    reg_was_read <= (others => '0');

    for reg_idx in registers'range loop
      if is_read_mode(registers(reg_idx).mode) then
        if is_read_operation and operation_index = reg_idx then
          reg_was_read(reg_idx) <= '1';
        end if;
      end if;
    end loop;
  end process;


  ------------------------------------------------------------------------------
  main : process
  begin
    wait until rising_edge(clk);

    reg_was_written <= (others => '0');

    -- Respond straight away and unconditionally.
    trail_response.enable <= trail_operation.enable;

    if trail_operation.enable then
      -- Set a default status. Will be overwritten below if the 'operation' is valid.
      trail_response.status <= trail_response_status_error;
    end if;

    for reg_idx in registers'range loop
      if is_read_mode(registers(reg_idx).mode) then
        if is_read_operation and operation_index = reg_idx then
          -- Set initial values zero.
          -- Below we will only assign the bits that are actually utilized by the register.
          -- Hopefully, software should not look at any bits outside of the utilized width,
          -- but set zero just in case and to avoid confusion.
          -- Does not impact netlist build size.
          trail_response.read_data(reg_values(0)'range) <= (others => '0');

          trail_response.status <= trail_response_status_okay;
        end if;

        for bit_idx in 0 to registers(reg_idx).utilized_width - 1 loop
          if is_application_gives_value_mode(registers(reg_idx).mode) then
            if is_read_operation and operation_index = reg_idx then
              trail_response.read_data(reg_values(0)'range)(bit_idx) <= regs_up(reg_idx)(bit_idx);
            end if;
          else
            if is_read_operation and operation_index = reg_idx then
              trail_response.read_data(reg_values(0)'range)(bit_idx) <= reg_values(reg_idx)(
                bit_idx
              );
            end if;
          end if;
        end loop;
      end if;

      if is_write_pulse_mode(registers(reg_idx).mode) then
        for bit_idx in 0 to registers(reg_idx).utilized_width - 1 loop
          -- Set initial default value.
          -- If a write occurs to this register, the value will be asserted for one cycle below.
          reg_values(reg_idx)(bit_idx) <= default_values(reg_idx)(bit_idx);
        end loop;
      end if;

      if is_write_mode(registers(reg_idx).mode) then
        if is_write_operation and operation_index = reg_idx then
          trail_response.status <= trail_response_status_okay;
          reg_was_written(reg_idx) <= '1';
        end if;

        for bit_idx in 0 to registers(reg_idx).utilized_width - 1 loop
          if is_write_operation and operation_index = reg_idx then
            reg_values(reg_idx)(bit_idx) <= trail_operation.write_data(reg_values(0)'range)(
              bit_idx
            );
          end if;
        end loop;
      end if;
    end loop;
  end process;

end architecture;
