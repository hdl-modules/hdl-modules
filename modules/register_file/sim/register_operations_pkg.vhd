-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the hdl-modules project, a collection of reusable, high-quality,
-- peer-reviewed VHDL building blocks.
-- https://hdl-modules.com
-- https://github.com/hdl-modules/hdl-modules
-- -------------------------------------------------------------------------------------------------
-- Various helper functions for reading/writing/checking registers.
--
-- .. note::
--
--   This file is largely unused, and replaced by simulation support packages produced
--   by the ``hdl-registers`` register interface code generator: https://hdl-registers.com
--   The file is kept for legacy reasons in case someone out there is still using it.
--
-- There is an intentional asymmetry in the default value for ``other_bits_value`` between
-- ``check_reg_equal_bit(s)`` and ``wait_until_reg_equals_bit(s)``.
-- For the former it is ``'0'`` while it is ``'-'`` for the latter.
-- This is based on the philosophy that a false positive is better than a hidden error.
-- False positives, when discovered, can be worked around by e.g. changing the default value.
--
-- Consider the example of ``check`` ing an error status register.
-- When we want to check that the expected error bit has been set, we would like to be informed if
-- any further errors have also occurred.
-- This would not happen unless ``other_bits_value`` value to ``check_reg_equal_bit(s)`` is ``'0'``.
--
-- Consider furthermore the situation where we are ``wait`` ing for a certain error bit to be
-- asserted in a test, but ten other errors occur.
-- In this scenario we would like the wait to end, and for the errors to have consequences.
-- This would not occur unless ``other_bits_value`` value to
-- ``wait_until_reg_equals_bit(s)`` is ``'-'``.
-- -------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
use vunit_lib.bus_master_pkg.bus_master_t;
use vunit_lib.bus_master_pkg.new_bus;
use vunit_lib.bus_master_pkg.read_bus;
use vunit_lib.bus_master_pkg.wait_until_read_equals;
use vunit_lib.bus_master_pkg.write_bus;
use vunit_lib.check_pkg.all;
use vunit_lib.com_types_pkg.max_timeout;
use vunit_lib.com_types_pkg.network_t;
use vunit_lib.logger_pkg.all;

library common;
use common.addr_pkg.addr_t;
use common.addr_pkg.addr_width;
use common.types_pkg.natural_vec_t;

library register_file;
use register_file.register_file_pkg.register_t;
use register_file.register_file_pkg.register_width;


package register_operations_pkg is

  -- Default bus handle that can be used to simplify calls.
  constant register_bus_master : bus_master_t := new_bus(
    data_length=>register_width,
    address_length=>addr_width,
    logger=>get_logger("register_bus_master")
  );

  -- Some common register operations.

  procedure read_reg(
    signal net : inout network_t;
    reg_index : in natural;
    value : out register_t;
    base_address : in addr_t := (others => '0');
    bus_handle : in bus_master_t := register_bus_master
  );

  procedure read_reg(
    signal net : inout network_t;
    reg_index : in natural;
    value : out integer;
    base_address : in addr_t := (others => '0');
    bus_handle : in bus_master_t := register_bus_master
  );

  procedure check_reg_equal(
    signal net : inout network_t;
    reg_index : in natural;
    value : in register_t;
    base_address : in addr_t := (others => '0');
    bus_handle : in bus_master_t := register_bus_master;
    message : in string := ""
  );

  procedure check_reg_equal(
    signal net : inout network_t;
    reg_index : in natural;
    value : in integer;
    base_address : in addr_t := (others => '0');
    bus_handle : in bus_master_t := register_bus_master;
    message : in string := ""
  );

  procedure check_reg_equal_bits(
    signal net : inout network_t;
    reg_index : in natural;
    bit_indexes : in natural_vec_t;
    values : in std_ulogic_vector;
    other_bits_value : in std_ulogic := '0';
    base_address : in addr_t := (others => '0');
    bus_handle : in bus_master_t := register_bus_master;
    message : in string := ""
  );

  procedure check_reg_equal_bit(
    signal net : inout network_t;
    reg_index : in natural;
    bit_index : in natural;
    value : in std_ulogic;
    other_bits_value : in std_ulogic := '0';
    base_address : in addr_t := (others => '0');
    bus_handle : in bus_master_t := register_bus_master;
    message : in string := ""
  );

  procedure wait_until_reg_equals(
    signal net : inout network_t;
    reg_index : in natural;
    value : in register_t;
    base_address : in addr_t := (others => '0');
    bus_handle : in bus_master_t := register_bus_master;
    timeout : delay_length := max_timeout;
    message : string := ""
  );

  procedure wait_until_reg_equals(
    signal net : inout network_t;
    reg_index : in natural;
    value : in integer;
    base_address : in addr_t := (others => '0');
    bus_handle : in bus_master_t := register_bus_master;
    timeout : delay_length := max_timeout;
    message : string := ""
  );

  procedure wait_until_reg_equals_bits(
    signal net : inout network_t;
    reg_index : in natural;
    bit_indexes : in natural_vec_t;
    values : in std_ulogic_vector;
    other_bits_value : in std_ulogic := '-';
    base_address : in addr_t := (others => '0');
    bus_handle : in bus_master_t := register_bus_master;
    timeout : delay_length := max_timeout;
    message : string := ""
  );

  procedure wait_until_reg_equals_bit(
    signal net : inout network_t;
    reg_index : in natural;
    bit_index : in natural;
    value : in std_ulogic;
    other_bits_value : in std_ulogic := '-';
    base_address : in addr_t := (others => '0');
    bus_handle : in bus_master_t := register_bus_master;
    timeout : delay_length := max_timeout;
    message : string := ""
  );

  procedure write_reg(
    signal net : inout network_t;
    reg_index : in natural;
    value : in register_t;
    base_address : in addr_t := (others => '0');
    bus_handle : in bus_master_t := register_bus_master
  );

  procedure write_reg(
    signal net : inout network_t;
    reg_index : in natural;
    value : in u_unsigned(register_width - 1 downto 0);
    base_address : in addr_t := (others => '0');
    bus_handle : in bus_master_t := register_bus_master
  );

  procedure write_reg(
    signal net : inout network_t;
    reg_index : in natural;
    value : in integer;
    base_address : in addr_t := (others => '0');
    bus_handle : in bus_master_t := register_bus_master
  );

  procedure write_reg_bits(
    signal net : inout network_t;
    reg_index : in natural;
    bit_indexes : in natural_vec_t;
    values : in std_ulogic_vector;
    other_bits_value : in std_ulogic := '0';
    base_address : in addr_t := (others => '0');
    bus_handle : in bus_master_t := register_bus_master
  );

  procedure write_reg_bit(
    signal net : inout network_t;
    reg_index : in natural;
    bit_index : in natural;
    value : in std_ulogic;
    other_bits_value : in std_ulogic := '0';
    base_address : in addr_t := (others => '0');
    bus_handle : in bus_master_t := register_bus_master
  );

  procedure read_modify_write_reg_bits(
    signal net : inout network_t;
    reg_index : in natural;
    bit_indexes : in natural_vec_t;
    values : in std_ulogic_vector;
    base_address : in addr_t := (others => '0');
    bus_handle : in bus_master_t := register_bus_master
  );

  procedure read_modify_write_reg_bit(
    signal net : inout network_t;
    reg_index : in natural;
    bit_index : in natural;
    value : in std_ulogic;
    base_address : in addr_t := (others => '0');
    bus_handle : in bus_master_t := register_bus_master
  );

  -- Internal helper function. Not meant to be used outside of this package.

  function to_reg_value(
    bit_indexes : natural_vec_t;
    values : std_ulogic_vector;
    previous_value : register_t := (others => '0')
  ) return register_t;

end;

package body register_operations_pkg is

  function get_error_message(
    reg_index : natural;
    base_address : addr_t;
    message : string
  ) return string is
    constant result : string :=
      "reg_index: " & to_string(reg_index) & ", base_address: " & to_string(base_address);
  begin
    if message = "" then
      return result;
    end if;

    return result & ", message: " & message;
  end function;

  procedure read_reg(
    signal net : inout network_t;
    reg_index : in natural;
    value : out register_t;
    base_address : in addr_t := (others => '0');
    bus_handle : in bus_master_t := register_bus_master
  ) is
    variable address : addr_t;
  begin
    address := base_address or to_unsigned(4 * reg_index, address'length);
    read_bus(net=>net, bus_handle=>bus_handle, address=>std_logic_vector(address), data=>value);
  end procedure;

  procedure read_reg(
    signal net : inout network_t;
    reg_index : in natural;
    value : out integer;
    base_address : in addr_t := (others => '0');
    bus_handle : in bus_master_t := register_bus_master
  ) is
    variable slv_value : register_t := (others => '0');
  begin
    read_reg(net, reg_index, slv_value, base_address, bus_handle);
    value := to_integer(signed(slv_value));
  end procedure;

  procedure check_reg_equal(
    signal net : inout network_t;
    reg_index : in natural;
    value : in register_t;
    base_address : in addr_t := (others => '0');
    bus_handle : in bus_master_t := register_bus_master;
    message : in string := ""
  ) is
    variable got : register_t := (others => '0');
  begin
    -- Check that the register value equals the specified 'value'. Note that '-' can be used as a
    -- wildcard in 'value' since check_match is used to check for equality.

    read_reg(
      net=>net,
      reg_index=>reg_index,
      value=>got,
      base_address=>base_address,
      bus_handle=>bus_handle
    );
    check_match(got, value, get_error_message(reg_index, base_address, message));
  end procedure;

  procedure check_reg_equal(
    signal net : inout network_t;
    reg_index : in natural;
    value : in integer;
    base_address : in addr_t := (others => '0');
    bus_handle : in bus_master_t := register_bus_master;
    message : in string := ""
  ) is
    variable got : integer := 0;
  begin
    read_reg(
      net=>net,
      reg_index=>reg_index,
      value=>got,
      base_address=>base_address,
      bus_handle=>bus_handle
    );
    check_equal(got, value, get_error_message(reg_index, base_address, message));
  end procedure;

  procedure check_reg_equal_bits(
    signal net : inout network_t;
    reg_index : in natural;
    bit_indexes : in natural_vec_t;
    values : in std_ulogic_vector;
    other_bits_value : in std_ulogic := '0';
    base_address : in addr_t := (others => '0');
    bus_handle : in bus_master_t := register_bus_master;
    message : in string := ""
  ) is
    variable reg_values : register_t := (others => '0');
  begin
    -- Check that the bits in 'bit_indexes' have the expected 'values'.
    -- Expected value of the other bits can be controlled with the 'other_bits_value' parameter.
    -- Can set 'other_bits_value' to '-' to ignore all bits that are not designated
    -- by 'bit_indexes'.

    reg_values := to_reg_value(
      bit_indexes=>bit_indexes,
      values=>values,
      previous_value=>(others => other_bits_value)
    );

    check_reg_equal(
      net=>net,
      reg_index=>reg_index,
      value=>reg_values,
      base_address=>base_address,
      bus_handle=>bus_handle,
      message=>message
    );
  end procedure;

  procedure check_reg_equal_bit(
    signal net : inout network_t;
    reg_index : in natural;
    bit_index : in natural;
    value : in std_ulogic;
    other_bits_value : in std_ulogic := '0';
    base_address : in addr_t := (others => '0');
    bus_handle : in bus_master_t := register_bus_master;
    message : in string := ""
  ) is
  begin
    -- Check that the 'bit_index' bit has the expected 'value'.
    -- Expected value of the other bits can be controlled with the 'other_bits_value' parameter.
    -- Can set 'other_bits_value' to '-' to ignore all bits that are not designated by 'bit_index'.

    check_reg_equal_bits(
      net=>net,
      reg_index=>reg_index,
      bit_indexes=>(0 => bit_index),
      values=>(0 => value),
      other_bits_value=>other_bits_value,
      base_address=>base_address,
      bus_handle=>bus_handle,
      message=>message
    );
  end procedure;

  procedure wait_until_reg_equals(
    signal net : inout network_t;
    reg_index : in natural;
    value : in register_t;
    base_address : in addr_t := (others => '0');
    bus_handle : in bus_master_t := register_bus_master;
    timeout : delay_length := max_timeout;
    message : string := ""
  ) is
    constant address : addr_t := base_address or to_unsigned(4 * reg_index, addr_t'length);
  begin
    -- Wait until the register has the specified 'value'. Note that '-' can be used as a wildcard
    -- in 'value' since std_match is used to check for equality inside the VUnit function.

    wait_until_read_equals(
      net=>net,
      bus_handle=>bus_handle,
      addr=>std_ulogic_vector(address),
      value=>value,
      timeout=>timeout,
      msg=>get_error_message(reg_index, base_address, message)
    );
  end procedure;

  procedure wait_until_reg_equals(
    signal net : inout network_t;
    reg_index : in natural;
    value : in integer;
    base_address : in addr_t := (others => '0');
    bus_handle : in bus_master_t := register_bus_master;
    timeout : delay_length := max_timeout;
    message : string := ""
  ) is
  begin
    wait_until_reg_equals(
      net=>net,
      reg_index=>reg_index,
      value=>std_ulogic_vector(to_signed(value, register_width)),
      base_address=>base_address,
      bus_handle=>bus_handle,
      timeout=>timeout,
      message=>message
    );
  end procedure;

  procedure wait_until_reg_equals_bits(
    signal net : inout network_t;
    reg_index : in natural;
    bit_indexes : in natural_vec_t;
    values : in std_ulogic_vector;
    other_bits_value : in std_ulogic := '-';
    base_address : in addr_t := (others => '0');
    bus_handle : in bus_master_t := register_bus_master;
    timeout : delay_length := max_timeout;
    message : string := ""
  ) is
    variable reg_value : register_t := (others => '0');
  begin
    -- Wait until all the bits listed in 'bit_indexes' are read as their corresponding 'values'.
    -- Other bits' values can either be ignored (if 'other_bits_value' is left at default value) or
    -- checked against an expected value (by specifying 'other_bits_value').

    reg_value := to_reg_value(
      bit_indexes=>bit_indexes,
      values=>values,
      previous_value=>(others => other_bits_value)
    );

    wait_until_reg_equals(
      net=>net,
      reg_index=>reg_index,
      value=>reg_value,
      base_address=>base_address,
      bus_handle=>bus_handle,
      timeout=>timeout,
      message=>message
    );
  end procedure;

  procedure wait_until_reg_equals_bit(
    signal net : inout network_t;
    reg_index : in natural;
    bit_index : in natural;
    value : in std_ulogic;
    other_bits_value : in std_ulogic := '-';
    base_address : in addr_t := (others => '0');
    bus_handle : in bus_master_t := register_bus_master;
    timeout : delay_length := max_timeout;
    message : string := ""
  ) is
  begin
    -- Wait until the 'bit_index' bit is read as 'value'.
    -- Other bits' values can either be ignored (if 'other_bits_value' is left at default value) or
    -- checked against an expected value (by specifying 'other_bits_value').

    wait_until_reg_equals_bits(
      net=>net,
      reg_index=>reg_index,
      bit_indexes=>(0 => bit_index),
      values=>(0 => value),
      other_bits_value=>other_bits_value,
      base_address=>base_address,
      bus_handle=>bus_handle,
      timeout=>timeout,
      message=>message
    );
  end procedure;

  procedure write_reg(
    signal net : inout network_t;
    reg_index : in natural;
    value : in register_t;
    base_address : in addr_t := (others => '0');
    bus_handle : in bus_master_t := register_bus_master
  ) is
    variable address : addr_t;
  begin
    -- Note that this call is non-blocking.

    address := base_address or to_unsigned(4 * reg_index, address'length);
    write_bus(net=>net, bus_handle=>bus_handle, address=>std_logic_vector(address), data=>value);
  end procedure;

  procedure write_reg(
    signal net : inout network_t;
    reg_index : in natural;
    value : in integer;
    base_address : in addr_t := (others => '0');
    bus_handle : in bus_master_t := register_bus_master
  ) is
  begin
    -- Note that this call is non-blocking.

    write_reg(
      net=>net,
      reg_index=>reg_index,
      value=>std_logic_vector(to_signed(value, register_width)),
      base_address=>base_address,
      bus_handle=>bus_handle
    );
  end procedure;

  procedure write_reg(
    signal net : inout network_t;
    reg_index : in natural;
    value : in u_unsigned(register_width - 1 downto 0);
    base_address : in addr_t := (others => '0');
    bus_handle : in bus_master_t := register_bus_master
  ) is
  begin
    -- Note that this call is non-blocking.

    write_reg(
      net=>net,
      reg_index=>reg_index,
      value=>std_logic_vector(value),
      base_address=>base_address,
      bus_handle=>bus_handle
    );
  end procedure;

  procedure write_reg_bits(
    signal net : inout network_t;
    reg_index : in natural;
    bit_indexes : in natural_vec_t;
    values : in std_ulogic_vector;
    other_bits_value : in std_ulogic := '0';
    base_address : in addr_t := (others => '0');
    bus_handle : in bus_master_t := register_bus_master
  ) is
    variable reg_value : register_t := (others => '0');
  begin
    -- Write to register where the bits listed in 'bit_indexes' will be set to 'values'.
    -- The other bits in the write word are set to zero if 'other_bits_value' is left out,
    -- or can be specified by assigning 'other_bits_value'.
    -- Note that this call is non-blocking.

    reg_value := to_reg_value(
      bit_indexes=>bit_indexes,
      values=>values,
      previous_value=>(others => other_bits_value)
    );

    write_reg(
      net=>net,
      reg_index=>reg_index,
      value=>reg_value,
      base_address=>base_address,
      bus_handle=>bus_handle
    );
  end procedure;

  procedure write_reg_bit(
    signal net : inout network_t;
    reg_index : in natural;
    bit_index : in natural;
    value : in std_ulogic;
    other_bits_value : in std_ulogic := '0';
    base_address : in addr_t := (others => '0');
    bus_handle : in bus_master_t := register_bus_master
  ) is
  begin
    -- Write to register where the 'bit_index' bit will be set to 'value'.
    -- The other bits in the write word are set to zero if 'other_bits_value' is left out,
    -- or can be specified by assigning 'other_bits_value'.
    -- Note that this call is non-blocking.

    write_reg_bits(
      net=>net,
      reg_index=>reg_index,
      bit_indexes=>(0 => bit_index),
      values=>(0 => value),
      other_bits_value=>other_bits_value,
      base_address=>base_address,
      bus_handle=>bus_handle
    );
  end procedure;

  procedure read_modify_write_reg_bits(
    signal net : inout network_t;
    reg_index : in natural;
    bit_indexes : in natural_vec_t;
    values : in std_ulogic_vector;
    base_address : in addr_t := (others => '0');
    bus_handle : in bus_master_t := register_bus_master
  ) is
    variable previous_value, new_value : register_t := (others => '0');
  begin
    -- Read-modify-write where the bits listed in 'bit_indexes' will be set to 'values'.
    -- Note that the read portion of this call is blocking, but the write portion is non-blocking.

    read_reg(
      net=>net,
      reg_index=>reg_index,
      value=>previous_value,
      base_address=>base_address,
      bus_handle=>bus_handle
    );

    new_value := to_reg_value(bit_indexes, values, previous_value);

    write_reg(
      net=>net,
      reg_index=>reg_index,
      value=>new_value,
      base_address=>base_address,
      bus_handle=>bus_handle
    );
  end procedure;

  procedure read_modify_write_reg_bit(
    signal net : inout network_t;
    reg_index : in natural;
    bit_index : in natural;
    value : in std_ulogic;
    base_address : in addr_t := (others => '0');
    bus_handle : in bus_master_t := register_bus_master
  ) is
  begin
    -- Read-modify-write where the 'bit_index' bit will be set to 'value'.
    -- Note that the read portion of this call is blocking, but the write portion is non-blocking.

    read_modify_write_reg_bits(
      net=>net,
      reg_index=>reg_index,
      bit_indexes=>(0 => bit_index),
      values=>(0 => value),
      base_address=>base_address,
      bus_handle=>bus_handle
    );
  end procedure;

  function to_reg_value(
    bit_indexes : natural_vec_t;
    values : std_ulogic_vector;
    previous_value : register_t := (others => '0')
  ) return register_t is
    variable result : register_t := previous_value;
  begin
    -- Construct a register value based on bit values.
    -- Assigning 'previous_value' realizes a "read-modify-write" behavior.

    -- The natural_vec_t array is of integer range while std_ulogic_vector array is natural range.
    -- This means that for literal inline arrays, bit_indexes will start at -2147483647 while
    -- values will start at 0. Hence the handling is little more cumbersome.

    assert bit_indexes'left = bit_indexes'low report "Must use ascending array";
    assert values'left = values'low report "Must use ascending array";
    assert bit_indexes'length = values'length report "Arrays must be same length";

    for vec_index in 0 to bit_indexes'length - 1 loop
      result(bit_indexes(bit_indexes'low + vec_index)) := values(values'low + vec_index);
    end loop;

    return result;
  end function;

end;
