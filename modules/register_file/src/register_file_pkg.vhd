-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the hdl-modules project, a collection of reusable, high-quality,
-- peer-reviewed VHDL building blocks.
-- https://hdl-modules.com
-- https://github.com/hdl-modules/hdl-modules
-- -------------------------------------------------------------------------------------------------
-- Package with constants/types/functions for generic register file ecosystem.
-- -------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library common;
use common.addr_pkg.all;

library math;
use math.math_pkg.all;


package register_file_pkg is

  constant register_width : positive := 32;
  subtype register_t is std_ulogic_vector(register_width - 1 downto 0);
  constant register_init : register_t := (others => '0');
  type register_vec_t is array (integer range <>) of register_t;

  type register_mode_t is (
    -- Software can read a value that hardware provides.
    r,
    -- Software can write a value that is available for usage in hardware.
    w,
    -- Software can write a value and read it back. The written value is available for usage
    -- in hardware.
    r_w,
    -- Software can write a value that is asserted for one cycle in hardware.
    wpulse,
    -- Software can read a value that hardware provides.
    -- Software can write a value that is asserted for one cycle in hardware.
    r_wpulse
  );

  -- If it is a mode where software can read the register.
  function is_read_mode(mode : register_mode_t) return boolean;
  -- If it is a mode where software can write the register.
  function is_write_mode(mode : register_mode_t) return boolean;
  -- If it is a mode where software can write the register and the value shall be asserted for
  -- one clock cycle in hardware.
  function is_write_pulse_mode(mode : register_mode_t) return boolean;
  -- If it is a mode where the value that software can read is provided by the 'regs_up' port
  -- from the users' application.
  -- As opposed to for example Read-Write, where the read value is a loopback of the written value.
  function is_application_gives_value_mode(mode : register_mode_t) return boolean;

  type register_definition_t is record
    -- The index of this register, within the list of registers.
    index : natural;
    -- The mode of this register.
    mode : register_mode_t;
    -- The number of data bits that are utilized in this register.
    -- Implementations can ignore other bits.
    utilized_width : natural range 0 to register_width;
  end record;
  type register_definition_vec_t is array (natural range <>) of register_definition_t;

  -- Get the highest register index that is used in the list of registers.
  function get_highest_index(regs : register_definition_vec_t) return natural;

end;

package body register_file_pkg is

  function is_read_mode(mode : register_mode_t) return boolean is
  begin
    return mode = r or mode = r_w or mode = r_wpulse;
  end function;

  function is_write_mode(mode : register_mode_t) return boolean is
  begin
    return mode = w or mode = r_w or mode = wpulse or mode = r_wpulse;
  end function;

  function is_write_pulse_mode(mode : register_mode_t) return boolean is
  begin
    return mode = wpulse or mode = r_wpulse;
  end function;

  function is_application_gives_value_mode(mode : register_mode_t) return boolean is
  begin
    return mode = r or mode = r_wpulse;
  end function;

  function get_highest_index(regs : register_definition_vec_t) return natural is
  begin
    assert regs(0).index = 0 severity failure;
    assert regs(regs'high).index = regs'length - 1 severity failure;
    return regs(regs'high).index;
  end function;

end;
