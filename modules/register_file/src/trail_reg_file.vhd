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

library trail;
use trail.trail_pkg.all;

use work.reg_file_pkg.all;

-- TODO rename
entity trail_reg_file is
  generic (
    regs : reg_definition_vec_t;
    default_values : reg_vec_t(regs'range) := (others => (others => '0'))
  );
  port (
    clk : in std_ulogic;
    --# {{}}
    --# Register control bus
    trail_operation : in trail_operation_t;
    trail_response : out trail_response_t := trail_response_init;
    --# {{}}
    -- Register values
    regs_up : in reg_vec_t(regs'range) := default_values;
    regs_down : out reg_vec_t(regs'range) := default_values;
    --# {{}}
    -- Each bit is pulsed for one cycle when the corresponding register is read/written.
    -- TODO.
    reg_was_read : out std_ulogic_vector(regs'range) := (others => '0');
    reg_was_written : out std_ulogic_vector(regs'range) := (others => '0')
  );
end entity;

architecture a of trail_reg_file is

  constant addr_and_mask_vec : addr_and_mask_vec_t := to_addr_and_mask_vec(regs);

  signal reg_values : reg_vec_t(regs'range) := default_values;

  constant invalid_addr : natural := regs'length;
  subtype decoded_idx_t is natural range 0 to invalid_addr;
  signal decoded_idx : decoded_idx_t := invalid_addr;

begin

  ------------------------------------------------------------------------------
  regs_down <= reg_values;


  ------------------------------------------------------------------------------
  decoded_idx <= decode(addr=>trail_operation.address, addrs=>addr_and_mask_vec);


  ------------------------------------------------------------------------------
  main : process
  begin
    wait until rising_edge(clk);

    reg_was_read <= (others => '0');
    reg_was_written <= (others => '0');

    -- Respond straight away and unconditionally.
    trail_response.enable <= trail_operation.enable;

    if trail_operation.enable then
      -- Set a default status. Will be overwritten below if the 'operation' is valid.
      trail_response.status <= trail_response_status_error;
    end if;

    for reg_idx in regs'range loop
      if (
        is_read_type(regs(reg_idx).reg_type)
        and trail_operation.enable = '1'
        and trail_operation.write_enable = '0'
        and decoded_idx = reg_idx
      ) then
        -- This is a read 'operation' from a register of a valid read type.

        if is_fabric_gives_value_type(regs(reg_idx).reg_type) then
          trail_response.read_data(reg_values(0)'range) <= regs_up(reg_idx);
        else
          trail_response.read_data(reg_values(0)'range) <= reg_values(reg_idx);
        end if;

        trail_response.status <= trail_response_status_okay;

        reg_was_read(reg_idx) <= '1';
      end if;

      if is_write_pulse_type(regs(reg_idx).reg_type) then
        -- Set initial default value.
        -- If a write occurs to this register, the value will be asserted for one cycle below.
        reg_values(reg_idx) <= default_values(reg_idx);
      end if;

      if (
        is_write_type(regs(reg_idx).reg_type)
        and trail_operation.enable = '1'
        and trail_operation.write_enable = '1'
        and decoded_idx = reg_idx
      ) then
        -- This is a write 'operation' to a register of a valid write type.

        reg_values(reg_idx) <= trail_operation.write_data(reg_values(0)'range);

        trail_response.status <= trail_response_status_okay;

        reg_was_written(reg_idx) <= '1';
      end if;
    end loop;
  end process;

end architecture;
