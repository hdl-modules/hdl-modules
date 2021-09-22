-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the tsfpga project.
-- https://tsfpga.com
-- https://gitlab.com/tsfpga/tsfpga
-- -------------------------------------------------------------------------------------------------
-- Data types for working with AXI4-Stream interfaces.
-- Based on the document "ARM IHI 0051A (ID030610) AMBA 4 AXI4-Stream Protocol Specification"
-- Available here: https://developer.arm.com/documentation/ihi0051/a/
-- -------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


package axi_stream_pkg is

  -- Max value
  constant axi_stream_id_sz : positive := 8;
  constant axi_stream_dest_sz : positive := 4;

  -- Data bus width in bytes, 128b seems reasonable at the moment.
  constant axi_stream_data_sz : positive := 128;
  -- Integer multiple of the width of the interface in bytes.
  constant axi_stream_user_sz : positive := axi_stream_data_sz / 8;
  constant axi_stream_strb_sz : positive := axi_stream_data_sz / 8;
  constant axi_stream_keep_sz : positive := axi_stream_data_sz / 8;

  type axi_stream_m2s_t is record
    valid : std_logic;
    data : std_logic_vector(axi_stream_data_sz - 1 downto 0);
    last : std_logic;
    user : std_logic_vector(axi_stream_user_sz - 1 downto 0);
    -- Excluded members: tkeep, tstrb, tid, tdest.
    -- These are optional according to the standard and should be added when needed.
  end record;
  type axi_stream_m2s_vec_t is array (integer range <>) of axi_stream_m2s_t;

  constant axi_stream_m2s_init : axi_stream_m2s_t := (
    valid|last => '0',
    data|user => (others => '-')
  );

  type axi_stream_s2m_t is record
    ready : std_logic;
  end record;
  type axi_stream_s2m_vec_t is array (integer range <>) of axi_stream_s2m_t;

  constant axi_stream_s2m_init : axi_stream_s2m_t := (ready => '1');

  function axi_stream_m2s_sz(data_width : positive; user_width : natural) return natural;

  function to_slv(
    data : axi_stream_m2s_t;
    data_width : positive;
    user_width : natural
  ) return std_logic_vector;

  function to_axi_stream_m2s(
    data : std_logic_vector;
    data_width : positive;
    user_width : natural;
    valid : std_logic
  ) return axi_stream_m2s_t;

end;

package body axi_stream_pkg is

  function axi_stream_m2s_sz(data_width : positive; user_width : natural) return natural is
  begin
    -- Exluded member: valid
    -- The 1 is last
    return data_width + user_width + 1;
  end function;

  function to_slv(
    data : axi_stream_m2s_t;
    data_width : positive;
    user_width : natural
  ) return std_logic_vector is
    variable result : std_logic_vector(axi_stream_m2s_sz(data_width, user_width) - 1 downto 0);
    variable lo, hi : natural := 0;
  begin
    lo := 0;
    hi := lo + data_width - 1;
    result(hi downto lo) := data.data(data_width - 1 downto 0);
    lo := hi + 1;
    hi := lo;
    result(hi) := data.last;
    lo := hi + 1;
    hi := lo + user_width - 1;
    result(hi downto lo) := data.user(user_width - 1 downto 0);
    assert hi = result'high severity failure;
    return result;
  end function;

  function to_axi_stream_m2s(
    data : std_logic_vector;
    data_width : positive;
    user_width : natural;
    valid : std_logic
  ) return axi_stream_m2s_t is
    variable offset : natural := data'low;
    variable result : axi_stream_m2s_t := axi_stream_m2s_init;
    variable lo, hi : natural := 0;
  begin
    lo := 0;
    hi := lo + data_width - 1;
    result.data(data_width - 1 downto 0) := data(hi + offset downto lo + offset);
    lo := hi + 1;
    hi := lo;
    result.last := data(hi + offset);
    lo := hi + 1;
    hi := lo + user_width - 1;
    result.user(user_width - 1 downto 0) := data(hi + offset downto lo + offset);
    assert hi + offset = data'high severity failure;
    result.valid := valid;
    return result;
  end function;

end;
