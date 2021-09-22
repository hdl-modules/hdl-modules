-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the tsfpga project.
-- https://tsfpga.com
-- https://gitlab.com/tsfpga/tsfpga
-- -------------------------------------------------------------------------------------------------
-- Data types for working with AXI4 interfaces
--
-- Based on the document "ARM IHI 0022E (ID022613): AMBA AXI and ACE Protocol Specification",
-- available here: http://infocenter.arm.com/help/index.jsp?topic=/com.arm.doc.ihi0022e/index.html
-- -------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library math;
use math.math_pkg.all;


package axi_pkg is

  -- Max value
  constant axi_id_sz : positive := 24;

  constant axi_max_burst_length_beats : positive := 256;
  constant axi3_max_burst_length_beats : positive := 16;


  ------------------------------------------------------------------------------
  -- A (Address Read and Address Write) channels
  ------------------------------------------------------------------------------

  -- Max value
  constant axi_a_addr_sz : positive := 64;
  -- Number of transfers = len + 1
  constant axi_a_len_sz : positive := 8;
  -- Bytes per transfer = 2^size
  constant axi_a_size_sz : positive := 3;

  function to_len(burst_length_beats : positive) return unsigned;
  function to_size(data_width_bits : positive) return unsigned;

  constant axi_a_burst_sz : positive := 2;
  constant axi_a_burst_fixed : std_logic_vector(axi_a_burst_sz - 1 downto 0) := "00";
  constant axi_a_burst_incr : std_logic_vector(axi_a_burst_sz - 1 downto 0) := "01";
  constant axi_a_burst_wrap : std_logic_vector(axi_a_burst_sz - 1 downto 0) := "10";

  constant axi_a_lock_sz : positive := 1; -- Two bits in AXI3
  constant axi_a_lock_normal : std_logic_vector(axi_a_lock_sz - 1 downto 0) := "0";
  constant axi_a_lock_exclusive : std_logic_vector(axi_a_lock_sz - 1 downto 0) := "1";
  constant axi3_a_lock_normal : std_logic_vector(2 - 1 downto 0) := "00";
  constant axi3_a_lock_exclusive : std_logic_vector(2 - 1 downto 0) := "01";
  constant axi3_a_lock_locked : std_logic_vector(2 - 1 downto 0) := "10";

  constant axi_a_cache_sz : positive := 4;
  constant axi_a_cache_device_non_bufferable : std_logic_vector(axi_a_cache_sz - 1 downto 0) := "0000";
  constant axi_a_cache_device_bufferable : std_logic_vector(axi_a_cache_sz - 1 downto 0) := "0001";
  constant axi_a_cache_normal_non_cacheable_non_bufferable : std_logic_vector(axi_a_cache_sz - 1 downto 0) := "0010";
  constant axi_a_cache_normal_non_cacheable_bufferable : std_logic_vector(axi_a_cache_sz - 1 downto 0) := "0011";
  constant axi_ar_cache_write_through_no_allocate : std_logic_vector(axi_a_cache_sz - 1 downto 0) := "1010";
  constant axi_aw_cache_write_through_no_allocate : std_logic_vector(axi_a_cache_sz - 1 downto 0) := "0110";
  constant axi_a_cache_write_through_read_allocate : std_logic_vector(axi_a_cache_sz - 1 downto 0) := "0110";
  constant axi_a_cache_write_through_write_allocate : std_logic_vector(axi_a_cache_sz - 1 downto 0) := "1010";
  constant axi_a_cache_write_through_read_and_write_allocate : std_logic_vector(axi_a_cache_sz - 1 downto 0) := "1110";
  constant axi_ar_cache_write_back_no_allocate : std_logic_vector(axi_a_cache_sz - 1 downto 0) := "1011";
  constant axi_aw_cache_write_back_no_allocate : std_logic_vector(axi_a_cache_sz - 1 downto 0) := "0111";
  constant axi_a_cache_write_back_read_allocate : std_logic_vector(axi_a_cache_sz - 1 downto 0) := "0111";
  constant axi_a_cache_write_back_write_allocate : std_logic_vector(axi_a_cache_sz - 1 downto 0) := "1011";
  constant axi_a_cache_write_back_read_and_write_allocate : std_logic_vector(axi_a_cache_sz - 1 downto 0) := "1111";

  constant axi_a_prot_sz : positive := 3;
  constant axi_a_prot_privileged : std_logic_vector(axi_a_prot_sz - 1 downto 0) := "001";
  constant axi_a_prot_unprivileged : std_logic_vector(axi_a_prot_sz - 1 downto 0) := "000";
  constant axi_a_prot_secure : std_logic_vector(axi_a_prot_sz - 1 downto 0) := "000";
  constant axi_a_prot_nonsecure : std_logic_vector(axi_a_prot_sz - 1 downto 0) := "010";
  constant axi_a_prot_data : std_logic_vector(axi_a_prot_sz - 1 downto 0) := "000";
  constant axi_a_prot_instruction : std_logic_vector(axi_a_prot_sz - 1 downto 0) := "100";

  constant axi_a_region_sz : positive := 4;

  type axi_m2s_a_t is record
    valid : std_logic;
    id : unsigned(axi_id_sz - 1 downto 0);
    addr : unsigned(axi_a_addr_sz - 1 downto 0);
    len : unsigned(axi_a_len_sz - 1 downto 0);
    size : unsigned(axi_a_size_sz - 1 downto 0);
    burst : std_logic_vector(axi_a_burst_sz - 1 downto 0);
    -- Excluded members: lock, cache, prot, region.
    -- These are typically not changed on a transfer-to-transfer basis.
  end record;

  constant axi_m2s_a_init : axi_m2s_a_t := (
    valid => '0',
    burst => (others => '0'),
    others => (others => '0')
  );
  function axi_m2s_a_sz(id_width : natural; addr_width : positive)  return positive;
  type axi_m2s_a_vec_t is array (integer range <>) of axi_m2s_a_t;

  function to_slv(
    data : axi_m2s_a_t; id_width : natural; addr_width : positive
  ) return std_logic_vector;
  function to_axi_m2s_a(
    data : std_logic_vector; id_width : natural; addr_width : positive
  ) return axi_m2s_a_t;

  type axi_s2m_a_t is record
    ready : std_logic;
  end record;

  constant axi_s2m_a_init : axi_s2m_a_t := (ready => '0');
  type axi_s2m_a_vec_t is array (integer range <>) of axi_s2m_a_t;


  ------------------------------------------------------------------------------
  -- W (Write Data) channels
  ------------------------------------------------------------------------------

  -- Max values
  constant axi_data_sz : positive := 128;
  constant axi_w_strb_sz : positive := axi_data_sz / 8;

  function to_strb(data_width : positive) return std_logic_vector;

  type axi_m2s_w_t is record
    valid : std_logic;
    data : std_logic_vector(axi_data_sz - 1 downto 0);
    strb : std_logic_vector(axi_w_strb_sz - 1 downto 0);
    last : std_logic;
    -- Only available in AXI3. We assume that AXI4 is used most of the time, hence id_width is
    -- defaulted to zero in the functions below.
    id : unsigned(axi_id_sz - 1 downto 0);
  end record;

  constant axi_m2s_w_init : axi_m2s_w_t := (
    valid => '0',
    data => (others => '-'),
    last => '0',
    id => (others => '-'),
    others => (others => '0')
  );
  function axi_m2s_w_sz(data_width : positive; id_width : natural := 0) return positive;
  type axi_m2s_w_vec_t is array (integer range <>) of axi_m2s_w_t;

  function axi_w_strb_width(data_width : positive) return positive;

  function to_slv(
    data : axi_m2s_w_t; data_width : positive; id_width : natural := 0
  ) return std_logic_vector;
  function to_axi_m2s_w(
    data : std_logic_vector; data_width : positive; id_width : natural := 0
  ) return axi_m2s_w_t;

  type axi_s2m_w_t is record
    ready : std_logic;
  end record;
  type axi_s2m_w_vec_t is array (integer range <>) of axi_s2m_w_t;

  constant axi_s2m_w_init : axi_s2m_w_t := (ready => '0');


  ------------------------------------------------------------------------------
  -- B (Write Response) channels
  ------------------------------------------------------------------------------

  type axi_m2s_b_t is record
    ready : std_logic;
  end record;

  constant axi_m2s_b_init : axi_m2s_b_t := (ready => '0');

  constant axi_resp_sz : positive := 2;
  constant axi_resp_okay : std_logic_vector(axi_resp_sz - 1 downto 0) := "00";
  -- Exclusive access okay.
  constant axi_resp_exokay : std_logic_vector(axi_resp_sz - 1 downto 0) := "01";
  -- Slave error. Slave wishes to return error.
  constant axi_resp_slverr : std_logic_vector(axi_resp_sz - 1 downto 0) := "10";
  -- Decode error. There is no slave at transaction address.
  constant axi_resp_decerr : std_logic_vector(axi_resp_sz - 1 downto 0) := "11";

  type axi_s2m_b_t is record
    valid : std_logic;
    id : unsigned(axi_id_sz - 1 downto 0);
    resp : std_logic_vector(axi_resp_sz - 1 downto 0);
  end record;

  constant axi_s2m_b_init : axi_s2m_b_t := (
    valid => '0',
    id => (others => '0'),
    resp => (others => '0')
  );
  function axi_s2m_b_sz(id_width : natural) return positive;
  type axi_s2m_b_vec_t is array (integer range <>) of axi_s2m_b_t;

  function to_slv(data : axi_s2m_b_t; id_width : natural) return std_logic_vector;
  function to_axi_s2m_b(data : std_logic_vector; id_width : natural) return axi_s2m_b_t;


  ------------------------------------------------------------------------------
  -- R (Read Data) channels
  ------------------------------------------------------------------------------

  type axi_m2s_r_t is record
    ready : std_logic;
  end record;
  type axi_m2s_r_vec_t is array (integer range <>) of axi_m2s_r_t;

  constant axi_m2s_r_init : axi_m2s_r_t := (ready => '0');

  type axi_s2m_r_t is record
    valid : std_logic;
    id : unsigned(axi_id_sz - 1 downto 0);
    data : std_logic_vector(axi_data_sz - 1 downto 0);
    resp : std_logic_vector(axi_resp_sz - 1 downto 0);
    last : std_logic;
  end record;

  constant axi_s2m_r_init : axi_s2m_r_t := (
    valid => '0',
    last => '0',
    id => (others => '0'),
    others => (others => '0')
  );
  function axi_s2m_r_sz(data_width : positive; id_width : natural)  return positive;
  type axi_s2m_r_vec_t is array (integer range <>) of axi_s2m_r_t;

  function to_slv(data : axi_s2m_r_t; data_width : positive; id_width : natural) return std_logic_vector;
  function to_axi_s2m_r(data : std_logic_vector; data_width : positive; id_width : natural) return axi_s2m_r_t;


  ------------------------------------------------------------------------------
  -- The complete buses
  ------------------------------------------------------------------------------

  type axi_read_m2s_t is record
    ar : axi_m2s_a_t;
    r : axi_m2s_r_t;
  end record;
  type axi_read_m2s_vec_t is array (integer range <>) of axi_read_m2s_t;

  constant axi_read_m2s_init : axi_read_m2s_t := (ar => axi_m2s_a_init, r => axi_m2s_r_init);

  type axi_read_s2m_t is record
    ar : axi_s2m_a_t;
    r : axi_s2m_r_t;
  end record;
  type axi_read_s2m_vec_t is array (integer range <>) of axi_read_s2m_t;

  constant axi_read_s2m_init : axi_read_s2m_t := (ar => axi_s2m_a_init, r => axi_s2m_r_init);

  type axi_write_m2s_t is record
    aw : axi_m2s_a_t;
    w : axi_m2s_w_t;
    b : axi_m2s_b_t;
  end record;
  type axi_write_m2s_vec_t is array (integer range <>) of axi_write_m2s_t;

  constant axi_write_m2s_init : axi_write_m2s_t := (aw => axi_m2s_a_init, w => axi_m2s_w_init, b => axi_m2s_b_init);

  type axi_write_s2m_t is record
    aw : axi_s2m_a_t;
    w : axi_s2m_w_t;
    b : axi_s2m_b_t;
  end record;
  type axi_write_s2m_vec_t is array (integer range <>) of axi_write_s2m_t;

  constant axi_write_s2m_init : axi_write_s2m_t := (aw => axi_s2m_a_init, w => axi_s2m_w_init, b => axi_s2m_b_init);

  type axi_m2s_t is record
    read : axi_read_m2s_t;
    write : axi_write_m2s_t;
  end record;
  type axi_m2s_vec_t is array (integer range <>) of axi_m2s_t;

  constant axi_m2s_init : axi_m2s_t := (read => axi_read_m2s_init, write => axi_write_m2s_init);

  type axi_s2m_t is record
    read : axi_read_s2m_t;
    write : axi_write_s2m_t;
  end record;
  type axi_s2m_vec_t is array (integer range <>) of axi_s2m_t;

  constant axi_s2m_init : axi_s2m_t := (read => axi_read_s2m_init, write => axi_write_s2m_init);

  function combine_response(resp1, resp2 : std_logic_vector(axi_resp_sz - 1 downto 0))
    return std_logic_vector;

end;

package body axi_pkg is

  function to_len(burst_length_beats : positive) return unsigned is
    variable result : unsigned(axi_a_len_sz - 1 downto 0);
  begin
    -- burst_length_beats is number of transfers
    result := to_unsigned(burst_length_beats - 1, result'length);
    return result;
  end function;

  function to_size(data_width_bits : positive) return unsigned is
    variable result : unsigned(axi_a_size_sz - 1 downto 0);
  begin
    result := to_unsigned(log2(data_width_bits / 8), result'length);
    return result;
  end function;

  function axi_m2s_a_sz(id_width : natural; addr_width : positive) return positive is
  begin
    -- Exluded member: valid
    return id_width + addr_width + axi_a_len_sz + axi_a_size_sz + axi_a_burst_sz;
  end function;

  function to_slv(
    data : axi_m2s_a_t; id_width : natural; addr_width : positive
  ) return std_logic_vector is
    variable result : std_logic_vector(axi_m2s_a_sz(id_width, addr_width) - 1 downto 0);
    variable lo, hi : natural := 0;
  begin
    lo := 0;
    if id_width > 0 then
      hi := id_width - 1;
      result(hi downto lo) := std_logic_vector(data.id(hi downto lo));
      lo := hi + 1;
    end if;
    hi := lo + addr_width - 1;
    result(hi downto lo) := std_logic_vector(data.addr(addr_width - 1 downto 0));
    lo := hi + 1;
    hi := lo + data.len'length - 1;
    result(hi downto lo) := std_logic_vector(data.len);
    lo := hi + 1;
    hi := lo + data.size'length - 1;
    result(hi downto lo) := std_logic_vector(data.size);
    lo := hi + 1;
    hi := lo + data.burst'length - 1;
    result(hi downto lo) := data.burst;
    assert hi = result'high severity failure;
    return result;
  end function;

  function to_axi_m2s_a(
    data : std_logic_vector; id_width : natural; addr_width : positive
  ) return axi_m2s_a_t is
    constant offset : natural := data'low;
    variable result : axi_m2s_a_t := axi_m2s_a_init;
    variable lo, hi : natural := 0;
  begin
    lo := 0;
    if id_width > 0 then
      hi := id_width - 1;
      result.id(hi downto lo) := unsigned(data(hi + offset downto lo + offset));
      lo := hi + 1;
    end if;
    hi := lo + addr_width - 1;
    result.addr(addr_width - 1 downto 0) := unsigned(data(hi + offset downto lo + offset));
    lo := hi + 1;
    hi := lo + result.len'length - 1;
    result.len := unsigned(data(hi + offset downto lo + offset));
    lo := hi + 1;
    hi := lo + result.size'length - 1;
    result.size := unsigned(data(hi + offset downto lo + offset));
    lo := hi + 1;
    hi := lo + result.burst'length - 1;
    result.burst := data(hi + offset downto lo + offset);
    assert hi + offset = data'high severity failure;
    return result;
  end function;

  function to_strb(data_width : positive) return std_logic_vector is
    variable result : std_logic_vector(axi_w_strb_sz - 1 downto 0) := (others => '0');
  begin
    result(data_width / 8 - 1 downto 0) := (others => '1');
    return result;
  end function;

  function axi_w_strb_width(data_width : positive) return positive is
  begin
    return data_width / 8;
  end function;

  function axi_m2s_w_sz(data_width : positive; id_width : natural := 0) return positive is
  begin
    -- Exluded member: valid.
    -- The 1 is "last".
    return data_width + axi_w_strb_width(data_width) + 1 + id_width;
  end function;

  function to_slv(
    data : axi_m2s_w_t; data_width : positive; id_width : natural := 0
  ) return std_logic_vector is
    variable result :
      std_logic_vector(axi_m2s_w_sz(data_width=>data_width, id_width=>id_width) - 1 downto 0) :=
      (others => '0');
    variable lo, hi : natural := 0;
  begin
    lo := 0;

    hi := lo + data_width - 1;
    result(hi downto lo) := data.data(data_width - 1 downto 0);
    lo := hi + 1;

    hi := lo + axi_w_strb_width(data_width) - 1;
    result(hi downto lo) := data.strb(axi_w_strb_width(data_width) - 1 downto 0);
    lo := hi + 1;

    hi := lo + id_width - 1;
    result(hi downto lo) := std_logic_vector(data.id(id_width - 1 downto 0));
    lo := hi + 1;

    hi := lo;
    result(hi) := data.last;
    assert hi = result'high severity failure;
    return result;
  end function;

  function to_axi_m2s_w(
    data : std_logic_vector; data_width : positive; id_width : natural := 0
  ) return axi_m2s_w_t is
    constant offset : natural := data'low;
    variable result : axi_m2s_w_t := axi_m2s_w_init;
    variable lo, hi : natural := 0;
  begin
    lo := 0;

    hi := lo + data_width - 1;
    result.data(data_width - 1 downto 0) := data(hi + offset downto lo + offset);
    lo := hi + 1;

    hi := lo + axi_w_strb_width(data_width) - 1;
    result.strb(axi_w_strb_width(data_width) - 1 downto 0) := data(hi + offset downto lo + offset);
    lo := hi + 1;

    hi := lo + id_width - 1;
    result.id(id_width - 1 downto 0) := unsigned(data(hi + offset downto lo + offset));
    lo := hi + 1;

    hi := lo;
    result.last := data(hi + offset);
    assert hi + offset = data'high severity failure;
    return result;
  end function;

  function axi_s2m_b_sz(id_width : natural) return positive is
  begin
    -- Exluded member: valid
    return id_width + axi_resp_sz;
  end function;

  function to_slv(data : axi_s2m_b_t; id_width : natural) return std_logic_vector is
    variable result : std_logic_vector(axi_s2m_b_sz(id_width) - 1 downto 0);
    variable lo, hi : natural := 0;
  begin
    lo := 0;
    if id_width > 0 then
      hi := id_width - 1;
      result(hi downto lo) := std_logic_vector(data.id(hi downto lo));
      lo := hi + 1;
    end if;
    hi := lo + axi_resp_sz - 1;
    result(hi downto lo) := data.resp;
    assert hi = result'high severity failure;
    return result;
  end function;

  function to_axi_s2m_b(data : std_logic_vector; id_width : natural) return axi_s2m_b_t is
    constant offset : natural := data'low;
    variable result : axi_s2m_b_t := axi_s2m_b_init;
    variable lo, hi : natural := 0;
  begin
    lo := 0;
    if id_width > 0 then
      hi := id_width - 1;
      result.id(hi downto lo) := unsigned(data(hi + offset downto lo + offset));
      lo := hi + 1;
    end if;
    hi := lo + axi_resp_sz - 1;
    result.resp := data(hi + offset downto lo + offset);
    assert hi + offset = data'high severity failure;
    return result;
  end function;

  function axi_s2m_r_sz(data_width : positive; id_width : natural) return positive is
  begin
    -- Exluded member: valid.
    -- The 1 is "last".
    return data_width + id_width + axi_resp_sz + 1;
  end function;

  function to_slv(data : axi_s2m_r_t; data_width : positive; id_width : natural) return std_logic_vector is
    variable result : std_logic_vector(axi_s2m_r_sz(data_width, id_width) - 1 downto 0);
    variable lo, hi : natural := 0;
  begin
    lo := 0;
    if id_width > 0 then
      hi := id_width - 1;
      result(hi downto lo) := std_logic_vector(data.id(hi downto lo));
      lo := hi + 1;
    end if;
    hi := lo + data_width - 1;
    result(hi downto lo) := data.data(data_width - 1 downto 0);
    lo := hi + 1;
    hi := lo + axi_resp_sz - 1;
    result(hi downto lo) := data.resp;
    lo := hi + 1;
    hi := lo;
    result(hi) := data.last;
    assert hi = result'high severity failure;
    return result;
  end function;

  function to_axi_s2m_r(data : std_logic_vector; data_width : positive; id_width : natural) return axi_s2m_r_t is
    constant offset : natural := data'low;
    variable result : axi_s2m_r_t := axi_s2m_r_init;
    variable lo, hi : natural := 0;
  begin
    lo := 0;
    if id_width > 0 then
      hi := id_width - 1;
      result.id(hi downto lo) := unsigned(data(hi + offset downto lo + offset));
      lo := hi + 1;
    end if;
    hi := lo + data_width - 1;
    result.data(data_width - 1 downto 0) := data(hi + offset downto lo + offset);
    lo := hi + 1;
    hi := lo + axi_resp_sz - 1;
    result.resp := data(hi + offset downto lo + offset);
    lo := hi + 1;
    hi := lo;
    result.last := data(hi + offset);
    assert hi + offset = data'high severity failure;
    return result;
  end function;

  -- Combine responses, with the "worst" response taking priority. OKAY may be considered
  -- an error if an exclusive access was desired, so OKAY takes priority over EXOKAY.
  function combine_response(
    resp1, resp2 : std_logic_vector(axi_resp_sz - 1 downto 0)
  ) return std_logic_vector is
    variable resp : std_logic_vector(axi_resp_sz - 1 downto 0);
  begin
    resp := resp1;

    case resp is
      when axi_resp_exokay =>
        -- All values take priority over EXOKAY
        resp := resp2;

      when axi_resp_okay =>
        -- Errors take priority over OKAY
        if resp2 = axi_resp_slverr then
          resp := axi_resp_slverr;
        end if;
        if resp2 = axi_resp_decerr then
          resp := axi_resp_decerr;
        end if;

      when axi_resp_slverr =>
        -- Only DECERR takes priority over SLVERR
        if resp2 = axi_resp_decerr then
          resp := axi_resp_decerr;
        end if;

      when others =>
        -- DECERR
        resp := axi_resp_decerr;

    end case;

    return resp;
  end function;
end;
