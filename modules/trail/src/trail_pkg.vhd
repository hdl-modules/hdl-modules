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

library math;
use math.math_pkg.all;


package trail_pkg is

  ------------------------------------------------------------------------------
  -- Operation address field.
  ------------------------------------------------------------------------------
  -- The width value below is a max value, implementation should only take into regard the bits
  -- that are actually used.
  constant trail_max_address_width : positive := 48;
  subtype trail_address_width_t is positive range 1 to trail_max_address_width;

  -- TODO.
  function trail_num_unaligned_address_bits(data_width : integer) return natural;

  -- TODO implement this?
  -- function trail_aligned_address_width(
  --   address_width : integer; data_width : integer
  -- ) return positive;


  ------------------------------------------------------------------------------
  -- Data field (operation write data or response read data).
  ------------------------------------------------------------------------------
  -- The width value below is a max value, implementation should only take into regard the bits
  -- that are actually used.
  constant trail_max_data_width : positive := 64;
  subtype trail_data_width_t is positive range 1 to trail_max_data_width;

  -- Check that provided widths are valid to be used with TRAIL.
  -- Return 'true' if everything is okay, otherwise 'false'.
  function sanity_check_trail_widths(address_width, data_width : integer) return boolean;
  -- Internal functions. In 99% of cases you should use the above function instead.
  function sanity_check_trail_address_width(address_width : integer) return boolean;
  function sanity_check_trail_data_width(data_width : integer) return boolean;


  ------------------------------------------------------------------------------
  -- Response status code.
  -- TODO change to SL? 0 = error, 1 = okay?
  ------------------------------------------------------------------------------
  type trail_response_status_t is (trail_response_status_okay, trail_response_status_error);
  constant trail_response_status_width : positive := 1;

  function to_sl(data : trail_response_status_t) return std_ulogic;

  function to_trail_response_status(data : std_ulogic) return trail_response_status_t;


  ------------------------------------------------------------------------------
  -- Operation (master-to-slave) payload.
  ------------------------------------------------------------------------------
  type trail_operation_t is record
    enable : std_ulogic;
    address : u_unsigned(trail_max_address_width - 1 downto 0);
    write_enable : std_ulogic;
    write_data : std_ulogic_vector(trail_max_data_width - 1 downto 0);
  end record;
  type trail_operation_vec_t is array (integer range <>) of trail_operation_t;

  constant trail_operation_init : trail_operation_t := (
    enable => '0',
    address => (others => '0'),
    write_enable => '0',
    write_data => (others => '0')
  );

  -- Note that the 'enable' signal, which is used for handshaking, is not included.
  function trail_operation_width(
    address_width : trail_address_width_t; data_width : trail_data_width_t
  ) return positive;

  -- Note that the 'enable' signal, which is used for handshaking, is not included.
  function to_slv(
    data : trail_operation_t;
    address_width : trail_address_width_t;
    data_width : trail_data_width_t
  ) return std_ulogic_vector;

  function to_trail_operation(
    data : std_ulogic_vector;
    enable : std_ulogic;
    address_width : trail_address_width_t;
    data_width : trail_data_width_t
  ) return trail_operation_t;


  ------------------------------------------------------------------------------
  -- Response (slave-to-master) payload.
  ------------------------------------------------------------------------------
  type trail_response_t is record
    enable : std_ulogic;
    status : trail_response_status_t;
    read_data : std_ulogic_vector(trail_max_data_width - 1 downto 0);
  end record;
  type trail_response_vec_t is array (integer range <>) of trail_response_t;

  constant trail_response_init : trail_response_t := (
    enable => '0',
    status => trail_response_status_okay,
    read_data => (others => '0')
  );

  -- Note that the 'enable' signal, which is used for handshaking, is not included.
  function trail_response_width(data_width : trail_data_width_t) return positive;

  -- Note that the 'enable' signal, which is used for handshaking, is not included.
  function to_slv(
    data : trail_response_t; data_width : trail_data_width_t
  ) return std_ulogic_vector;

  function to_trail_response(
    data : std_ulogic_vector; enable : std_ulogic; data_width : trail_data_width_t
  ) return trail_response_t;

end;

package body trail_pkg is

  ------------------------------------------------------------------------------
  function trail_num_unaligned_address_bits(data_width : integer) return natural is
    variable data_width_bytes : positive := 1;
    variable result : natural := 0;
  begin
    assert sanity_check_trail_data_width(data_width=>data_width)
      report "Invalid data width, see printout above."
      severity failure;

    data_width_bytes := data_width / 8;
    result := log2(data_width_bytes);

    return result;
  end function;
  ------------------------------------------------------------------------------

  ------------------------------------------------------------------------------
  function sanity_check_trail_widths(address_width, data_width : integer) return boolean is
    constant num_unaligned_address_bits : natural := trail_num_unaligned_address_bits(
        data_width=>data_width
    );
  begin
    if not sanity_check_trail_address_width(address_width=>address_width) then
      return false;
    end if;

    if not sanity_check_trail_data_width(data_width=>data_width) then
      return false;
    end if;

    if address_width <= num_unaligned_address_bits then
      report (
        "TRAIL address must have at least one aligned bit. Got address_width="
        & integer'image(address_width)
        & ", data_width="
        & integer'image(data_width)
        & "."
      );
      return false;
    end if;

    return true;
  end function;

  function sanity_check_trail_address_width(address_width : integer) return boolean is
    constant message : string := ". Got address_width=" & integer'image(address_width) & ".";
  begin
    if address_width <= 0 then
      report "TRAIL address width must be greater than zero" & message;
      return false;
    end if;

    if address_width > trail_max_address_width then
      report (
        "TRAIL address width must not be greater than max value "
        & integer'image(trail_max_address_width)
        & message
      );
      return false;
    end if;

    return true;
  end function;

  function sanity_check_trail_data_width(data_width : integer) return boolean is
    constant message : string := ". Got data_width=" & integer'image(data_width) & ".";
  begin
    if data_width <= 0 then
      report "TRAIL data width must be greater than zero" & message;
      return false;
    end if;

    if data_width > trail_max_data_width then
      report (
        "TRAIL data width must not be greater than max value "
        & integer'image(trail_max_data_width)
        & message
      );
      return false;
    end if;

    if data_width mod 8 /= 0 then
      report "TRAIL data width must be a whole number of bytes" & message;
      return false;
    end if;

    if not is_power_of_two(data_width / 8) then
      report "TRAIL data byte-width must be a power of two" & message;
      return false;
    end if;

    return true;
  end function;
  ------------------------------------------------------------------------------

  ------------------------------------------------------------------------------
  function to_sl(data : trail_response_status_t) return std_ulogic is
  begin
    if data = trail_response_status_okay then
      return '0';
    end if;

    return '1';
  end function;
  ------------------------------------------------------------------------------

  ------------------------------------------------------------------------------
  function to_trail_response_status(data : std_ulogic) return trail_response_status_t is
  begin
    if data = '0'then
      return trail_response_status_okay;
    end if;

    return trail_response_status_error;
  end function;
  ------------------------------------------------------------------------------

  ------------------------------------------------------------------------------
  function trail_operation_width(
    address_width : trail_address_width_t; data_width : trail_data_width_t
  ) return positive is
    constant num_unaligned_address_bits : natural := trail_num_unaligned_address_bits(
        data_width=>data_width
    );
  begin
    -- +1 for 'write_enable'.
    -- Subtract the address bits that are unused (assumed zero) given the data width.
    return (address_width - num_unaligned_address_bits) + 1 + data_width;
  end function;
  ------------------------------------------------------------------------------

  ------------------------------------------------------------------------------
  function to_slv(
    data : trail_operation_t;
    address_width : trail_address_width_t;
    data_width : trail_data_width_t
  ) return std_ulogic_vector is
    constant num_unaligned_address_bits : natural := trail_num_unaligned_address_bits(
        data_width=>data_width
    );
    constant address_width_to_use : positive := address_width - num_unaligned_address_bits;

    constant result_width : positive := trail_operation_width(
      address_width=>address_width, data_width=>data_width
    );
    variable result : std_logic_vector(result_width - 1 downto 0) := (others => '0');
  begin
    result(address_width_to_use - 1 downto 0) := std_ulogic_vector(
      data.address(
        address_width - 1 downto num_unaligned_address_bits
      )
    );

    result(data_width + address_width_to_use - 1 downto address_width_to_use) := data.write_data(
      data_width - 1 downto 0
    );

    result(result'high) := data.write_enable;

    return result;
  end function;
  ------------------------------------------------------------------------------

  ------------------------------------------------------------------------------
  function to_trail_operation(
    data : std_ulogic_vector;
    enable : std_ulogic;
    address_width : trail_address_width_t;
    data_width : trail_data_width_t
  ) return trail_operation_t is
    constant expected_slv_width : positive := trail_operation_width(
      address_width=>address_width, data_width=>data_width
    );

    constant num_unaligned_address_bits : natural := trail_num_unaligned_address_bits(
        data_width=>data_width
    );
    constant address_width_to_use : positive := address_width - num_unaligned_address_bits;

    variable result : trail_operation_t := trail_operation_init;
  begin
    assert data'length = expected_slv_width report "Unexpected SLV width";

    result.address(address_width - 1 downto num_unaligned_address_bits) := u_unsigned(
      data(
        address_width_to_use - 1 downto 0
      )
    );

    result.write_data(data_width - 1 downto 0) := data(
      data_width + address_width_to_use - 1 downto address_width_to_use
    );

    result.write_enable := data(data'high);

    result.enable := enable;

    return result;
  end function;
  ------------------------------------------------------------------------------

  ------------------------------------------------------------------------------
  function trail_response_width(data_width : trail_data_width_t) return positive is
  begin
    return data_width + trail_response_status_width;
  end function;
  ------------------------------------------------------------------------------

  ------------------------------------------------------------------------------
  function to_slv(
    data : trail_response_t; data_width : trail_data_width_t
  ) return std_ulogic_vector is
    constant result_width : positive := trail_response_width(data_width=>data_width);
    variable result : std_logic_vector(result_width - 1 downto 0) := (others => '0');
  begin
    result(data_width - 1 downto 0) := data.read_data(data_width - 1 downto 0);

    result(result'high) := to_sl(data.status);

    return result;
  end function;
  ------------------------------------------------------------------------------

  ------------------------------------------------------------------------------
  function to_trail_response(
    data : std_ulogic_vector; enable : std_ulogic; data_width : trail_data_width_t
  ) return trail_response_t is
    constant expected_slv_width : positive := trail_response_width(data_width=>data_width);

    variable result : trail_response_t := trail_response_init;
  begin
    assert data'length = expected_slv_width report "Unexpected SLV width";

    result.read_data(data_width - 1 downto 0) := data(data_width - 1 downto 0);

    result.status := to_trail_response_status(data(data'high));

    result.enable := enable;

    return result;
  end function;
  ------------------------------------------------------------------------------

end package body;
