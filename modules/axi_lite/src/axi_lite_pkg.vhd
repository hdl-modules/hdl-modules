-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the hdl-modules project, a collection of reusable, high-quality,
-- peer-reviewed VHDL building blocks.
-- https://hdl-modules.com
-- https://github.com/hdl-modules/hdl-modules
-- -------------------------------------------------------------------------------------------------
-- Data types for working with AXI4-Lite interfaces.
-- Based on the document "ARM IHI 0022E (ID022613): AMBA AXI and ACE Protocol Specification"
-- Available here: http://infocenter.arm.com/help/index.jsp?topic=/com.arm.doc.ihi0022e/
-- -------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library axi;
use axi.axi_pkg.all;


package axi_lite_pkg is

  ------------------------------------------------------------------------------
  -- A (Address Read and Address Write) channels
  ------------------------------------------------------------------------------

  -- Record for the AR/AW signals in the master-to-slave direction.
  -- Note that the width of the 'addr' field is a max value, implementation should only take into
  -- regard the bits that are actually used.
  type axi_lite_m2s_a_t is record
    valid : std_ulogic;
    addr : u_unsigned(axi_a_addr_sz - 1 downto 0);
    -- Excluded members: prot
    -- These are typically not changed on a transfer-to-transfer basis.
  end record;

  constant axi_lite_m2s_a_init : axi_lite_m2s_a_t := (valid => '0', addr => (others => '0'));
  function axi_lite_m2s_a_sz(addr_width : positive range 1 to axi_a_addr_sz) return positive;

  -- Record for the AR/AW signals in the slave-to-master direction.
  type axi_lite_s2m_a_t is record
    ready : std_ulogic;
  end record;

  constant axi_lite_s2m_a_init : axi_lite_s2m_a_t := (ready => '0');


  ------------------------------------------------------------------------------
  -- W (Write Data) channels
  ------------------------------------------------------------------------------

  -- Data field (RDATA or WDATA).
  -- The width value below is a max value, implementation should only take into regard the bits
  -- that are actually used.
  constant axi_lite_data_sz : positive := 64;

  -- Check that a provided data width is valid to be used with AXI-Lite.
  -- Return 'true' if everything is okay, otherwise 'false'.
  function sanity_check_axi_lite_data_width(data_width : integer) return boolean;

  -- Write data strobe field (WSTRB).
  -- The width value below is a max value, implementation should only take into regard the bits
  -- that are actually used.
  constant axi_lite_w_strb_sz : positive := axi_lite_data_sz / 8;

  function to_axi_lite_strb(
    data_width : positive range 8 to axi_lite_data_sz
  ) return std_ulogic_vector;

  -- Record for the W signals in the master-to-slave direction.
  type axi_lite_m2s_w_t is record
    valid : std_ulogic;
    data : std_ulogic_vector(axi_lite_data_sz - 1 downto 0);
    strb : std_ulogic_vector(axi_lite_w_strb_sz - 1 downto 0);
  end record;

  constant axi_lite_m2s_w_init : axi_lite_m2s_w_t := (
    valid => '0', data => (others => '-'), strb => (others => '0')
  );
  function axi_lite_m2s_w_sz(data_width : positive range 8 to axi_lite_data_sz) return positive;

  function to_slv(
    data : axi_lite_m2s_w_t; data_width : positive range 8 to axi_lite_data_sz
  ) return std_ulogic_vector;
  function to_axi_lite_m2s_w(
    data : std_ulogic_vector; data_width : positive range 8 to axi_lite_data_sz
  ) return axi_lite_m2s_w_t;

  -- Record for the W signals in the slave-to-master direction.
  type axi_lite_s2m_w_t is record
    ready : std_ulogic;
  end record;

  constant axi_lite_s2m_w_init : axi_lite_s2m_w_t := (ready => '0');


  ------------------------------------------------------------------------------
  -- B (Write Response) channels
  ------------------------------------------------------------------------------

  -- Record for the B signals in the master-to-slave direction.
  type axi_lite_m2s_b_t is record
    ready : std_ulogic;
  end record;

  constant axi_lite_m2s_b_init : axi_lite_m2s_b_t := (ready => '0');

  -- Record for the B signals in the slave-to-master direction.
  type axi_lite_s2m_b_t is record
    valid : std_ulogic;
    resp : axi_resp_t;
  end record;

  constant axi_lite_s2m_b_init : axi_lite_s2m_b_t := (valid => '0', resp => (others => '-'));
  -- Excluded member: valid
  constant axi_lite_s2m_b_sz : positive := axi_resp_sz;


  ------------------------------------------------------------------------------
  -- R (Read Data) channels
  ------------------------------------------------------------------------------

  -- Record for the R signals in the master-to-slave direction.
  type axi_lite_m2s_r_t is record
    ready : std_ulogic;
  end record;

  constant axi_lite_m2s_r_init : axi_lite_m2s_r_t := (ready => '0');

  -- Record for the R signals in the slave-to-master direction.
  type axi_lite_s2m_r_t is record
    valid : std_ulogic;
    data : std_ulogic_vector(axi_lite_data_sz - 1 downto 0);
    resp : axi_resp_t;
  end record;

  constant axi_lite_s2m_r_init : axi_lite_s2m_r_t := (
    valid => '0', data => (others => '-'), resp => (others => '-')
  );
  function axi_lite_s2m_r_sz(data_width : positive range 8 to axi_lite_data_sz) return positive;

  function to_slv(
    data : axi_lite_s2m_r_t; data_width : positive range 8 to axi_lite_data_sz
  ) return std_ulogic_vector;
  function to_axi_lite_s2m_r(
    data : std_ulogic_vector; data_width : positive range 8 to axi_lite_data_sz
  ) return axi_lite_s2m_r_t;


  ------------------------------------------------------------------------------
  -- The complete buses
  ------------------------------------------------------------------------------

  type axi_lite_read_m2s_t is record
    ar : axi_lite_m2s_a_t;
    r : axi_lite_m2s_r_t;
  end record;
  type axi_lite_read_m2s_vec_t is array (integer range <>) of axi_lite_read_m2s_t;

  constant axi_lite_read_m2s_init : axi_lite_read_m2s_t := (
    ar => axi_lite_m2s_a_init,
    r => axi_lite_m2s_r_init
  );

  type axi_lite_read_s2m_t is record
    ar : axi_lite_s2m_a_t;
    r : axi_lite_s2m_r_t;
  end record;
  type axi_lite_read_s2m_vec_t is array (integer range <>) of axi_lite_read_s2m_t;

  constant axi_lite_read_s2m_init : axi_lite_read_s2m_t := (
    ar => axi_lite_s2m_a_init,
    r => axi_lite_s2m_r_init
  );

  type axi_lite_write_m2s_t is record
    aw : axi_lite_m2s_a_t;
    w : axi_lite_m2s_w_t;
    b : axi_lite_m2s_b_t;
  end record;
  type axi_lite_write_m2s_vec_t is array (integer range <>) of axi_lite_write_m2s_t;

  constant axi_lite_write_m2s_init : axi_lite_write_m2s_t := (
    aw => axi_lite_m2s_a_init,
    w => axi_lite_m2s_w_init,
    b => axi_lite_m2s_b_init
  );

  type axi_lite_write_s2m_t is record
    aw : axi_lite_s2m_a_t;
    w : axi_lite_s2m_w_t;
    b : axi_lite_s2m_b_t;
  end record;
  type axi_lite_write_s2m_vec_t is array (integer range <>) of axi_lite_write_s2m_t;

  constant axi_lite_write_s2m_init : axi_lite_write_s2m_t := (
    aw => axi_lite_s2m_a_init,
    w => axi_lite_s2m_w_init,
    b => axi_lite_s2m_b_init
  );

  type axi_lite_m2s_t is record
    read : axi_lite_read_m2s_t;
    write : axi_lite_write_m2s_t;
  end record;
  type axi_lite_m2s_vec_t is array (integer range <>) of axi_lite_m2s_t;

  constant axi_lite_m2s_init : axi_lite_m2s_t := (
    read => axi_lite_read_m2s_init,
    write => axi_lite_write_m2s_init
  );

  type axi_lite_s2m_t is record
    read : axi_lite_read_s2m_t;
    write : axi_lite_write_s2m_t;
  end record;
  type axi_lite_s2m_vec_t is array (integer range <>) of axi_lite_s2m_t;

  constant axi_lite_s2m_init : axi_lite_s2m_t := (
    read => axi_lite_read_s2m_init,
    write => axi_lite_write_s2m_init
  );

end;

package body axi_lite_pkg is

  ------------------------------------------------------------------------------
  function axi_lite_m2s_a_sz(addr_width : positive range 1 to axi_a_addr_sz) return positive is
  begin
    -- Excluded member: valid.
    return addr_width;
  end function;
  ------------------------------------------------------------------------------

  ------------------------------------------------------------------------------
  function sanity_check_axi_lite_data_width(data_width : integer) return boolean is
    constant message : string := ". Got data_width=" & integer'image(data_width) & ".";
  begin
    if data_width /= 32 and data_width /= 64 then
      report "AXI-Lite data width must be either 32 or 64" & message;
      return false;
    end if;

    return true;
  end function;

  function to_axi_lite_strb(
    data_width : positive range 8 to axi_lite_data_sz
  ) return std_ulogic_vector is
    variable result : std_ulogic_vector(axi_lite_w_strb_sz - 1 downto 0) := (others => '0');
  begin
    assert sanity_check_axi_lite_data_width(data_width)
      report "Invalid data width, see printout above"
      severity failure;

    result(data_width / 8 - 1 downto 0) := (others => '1');

    return result;
  end function;

  function axi_lite_m2s_w_sz(data_width : positive range 8 to axi_lite_data_sz) return positive is
  begin
    assert sanity_check_axi_lite_data_width(data_width)
      report "Invalid data width, see printout above"
      severity failure;

    -- Excluded member: valid
    return data_width + axi_w_strb_width(data_width);
  end function;

  function to_slv(
    data : axi_lite_m2s_w_t; data_width : positive range 8 to axi_lite_data_sz
  ) return std_ulogic_vector is
    variable result : std_ulogic_vector(axi_lite_m2s_w_sz(data_width) - 1 downto 0);
    variable lo, hi : natural := 0;
  begin
    lo := 0;
    hi := lo + data_width - 1;
    result(hi downto lo) := data.data(data_width - 1 downto 0);

    lo := hi + 1;
    hi := lo + axi_w_strb_width(data_width) - 1;
    result(hi downto lo) := data.strb(axi_w_strb_width(data_width) - 1 downto 0);

    assert hi = result'high;

    return result;
  end function;

  function to_axi_lite_m2s_w(
    data : std_ulogic_vector; data_width : positive range 8 to axi_lite_data_sz
  ) return axi_lite_m2s_w_t is
    variable result : axi_lite_m2s_w_t := axi_lite_m2s_w_init;
    variable lo, hi : natural := 0;
  begin
    lo := 0;
    hi := lo + data_width - 1;
    result.data(data_width - 1 downto 0) := data(hi downto lo);

    lo := hi + 1;
    hi := lo + axi_w_strb_width(data_width) - 1;
    result.strb(axi_w_strb_width(data_width) - 1 downto 0) := data(hi downto lo);

    assert hi = data'high;

    return result;
  end function;
  ------------------------------------------------------------------------------

  ------------------------------------------------------------------------------
  function axi_lite_s2m_r_sz(data_width : positive range 8 to axi_lite_data_sz)  return positive is
  begin
    assert sanity_check_axi_lite_data_width(data_width)
      report "Invalid data width, see printout above"
      severity failure;

    -- Excluded member: valid
    return data_width + axi_resp_sz;
  end function;

  function to_slv(
    data : axi_lite_s2m_r_t; data_width : positive range 8 to axi_lite_data_sz
  ) return std_ulogic_vector is
    variable result : std_ulogic_vector(axi_lite_s2m_r_sz(data_width) - 1 downto 0);
    variable lo, hi : natural := 0;
  begin
    lo := 0;
    hi := lo + data_width - 1;
    result(hi downto lo) := data.data(data_width - 1 downto 0);

    lo := hi + 1;
    hi := lo + axi_resp_sz - 1;
    result(hi downto lo) := data.resp;

    assert hi = result'high;

    return result;
  end function;

  function to_axi_lite_s2m_r(
    data : std_ulogic_vector; data_width : positive range 8 to axi_lite_data_sz
  ) return axi_lite_s2m_r_t is
    variable result : axi_lite_s2m_r_t := axi_lite_s2m_r_init;
    variable lo, hi : natural := 0;
  begin
    lo := 0;
    hi := lo + data_width - 1;
    result.data(data_width - 1 downto 0) := data(hi downto lo);

    lo := hi + 1;
    hi := lo + axi_resp_sz - 1;
    result.resp := data(hi downto lo);

    assert hi = data'high;

    return result;
  end function;
  ------------------------------------------------------------------------------

end;
