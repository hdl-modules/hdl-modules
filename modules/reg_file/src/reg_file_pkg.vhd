-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the tsfpga project.
-- https://tsfpga.com
-- https://gitlab.com/tsfpga/tsfpga
-- -------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library common;
use common.addr_pkg.all;

library math;
use math.math_pkg.all;


package reg_file_pkg is

  constant reg_width : integer := 32;
  subtype reg_t is std_logic_vector(reg_width - 1 downto 0);
  type reg_vec_t is array (integer range <>) of reg_t;

  type reg_type_t is (
    r, -- Bus can read a value that fabric provides
    w, -- Bus can write a value that is available for fabric usage
    r_w, -- Bus can write a value and read it back. The written value is available for fabric usage
    wpulse, -- Bus can write a value that is asserted for one cycle in fabric
    r_wpulse -- Bus can read a value that fabric provides. Bus can write a value that is asserted for one cycle in fabric
  );

  function is_read_type(reg_type : reg_type_t) return boolean;
  function is_write_type(reg_type : reg_type_t) return boolean;
  function is_write_pulse_type(reg_type : reg_type_t) return boolean;
  function is_fabric_gives_value_type(reg_type : reg_type_t) return boolean;

  type reg_definition_t is record
    idx : integer;
    reg_type : reg_type_t;
  end record;
  type reg_definition_vec_t is array (natural range <>) of reg_definition_t;

  function get_highest_idx(regs : reg_definition_vec_t) return integer;
  function get_addr_mask(regs : reg_definition_vec_t) return addr_t;
  function to_addr_and_mask_vec(regs : reg_definition_vec_t) return addr_and_mask_vec_t;

end;

package body reg_file_pkg is

  function is_read_type(reg_type : reg_type_t) return boolean is
  begin
    return reg_type = r or reg_type = r_w or reg_type = r_wpulse;
  end function;

  function is_write_type(reg_type : reg_type_t) return boolean is
  begin
    return reg_type = w or reg_type = r_w or reg_type = wpulse or reg_type = r_wpulse;
  end function;

  function is_write_pulse_type(reg_type : reg_type_t) return boolean is
  begin
    return reg_type = wpulse or reg_type = r_wpulse;
  end function;

  function is_fabric_gives_value_type(reg_type : reg_type_t) return boolean is
  begin
    return reg_type = r or reg_type = r_wpulse;
  end function;

  function get_highest_idx(regs : reg_definition_vec_t) return integer is
  begin
    assert regs(0).idx = 0 severity failure;
    assert regs(regs'high).idx = regs'length - 1 severity failure;
    return regs(regs'high).idx;
  end function;

  function get_addr_mask(regs : reg_definition_vec_t) return addr_t is
    constant num_bits : integer := num_bits_needed(get_highest_idx(regs));
    variable result : addr_t := (others => '0');
  begin
    -- Lowest bits are always zero since registers are 32-bits i.e. four-byte aligned.
    result(num_bits + 2 - 1 downto 2) := (others => '1');
    return result;
  end function;

  function to_addr_and_mask_vec(regs : reg_definition_vec_t) return addr_and_mask_vec_t is
    constant mask : addr_t := get_addr_mask(regs);
    variable result : addr_and_mask_vec_t(regs'range);
  begin
    for list_idx in regs'range loop
      -- Registers are 32-bits i.e. four-byte aligned, hence the multiplication.
      result(list_idx).addr := to_unsigned(4 * regs(list_idx).idx, result(list_idx).addr'length);
      result(list_idx).mask := mask;
    end loop;
    return result;
  end function;

end;
