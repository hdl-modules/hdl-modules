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

library osvvm;
use osvvm.RandomPkg.RandomPType;

library common;
use common.types_pkg.to_sl;

use work.trail_pkg.all;


package trail_sim_pkg is

  ------------------------------------------------------------------------------
  type trail_bfm_command_t is record
    write_enable : std_ulogic;
    address : u_unsigned(trail_max_address_width - 1 downto 0);
    data : std_ulogic_vector(trail_max_data_width - 1 downto 0);
    expect_error : std_ulogic;
  end record;
  constant trail_bfm_command_init : trail_bfm_command_t := (
    write_enable => '0',
    address => (others => '0'),
    data => (others => '0'),
    expect_error => '0'
  );

  constant trail_bfm_command_width : positive := (
    1 + trail_max_address_width + trail_max_data_width + 1
  );

  procedure get_random_trail_bfm_command(
    constant address_width : trail_address_width_t;
    constant data_width : trail_data_width_t;
    constant include_error : boolean := true;
    rnd : inout RandomPType;
    command : out trail_bfm_command_t
  );

  function to_slv(data : trail_bfm_command_t) return std_logic_vector;
  function to_trail_bfm_command(
    data : std_logic_vector(trail_bfm_command_width - 1 downto 0)
  ) return trail_bfm_command_t;
  ------------------------------------------------------------------------------

  ------------------------------------------------------------------------------
  procedure get_random_trail_address(
    constant address_width : trail_address_width_t;
    constant data_width : trail_data_width_t;
    rnd : inout RandomPType;
    address : out u_unsigned
  );
  ------------------------------------------------------------------------------

end;

package body trail_sim_pkg is

  ------------------------------------------------------------------------------
  procedure get_random_trail_bfm_command(
    constant address_width : trail_address_width_t;
    constant data_width : trail_data_width_t;
    constant include_error : boolean := true;
    rnd : inout RandomPType;
    command : out trail_bfm_command_t
  ) is
    variable result : trail_bfm_command_t := trail_bfm_command_init;
    variable result_address : u_unsigned(address_width - 1 downto 0) := (others => '0');
  begin
    result.write_enable := rnd.RandSlv(1)(1);

    get_random_trail_address(
      address_width=>address_width, data_width=>data_width, rnd=>rnd, address=>result_address
    );
    result.address(result_address'range) := result_address;

    result.data := rnd.RandSlv(result.data'length);

    if include_error then
      result.expect_error := to_sl(rnd.DistBool(Weight=>(false=>9, true=>1)));
    else
      result.expect_error := '0';
    end if;

    command := result;
  end procedure;

  function to_slv(data : trail_bfm_command_t) return std_logic_vector is
    variable result : std_logic_vector(trail_bfm_command_width - 1 downto 0) := (others => '0');
    variable lo, hi : natural := 0;
  begin
    result(lo) := data.write_enable;

    lo := hi + 1;
    hi := lo + data.address'length - 1;
    result(hi downto lo) := std_logic_vector(data.address);

    lo := hi + 1;
    hi := lo + data.data'length - 1;
    result(hi downto lo) := data.data;

    lo := hi + 1;
    result(lo) := data.expect_error;

    assert lo = result'high report "Something wrong with widths.";

    return result;
  end function;

  function to_trail_bfm_command(
    data : std_logic_vector(trail_bfm_command_width - 1 downto 0)
  ) return trail_bfm_command_t is
    variable result : trail_bfm_command_t := trail_bfm_command_init;
    variable lo, hi : natural := 0;
  begin
    result.write_enable := data(lo);

    lo := hi + 1;
    hi := lo + result.address'length - 1;
    result.address := u_unsigned(data(hi downto lo));

    lo := hi + 1;
    hi := lo + result.data'length - 1;
    result.data := data(hi downto lo);

    lo := hi + 1;
    result.expect_error := data(lo);

    assert lo = data'high report "Something wrong with widths.";

    return result;
  end function;
  ------------------------------------------------------------------------------

  ------------------------------------------------------------------------------
  procedure get_random_trail_address(
    constant address_width : trail_address_width_t;
    constant data_width : trail_data_width_t;
    rnd : inout RandomPType;
    address : out u_unsigned
  ) is
    constant num_unaligned_address_bits : natural := trail_num_unaligned_address_bits(
      data_width=>data_width
    );
    variable result : u_unsigned(address_width - 1 downto 0) := (others => '0');
  begin
    result := rnd.RandUnsigned(result'length);
    result(num_unaligned_address_bits - 1 downto 0) := (others => '0');

    address := result;
  end procedure;
  ------------------------------------------------------------------------------

end package body;
