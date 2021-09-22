-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the tsfpga project.
-- https://tsfpga.com
-- https://gitlab.com/tsfpga/tsfpga
-- -------------------------------------------------------------------------------------------------
-- Data types for working with AXI4-Lite interfaces.
-- Based on the document "ARM IHI 0022E (ID022613): AMBA AXI and ACE Protocol Specification"
-- Available here: http://infocenter.arm.com/help/index.jsp?topic=/com.arm.doc.ihi0022e/
-- -------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.axi_pkg.all;


package axi_lite_pkg is

  ------------------------------------------------------------------------------
  -- A (Address Read and Address Write) channels
  ------------------------------------------------------------------------------

  type axi_lite_m2s_a_t is record
    valid : std_logic;
    addr : unsigned(axi_a_addr_sz - 1 downto 0);
    -- Excluded members: prot
    -- These are typically not changed on a transfer-to-transfer basis.
  end record;

  constant axi_lite_m2s_a_init : axi_lite_m2s_a_t := (valid => '0', others => (others => '0'));
  function axi_lite_m2s_a_sz(addr_width : positive) return positive;

  type axi_lite_s2m_a_t is record
    ready : std_logic;
  end record;

  constant axi_lite_s2m_a_init : axi_lite_s2m_a_t := (ready => '0');


  ------------------------------------------------------------------------------
  -- W (Write Data) channels
  ------------------------------------------------------------------------------

  -- Max values
  constant axi_lite_data_sz : positive := 64;
  constant axi_lite_w_strb_sz : positive := axi_lite_data_sz / 8;

  function to_axi_lite_strb(data_width : positive) return std_logic_vector;

  type axi_lite_m2s_w_t is record
    valid : std_logic;
    data : std_logic_vector(axi_lite_data_sz - 1 downto 0);
    strb : std_logic_vector(axi_lite_w_strb_sz - 1 downto 0);
  end record;

  constant axi_lite_m2s_w_init : axi_lite_m2s_w_t := (valid => '0', others => (others => '-'));

  function axi_lite_m2s_w_sz(data_width : positive) return positive;
  function to_slv(data : axi_lite_m2s_w_t; data_width : positive) return std_logic_vector;
  function to_axi_lite_m2s_w(data : std_logic_vector; data_width : positive) return axi_lite_m2s_w_t;

  type axi_lite_s2m_w_t is record
    ready : std_logic;
  end record;

  constant axi_lite_s2m_w_init : axi_lite_s2m_w_t := (ready => '0');


  ------------------------------------------------------------------------------
  -- B (Write Response) channels
  ------------------------------------------------------------------------------

  type axi_lite_m2s_b_t is record
    ready : std_logic;
  end record;

  constant axi_lite_m2s_b_init : axi_lite_m2s_b_t := (ready => '0');

  type axi_lite_s2m_b_t is record
    valid : std_logic;
    resp : std_logic_vector(axi_resp_sz - 1 downto 0);
  end record;

  constant axi_lite_s2m_b_init : axi_lite_s2m_b_t := (valid => '0', others => (others => '0'));
  -- Exluded member: valid
  constant axi_lite_s2m_b_sz : positive := axi_resp_sz;


  ------------------------------------------------------------------------------
  -- R (Read Data) channels
  ------------------------------------------------------------------------------

  type axi_lite_m2s_r_t is record
    ready : std_logic;
  end record;

  constant axi_lite_m2s_r_init : axi_lite_m2s_r_t := (ready => '0');

  type axi_lite_s2m_r_t is record
    valid : std_logic;
    data : std_logic_vector(axi_lite_data_sz - 1 downto 0);
    resp : std_logic_vector(axi_resp_sz - 1 downto 0);
  end record;

  constant axi_lite_s2m_r_init : axi_lite_s2m_r_t := (valid => '0', others => (others => '0'));
  function axi_lite_s2m_r_sz(data_width : positive) return positive;
  function to_slv(data : axi_lite_s2m_r_t; data_width : positive) return std_logic_vector;
  function to_axi_lite_s2m_r(data : std_logic_vector; data_width : positive) return axi_lite_s2m_r_t;


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

  function axi_lite_m2s_a_sz(addr_width : positive) return positive is
  begin
    -- Excluded membed: valid.
    return addr_width;
  end function;

  function axi_lite_m2s_w_sz(data_width : positive) return positive is
  begin
    assert data_width = 32 or data_width = 64
      report "AXI4-Lite protocol only supports data width 32 or 64" severity failure;
    -- Exluded member: valid
    return data_width + axi_w_strb_width(data_width);
  end function;

  function to_axi_lite_strb(data_width : positive) return std_logic_vector is
    variable result : std_logic_vector(axi_lite_w_strb_sz - 1 downto 0) := (others => '0');
  begin
    result(data_width / 8 - 1 downto 0) := (others => '1');
    return result;
  end function;

  function to_slv(data : axi_lite_m2s_w_t; data_width : positive) return std_logic_vector is
    variable result : std_logic_vector(axi_lite_m2s_w_sz(data_width) - 1 downto 0);
    variable lo, hi : natural := 0;
  begin
    lo := 0;
    hi := lo + data_width - 1;
    result(hi downto lo) := data.data(data_width - 1 downto 0);
    lo := hi + 1;
    hi := lo + axi_w_strb_width(data_width) - 1;
    result(hi downto lo) := data.strb(axi_w_strb_width(data_width) - 1 downto 0);
    assert hi = result'high severity failure;
    return result;
  end function;

  function to_axi_lite_m2s_w(
    data : std_logic_vector;
    data_width : positive
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
    assert hi = data'high severity failure;
    return result;
  end function;

  function axi_lite_s2m_r_sz(data_width : positive)  return positive is
  begin
    -- Exluded member: valid
    return data_width + axi_resp_sz;
  end function;

  function to_slv(data : axi_lite_s2m_r_t; data_width : positive) return std_logic_vector is
    variable result : std_logic_vector(axi_lite_s2m_r_sz(data_width) - 1 downto 0);
    variable lo, hi : natural := 0;
  begin
    lo := 0;
    hi := lo + data_width - 1;
    result(hi downto lo) := data.data(data_width - 1 downto 0);
    lo := hi + 1;
    hi := lo + axi_resp_sz - 1;
    result(hi downto lo) := data.resp;
    assert hi = result'high severity failure;
    return result;
  end function;

  function to_axi_lite_s2m_r(
    data : std_logic_vector;
    data_width : positive
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
    assert hi = data'high severity failure;
    return result;
  end function;

end;
