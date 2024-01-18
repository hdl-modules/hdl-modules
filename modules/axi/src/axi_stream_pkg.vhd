-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the hdl-modules project, a collection of reusable, high-quality,
-- peer-reviewed VHDL building blocks.
-- https://hdl-modules.com
-- https://github.com/hdl-modules/hdl-modules
-- -------------------------------------------------------------------------------------------------
-- Data types for working with AXI4-Stream interfaces.
-- Based on the document "ARM IHI 0051A (ID030610) AMBA 4 AXI4-Stream Protocol Specification"
-- Available here: https://developer.arm.com/documentation/ihi0051/a/
-- -------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


package axi_stream_pkg is

  -- ID field (TID).
  -- The width value below is a max value, implementation should only take into regard the bits
  -- that are actually used.
  constant axi_stream_id_sz : positive := 8;

  -- Destination field (TDEST).
  -- The width value below is a max value, implementation should only take into regard the bits
  -- that are actually used.
  constant axi_stream_dest_sz : positive := 4;

  -- Data field (TDATA).
  -- The width value below is a max value, implementation should only take into regard the bits
  -- that are actually used.
  constant axi_stream_data_sz : positive := 128;

  -- Data strobe field (TSTRB).
  -- The width value below is a max value, implementation should only take into regard the bits
  -- that are actually used.
  constant axi_stream_strb_sz : positive := axi_stream_data_sz / 8;

  -- Data keep field (TKEEP).
  -- The width value below is a max value, implementation should only take into regard the bits
  -- that are actually used.
  constant axi_stream_keep_sz : positive := axi_stream_data_sz / 8;

  -- User field (TUSER).
  -- The width value below is a max value, implementation should only take into regard the bits
  -- that are actually used.
  constant axi_stream_user_sz : positive := axi_stream_data_sz / 8;

  -- Record for the AXI-Stream signals in the master-to-slave direction.
  type axi_stream_m2s_t is record
    valid : std_ulogic;
    data : std_ulogic_vector(axi_stream_data_sz - 1 downto 0);
    last : std_ulogic;
    user : std_ulogic_vector(axi_stream_user_sz - 1 downto 0);
    -- Excluded members: tkeep, tstrb, tid, tdest.
    -- These are optional according to the standard and should be added when needed.
  end record;
  type axi_stream_m2s_vec_t is array (integer range <>) of axi_stream_m2s_t;

  constant axi_stream_m2s_init : axi_stream_m2s_t := (
    valid => '0',
    last => '-',
    data => (others => '-'),
    user => (others => '-')
  );

  -- Record for the AXI-Stream signals in the slave-to-master direction.
  type axi_stream_s2m_t is record
    ready : std_ulogic;
  end record;
  type axi_stream_s2m_vec_t is array (integer range <>) of axi_stream_s2m_t;

  constant axi_stream_s2m_init : axi_stream_s2m_t := (ready => '1');

  function axi_stream_m2s_sz(
    data_width : positive range 1 to axi_stream_data_sz;
    user_width : natural range 0 to axi_stream_user_sz
  ) return natural;

  function to_slv(
    data : axi_stream_m2s_t;
    data_width : positive range 1 to axi_stream_data_sz;
    user_width : natural range 0 to axi_stream_user_sz
  ) return std_ulogic_vector;

  function to_axi_stream_m2s(
    data : std_ulogic_vector;
    data_width : positive range 1 to axi_stream_data_sz;
    user_width : natural range 0 to axi_stream_user_sz;
    valid : std_ulogic
  ) return axi_stream_m2s_t;

end;

package body axi_stream_pkg is

  function axi_stream_m2s_sz(
    data_width : positive range 1 to axi_stream_data_sz;
    user_width : natural range 0 to axi_stream_user_sz
  ) return natural is
  begin
    -- Excluded member: valid
    -- The 1 is for 'last'.
    return data_width + user_width + 1;
  end function;

  function to_slv(
    data : axi_stream_m2s_t;
    data_width : positive range 1 to axi_stream_data_sz;
    user_width : natural range 0 to axi_stream_user_sz
  ) return std_ulogic_vector is
    variable result : std_ulogic_vector(axi_stream_m2s_sz(data_width, user_width) - 1 downto 0);
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

    assert hi = result'high;

    return result;
  end function;

  function to_axi_stream_m2s(
    data : std_ulogic_vector;
    data_width : positive range 1 to axi_stream_data_sz;
    user_width : natural range 0 to axi_stream_user_sz;
    valid : std_ulogic
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

    assert hi + offset = data'high;

    result.valid := valid;

    return result;
  end function;

end;
