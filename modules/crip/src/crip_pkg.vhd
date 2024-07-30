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


package crip_pkg is

  ------------------------------------------------------------------------------
  -- Operation address field.
  ------------------------------------------------------------------------------
  -- The width value below is a max value, implementation should only take into regard the bits
  -- that are actually used.
  constant crip_max_address_width : positive := 48;
  subtype crip_address_width_t is positive range 1 to crip_max_address_width;

  -- TODO.
  function crip_num_unaligned_address_bits(data_width : integer) return natural;

  -- TODO
  -- function crip_aligned_address_width(
  --   address_width : integer; data_width : integer
  -- ) return positive;


  ------------------------------------------------------------------------------
  -- Data field (operation write data or response read data).
  ------------------------------------------------------------------------------
  -- The width value below is a max value, implementation should only take into regard the bits
  -- that are actually used.
  constant crip_max_data_width : positive := 64;
  subtype crip_data_width_t is positive range 1 to crip_max_address_width;

  -- Check that a provided data width is valid to be used with crip.
  -- Return 'true' if everything is okay, otherwise 'false'.
  function sanity_check_crip_data_width(data_width : integer) return boolean;


  ------------------------------------------------------------------------------
  -- Response status code.
  ------------------------------------------------------------------------------
  type crip_response_status_t is (crip_response_status_okay, crip_response_status_error);
  constant crip_response_status_width : positive := 1;

  function to_sl(data : crip_response_status_t) return std_ulogic;

  function to_crip_response_status(data : std_ulogic) return crip_response_status_t;


  ------------------------------------------------------------------------------
  -- Operation (master-to-slave) payload.
  ------------------------------------------------------------------------------
  type crip_operation_t is record
    enable : std_ulogic;
    address : u_unsigned(crip_max_address_width - 1 downto 0);
    write_enable : std_ulogic;
    write_data : std_ulogic_vector(crip_max_data_width - 1 downto 0);
  end record;

  constant crip_operation_init : crip_operation_t := (
    enable => '0',
    address => (others => '0'),
    write_enable => '0',
    write_data => (others => '0')
  );

  -- Note that the 'new' signal, which is used for handshaking, is not included.
  function crip_operation_width(
    address_width : crip_address_width_t; data_width : crip_data_width_t
  ) return positive;

  type crip_operation_vec_t is array (integer range <>) of crip_operation_t;

  -- Note that the 'new' signal, which is used for handshaking, is not included.
  function to_slv(
    data : crip_operation_t;
    address_width : crip_address_width_t;
    data_width : crip_data_width_t
  ) return std_ulogic_vector;

  function to_crip_operation(
    data : std_ulogic_vector;
    address_width : crip_address_width_t;
    data_width : crip_data_width_t;
    enable : std_ulogic
  ) return crip_operation_t;


  ------------------------------------------------------------------------------
  -- Response (slave-to-master) payload.
  ------------------------------------------------------------------------------
  type crip_response_t is record
    enable : std_ulogic;
    status : crip_response_status_t;
    read_data : std_ulogic_vector(crip_max_data_width - 1 downto 0);
  end record;

  constant crip_response_init : crip_response_t := (
    enable => '0',
    status => crip_response_status_okay,
    read_data => (others => '0')
  );

  function crip_response_width(data_width : crip_data_width_t) return positive;

  type crip_response_vec_t is array (integer range <>) of crip_response_t;

  function to_slv(data : crip_response_t; data_width : crip_data_width_t) return std_ulogic_vector;

  function to_crip_response(
    data : std_ulogic_vector; data_width : crip_data_width_t; enable : std_ulogic
  ) return crip_response_t;

end;

package body crip_pkg is

  ------------------------------------------------------------------------------
  function crip_num_unaligned_address_bits(data_width : integer) return natural is
    variable data_width_bytes : positive := 1;
    variable result : natural := 0;
  begin
    assert sanity_check_crip_data_width(data_width=>data_width)
      report "Invalid data width, see printout above."
      severity failure;

    data_width_bytes := data_width / 8;
    result := log2(data_width_bytes);

    return result;
  end function;
  ------------------------------------------------------------------------------

  ------------------------------------------------------------------------------
  function sanity_check_crip_data_width(data_width : integer) return boolean is
    constant message : string := ". Got data_width=" & integer'image(data_width) & ".";
  begin
    if data_width <= 0 then
      report "crip data width must be greater than zero" & message;
      return false;
    end if;

    if data_width > crip_max_data_width then
      report (
        "crip data width must not be greater than max value "
        & integer'image(crip_max_data_width)
        & message
      );
      return false;
    end if;

    if data_width mod 8 /= 0 then
      report "crip data width must be a whole number of bytes" & message;
      return false;
    end if;

    if not is_power_of_two(data_width / 8) then
      report "crip data byte width must be a power of two" & message;
      return false;
    end if;

    return true;
  end function;
  ------------------------------------------------------------------------------

  ------------------------------------------------------------------------------
  function to_sl(data : crip_response_status_t) return std_ulogic is
  begin
    if data = crip_response_status_okay then
      return '0';
    end if;

    return '1';
  end function;
  ------------------------------------------------------------------------------

  ------------------------------------------------------------------------------
  function to_crip_response_status(data : std_ulogic) return crip_response_status_t is
  begin
    if data = '0'then
      return crip_response_status_okay;
    end if;

    return crip_response_status_error;
  end function;
  ------------------------------------------------------------------------------

  ------------------------------------------------------------------------------
  function crip_operation_width(
    address_width : crip_address_width_t; data_width : crip_data_width_t
  ) return positive is
    constant num_unaligned_address_bits : natural := crip_num_unaligned_address_bits(
        data_width=>data_width
    );
  begin
    -- +1 for 'write_enable'.
    -- Subtract the address bits that are unused (assumed zero) give the data width and that we
    -- only support aligned operations.
    return (address_width - num_unaligned_address_bits) + 1 + data_width;
  end function;
  ------------------------------------------------------------------------------

  ------------------------------------------------------------------------------
  function to_slv(
    data : crip_operation_t;
    address_width : crip_address_width_t;
    data_width : crip_data_width_t
  ) return std_ulogic_vector is
    constant num_unaligned_address_bits : natural := crip_num_unaligned_address_bits(
        data_width=>data_width
    );
    constant address_width_to_use : positive := address_width - num_unaligned_address_bits;

    constant result_width : positive := crip_operation_width(
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
  function to_crip_operation(
    data : std_ulogic_vector;
    address_width : crip_address_width_t;
    data_width : crip_data_width_t;
    enable : std_ulogic
  ) return crip_operation_t is
    constant expected_slv_width : positive := crip_operation_width(
      address_width=>address_width, data_width=>data_width
    );

    constant num_unaligned_address_bits : natural := crip_num_unaligned_address_bits(
        data_width=>data_width
    );
    constant address_width_to_use : positive := address_width - num_unaligned_address_bits;

    variable result : crip_operation_t := crip_operation_init;
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
  function crip_response_width(data_width : crip_data_width_t) return positive is
  begin
    return data_width + crip_response_status_width;
  end function;
  ------------------------------------------------------------------------------

  ------------------------------------------------------------------------------
  function to_slv(
    data : crip_response_t; data_width : crip_data_width_t
  ) return std_ulogic_vector is
    constant result_width : positive := crip_response_width(data_width=>data_width);
    variable result : std_logic_vector(result_width - 1 downto 0) := (others => '0');
  begin
    result(data_width - 1 downto 0) := data.read_data(data_width - 1 downto 0);

    result(result'high) := to_sl(data.status);

    return result;
  end function;
  ------------------------------------------------------------------------------

  ------------------------------------------------------------------------------
  function to_crip_response(
    data : std_ulogic_vector; data_width : crip_data_width_t; enable : std_ulogic
  ) return crip_response_t is
    constant expected_slv_width : positive := crip_response_width(data_width=>data_width);

    variable result : crip_response_t := crip_response_init;
  begin
    assert data'length = expected_slv_width report "Unexpected SLV width";

    result.read_data(data_width - 1 downto 0) := data(data_width - 1 downto 0);

    result.status := to_crip_response_status(data(data'high));

    result.enable := enable;

    return result;
  end function;
  ------------------------------------------------------------------------------

end package body;
