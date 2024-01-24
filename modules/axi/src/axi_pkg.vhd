-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the hdl-modules project, a collection of reusable, high-quality,
-- peer-reviewed VHDL building blocks.
-- https://hdl-modules.com
-- https://github.com/hdl-modules/hdl-modules
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

  -- Data field (RDATA or WDATA).
  -- The width value below is a max value, implementation should only take into regard the bits
  -- that are actually used.
  constant axi_data_sz : positive := 128;

  ------------------------------------------------------------------------------
  -- A (Address Read and Address Write) channels
  ------------------------------------------------------------------------------

  -- ID field (ARID, AWID, BID as well as RID if using AXI3)
  -- The width value below is a max value, implementation should only take into regard the bits
  -- that are actually used.
  constant axi_id_sz : positive := 24;

  -- Address field (ARADDR or AWADDR).
  -- The width value below is a max value, implementation should only take into regard the bits
  -- that are actually used.
  constant axi_a_addr_sz : positive := 64;

  -- Length field (ARLEN or AWLEN)
  -- Number of beats (data transfers) in this burst = AxLEN + 1
  constant axi_a_len_sz : positive := 8;
  subtype axi_a_len_t is u_unsigned(axi_a_len_sz - 1 downto 0);

  constant axi_max_burst_length_beats : positive := 256;
  constant axi3_max_burst_length_beats : positive := 16;

  function get_max_burst_length_beats(enable_axi3 : boolean) return positive;

  -- Find the number of AxLEN bits that have to be taken into account, given the provided
  -- max burst length.
  function get_a_len_width(
    max_burst_length_beats : positive range 1 to axi_max_burst_length_beats
  ) return positive;

  -- Convert a given burst length to the corresponding AxLEN value.
  function to_len(
    burst_length_beats : positive range 1 to axi_max_burst_length_beats
  ) return axi_a_len_t;

  -- Size field (ARSIZE or AWSIZE)
  -- Bytes per beat (data transfer) in this burst = 2^AxSIZE
  constant axi_a_size_sz : positive := 3;
  subtype axi_a_size_t is u_unsigned(axi_a_size_sz - 1 downto 0);

  function to_size(data_width_bits : positive range 8 to axi_data_sz) return axi_a_size_t;

  -- Burst field (ARBURST or AWBURST)
  constant axi_a_burst_sz : positive := 2;
  subtype axi_a_burst_t is std_ulogic_vector(axi_a_burst_sz - 1 downto 0);

  constant axi_a_burst_fixed : axi_a_burst_t := "00";
  constant axi_a_burst_incr : axi_a_burst_t := "01";
  constant axi_a_burst_wrap : axi_a_burst_t := "10";

  -- Lock field (ARLOCK or AWLOCK)
  -- Note that this is two bits in AXI3. We use AXI4 as the default.
  constant axi_a_lock_sz : positive := 1;
  subtype axi_a_lock_t is std_ulogic_vector(axi_a_lock_sz - 1 downto 0);

  constant axi_a_lock_normal : axi_a_lock_t := "0";
  constant axi_a_lock_exclusive : axi_a_lock_t := "1";

  subtype axi3_a_lock_t is std_ulogic_vector(2 - 1 downto 0);
  constant axi3_a_lock_normal : axi3_a_lock_t := "00";
  constant axi3_a_lock_exclusive : axi3_a_lock_t := "01";
  constant axi3_a_lock_locked : axi3_a_lock_t := "10";

  -- Cache field (ARCACHE or AWCACHE)
  constant axi_a_cache_sz : positive := 4;
  subtype axi_a_cache_t is std_ulogic_vector(axi_a_cache_sz - 1 downto 0);

  constant axi_a_cache_device_non_bufferable : axi_a_cache_t := "0000";
  constant axi_a_cache_device_bufferable : axi_a_cache_t := "0001";
  constant axi_a_cache_normal_non_cacheable_non_bufferable : axi_a_cache_t := "0010";
  constant axi_a_cache_normal_non_cacheable_bufferable : axi_a_cache_t := "0011";
  constant axi_ar_cache_write_through_no_allocate : axi_a_cache_t := "1010";
  constant axi_aw_cache_write_through_no_allocate : axi_a_cache_t := "0110";
  constant axi_a_cache_write_through_read_allocate : axi_a_cache_t := "0110";
  constant axi_a_cache_write_through_write_allocate : axi_a_cache_t := "1010";
  constant axi_a_cache_write_through_read_and_write_allocate : axi_a_cache_t := "1110";
  constant axi_ar_cache_write_back_no_allocate : axi_a_cache_t := "1011";
  constant axi_aw_cache_write_back_no_allocate : axi_a_cache_t := "0111";
  constant axi_a_cache_write_back_read_allocate : axi_a_cache_t := "0111";
  constant axi_a_cache_write_back_write_allocate : axi_a_cache_t := "1011";
  constant axi_a_cache_write_back_read_and_write_allocate : axi_a_cache_t := "1111";

  -- Protocol field (ARPROT or AWPROT)
  constant axi_a_prot_sz : positive := 3;
  subtype axi_a_prot_t is std_ulogic_vector(axi_a_prot_sz - 1 downto 0);

  constant axi_a_prot_privileged : axi_a_prot_t := "001";
  constant axi_a_prot_unprivileged : axi_a_prot_t := "000";
  constant axi_a_prot_secure : axi_a_prot_t := "000";
  constant axi_a_prot_nonsecure : axi_a_prot_t := "010";
  constant axi_a_prot_data : axi_a_prot_t := "000";
  constant axi_a_prot_instruction : axi_a_prot_t := "100";

  -- Region field (ARREGION or AWREGION)
  constant axi_a_region_sz : positive := 4;
  subtype axi_a_region_t is std_ulogic_vector(axi_a_region_sz - 1 downto 0);

  -- Record for the AR/AW signals in the master-to-slave direction.
  type axi_m2s_a_t is record
    valid : std_ulogic;
    id : u_unsigned(axi_id_sz - 1 downto 0);
    addr : u_unsigned(axi_a_addr_sz - 1 downto 0);
    len : axi_a_len_t;
    size : axi_a_size_t;
    burst : axi_a_burst_t;
    -- Excluded members: lock, cache, prot, region.
    -- These are typically not changed on a transfer-to-transfer basis.
  end record;

  constant axi_m2s_a_init : axi_m2s_a_t := (
    valid => '0',
    id => (others => '0'),
    addr => (others => '0'),
    len => (others => '-'),
    size => (others => '-'),
    burst => (others => '-')
  );
  function axi_m2s_a_sz(
    id_width : natural range 0 to axi_id_sz; addr_width : positive range 1 to axi_a_addr_sz
  ) return positive;
  type axi_m2s_a_vec_t is array (integer range <>) of axi_m2s_a_t;

  function to_slv(
    data : axi_m2s_a_t;
    id_width : natural range 0 to axi_id_sz;
    addr_width : positive range 1 to axi_a_addr_sz
  ) return std_ulogic_vector;
  function to_axi_m2s_a(
    data : std_ulogic_vector;
    id_width : natural range 0 to axi_id_sz;
    addr_width : positive range 1 to axi_a_addr_sz
  ) return axi_m2s_a_t;

  -- Record for the AR/AW signals in the slave-to-master direction.
  type axi_s2m_a_t is record
    ready : std_ulogic;
  end record;

  constant axi_s2m_a_init : axi_s2m_a_t := (ready => '0');
  type axi_s2m_a_vec_t is array (integer range <>) of axi_s2m_a_t;


  ------------------------------------------------------------------------------
  -- W (Write Data) channels
  ------------------------------------------------------------------------------

  -- Check that a provided data width is valid to be used with AXI.
  -- Return 'true' if everything is okay, otherwise 'false'.
  function sanity_check_axi_data_width(data_width : integer) return boolean;

  -- Write data strobe field (WSTRB).
  -- The width value below is a max value, implementation should only take into regard the bits
  -- that are actually used.
  constant axi_w_strb_sz : positive := axi_data_sz / 8;

  function to_strb(data_width : positive range 8 to axi_data_sz) return std_ulogic_vector;
  function axi_w_strb_width(data_width : positive range 8 to axi_data_sz) return positive;

  -- Record for the W signals in the master-to-slave direction.
  type axi_m2s_w_t is record
    valid : std_ulogic;
    data : std_ulogic_vector(axi_data_sz - 1 downto 0);
    strb : std_ulogic_vector(axi_w_strb_sz - 1 downto 0);
    last : std_ulogic;
    -- Only available in AXI3. We assume that AXI4 is used most of the time, hence id_width is
    -- defaulted to zero in the functions below.
    id : u_unsigned(axi_id_sz - 1 downto 0);
  end record;

  constant axi_m2s_w_init : axi_m2s_w_t := (
    valid => '0',
    data => (others => '-'),
    strb => (others => '0'),
    last => '-',
    id => (others => '-')
  );
  function axi_m2s_w_sz(
    data_width : positive range 8 to axi_data_sz; id_width : natural range 0 to axi_id_sz := 0
  ) return positive;
  type axi_m2s_w_vec_t is array (integer range <>) of axi_m2s_w_t;

  function to_slv(
    data : axi_m2s_w_t;
    data_width : positive range 8 to axi_data_sz;
    id_width : natural range 0 to axi_id_sz := 0
  ) return std_ulogic_vector;
  function to_axi_m2s_w(
    data : std_ulogic_vector;
    data_width : positive range 8 to axi_data_sz;
    id_width : natural range 0 to axi_id_sz := 0
  ) return axi_m2s_w_t;

  -- Record for the W signals in the slave-to-master direction.
  type axi_s2m_w_t is record
    ready : std_ulogic;
  end record;
  type axi_s2m_w_vec_t is array (integer range <>) of axi_s2m_w_t;

  constant axi_s2m_w_init : axi_s2m_w_t := (ready => '0');


  ------------------------------------------------------------------------------
  -- B (Write Response) channels
  ------------------------------------------------------------------------------

  -- Record for the W signals in the master-to-slave direction.
  type axi_m2s_b_t is record
    ready : std_ulogic;
  end record;

  constant axi_m2s_b_init : axi_m2s_b_t := (ready => '0');

  -- Response field (RRESP or BRESP).
  constant axi_resp_sz : positive := 2;
  subtype axi_resp_t is std_ulogic_vector(axi_resp_sz - 1 downto 0);

  -- Okay.
  constant axi_resp_okay : axi_resp_t := "00";
  -- Exclusive access okay.
  constant axi_resp_exokay : axi_resp_t := "01";
  -- Slave error. Slave wishes to return error.
  constant axi_resp_slverr : axi_resp_t := "10";
  -- Decode error. There is no slave at transaction address.
  constant axi_resp_decerr : axi_resp_t := "11";

  -- Record for the B signals in the slave-to-master direction.
  type axi_s2m_b_t is record
    valid : std_ulogic;
    id : u_unsigned(axi_id_sz - 1 downto 0);
    resp : axi_resp_t;
  end record;

  constant axi_s2m_b_init : axi_s2m_b_t := (
    valid => '0',
    id => (others => '0'),
    resp => (others => '-')
  );
  function axi_s2m_b_sz(id_width : natural range 0 to axi_id_sz) return positive;
  type axi_s2m_b_vec_t is array (integer range <>) of axi_s2m_b_t;

  function to_slv(
    data : axi_s2m_b_t; id_width : natural range 0 to axi_id_sz
  ) return std_ulogic_vector;
  function to_axi_s2m_b(
    data : std_ulogic_vector; id_width : natural range 0 to axi_id_sz
  ) return axi_s2m_b_t;


  ------------------------------------------------------------------------------
  -- R (Read Data) channels
  ------------------------------------------------------------------------------

  -- Record for the R signals in the master-to-slave direction.
  type axi_m2s_r_t is record
    ready : std_ulogic;
  end record;
  type axi_m2s_r_vec_t is array (integer range <>) of axi_m2s_r_t;

  constant axi_m2s_r_init : axi_m2s_r_t := (ready => '0');

  -- Record for the R signals in the slave-to-master direction.
  type axi_s2m_r_t is record
    valid : std_ulogic;
    id : u_unsigned(axi_id_sz - 1 downto 0);
    data : std_ulogic_vector(axi_data_sz - 1 downto 0);
    resp : axi_resp_t;
    last : std_ulogic;
  end record;

  constant axi_s2m_r_init : axi_s2m_r_t := (
    valid => '0',
    id => (others => '0'),
    data => (others => '-'),
    resp => (others => '-'),
    last => '-'
  );
  function axi_s2m_r_sz(
    data_width : positive range 8 to axi_data_sz; id_width : natural range 0 to axi_id_sz
  )  return positive;
  type axi_s2m_r_vec_t is array (integer range <>) of axi_s2m_r_t;

  function to_slv(
    data : axi_s2m_r_t;
    data_width : positive range 8 to axi_data_sz;
    id_width : natural range 0 to axi_id_sz
  ) return std_ulogic_vector;
  function to_axi_s2m_r(
    data : std_ulogic_vector;
    data_width : positive range 8 to axi_data_sz;
    id_width : natural range 0 to axi_id_sz
  ) return axi_s2m_r_t;


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

  constant axi_write_m2s_init : axi_write_m2s_t := (
    aw => axi_m2s_a_init,
    w => axi_m2s_w_init,
    b => axi_m2s_b_init
  );

  type axi_write_s2m_t is record
    aw : axi_s2m_a_t;
    w : axi_s2m_w_t;
    b : axi_s2m_b_t;
  end record;
  type axi_write_s2m_vec_t is array (integer range <>) of axi_write_s2m_t;

  constant axi_write_s2m_init : axi_write_s2m_t := (
    aw => axi_s2m_a_init,
    w => axi_s2m_w_init,
    b => axi_s2m_b_init
  );

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

  function combine_response(resp1, resp2 : axi_resp_t) return axi_resp_t;

end;

package body axi_pkg is

  ------------------------------------------------------------------------------
  function get_max_burst_length_beats(enable_axi3 : boolean) return positive is
  begin
    if enable_axi3 then
      return axi3_max_burst_length_beats;
    end if;

    return axi_max_burst_length_beats;
  end function;

  function get_a_len_width(
    max_burst_length_beats : positive range 1 to axi_max_burst_length_beats
  ) return positive is
    constant max_a_len : positive := max_burst_length_beats - 1;
    constant result : positive range 1 to axi_a_len_sz := num_bits_needed(max_a_len);
  begin
    assert (
        max_burst_length_beats = axi_max_burst_length_beats
        or max_burst_length_beats = axi3_max_burst_length_beats
      )
      report "Invalid max burst length"
      severity failure;

    return result;
  end function;

  function to_len(
    burst_length_beats : positive range 1 to axi_max_burst_length_beats
  ) return axi_a_len_t is
    -- burst_length_beats is number of transfers
    constant result : axi_a_len_t := to_unsigned(burst_length_beats - 1, axi_a_len_sz);
  begin
    return result;
  end function;

  function to_size(data_width_bits : positive range 8 to axi_data_sz) return axi_a_size_t is
    constant result : axi_a_size_t := to_unsigned(log2(data_width_bits / 8), axi_a_size_sz);
  begin
    assert sanity_check_axi_data_width(data_width_bits)
      report "Invalid data width, see printout above"
      severity failure;

    return result;
  end function;

  function axi_m2s_a_sz(
    id_width : natural range 0 to axi_id_sz; addr_width : positive range 1 to axi_a_addr_sz
  ) return positive is
  begin
    -- Excluded member: valid
    return id_width + addr_width + axi_a_len_sz + axi_a_size_sz + axi_a_burst_sz;
  end function;

  function to_slv(
    data : axi_m2s_a_t;
    id_width : natural range 0 to axi_id_sz;
    addr_width : positive range 1 to axi_a_addr_sz
  ) return std_ulogic_vector is
    variable result : std_ulogic_vector(axi_m2s_a_sz(id_width, addr_width) - 1 downto 0);
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

    assert hi = result'high;

    return result;
  end function;

  function to_axi_m2s_a(
    data : std_ulogic_vector;
    id_width : natural range 0 to axi_id_sz;
    addr_width : positive range 1 to axi_a_addr_sz
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

    assert hi + offset = data'high;

    return result;
  end function;
  ------------------------------------------------------------------------------

  ------------------------------------------------------------------------------
  function sanity_check_axi_data_width(data_width : integer) return boolean is
    constant message : string := ". Got data_width=" & integer'image(data_width) & ".";
  begin
    if data_width <= 0 then
      report "AXI data width must be greater than zero" & message;
      return false;
    end if;

    if data_width > axi_data_sz then
      report (
        "AXI data width must not be greater than max value "
        & integer'image(axi_data_sz)
        & message
      );
      return false;
    end if;

    if data_width mod 8 /= 0 then
      report "AXI data width must be a whole number of bytes" & message;
      return false;
    end if;

    if not is_power_of_two(data_width / 8) then
      report "AXI data byte width must be a power of two" & message;
      return false;
    end if;

    return true;
  end function;

  function to_strb(data_width : positive range 8 to axi_data_sz) return std_ulogic_vector is
    variable result : std_ulogic_vector(axi_w_strb_sz - 1 downto 0) := (others => '0');
  begin
    assert sanity_check_axi_data_width(data_width)
      report "Invalid data width, see printout above"
      severity failure;

    result(data_width / 8 - 1 downto 0) := (others => '1');

    return result;
  end function;

  function axi_w_strb_width(data_width : positive range 8 to axi_data_sz) return positive is
  begin
    assert sanity_check_axi_data_width(data_width)
      report "Invalid data width, see printout above"
      severity failure;

    return data_width / 8;
  end function;

  function axi_m2s_w_sz(
    data_width : positive range 8 to axi_data_sz; id_width : natural range 0 to axi_id_sz := 0
  ) return positive is
  begin
    assert sanity_check_axi_data_width(data_width)
      report "Invalid data width, see printout above"
      severity failure;

    -- Excluded member: valid.
    -- The 1 is for 'last'.
    return data_width + axi_w_strb_width(data_width) + 1 + id_width;
  end function;

  function to_slv(
    data : axi_m2s_w_t;
    data_width : positive range 8 to axi_data_sz;
    id_width : natural range 0 to axi_id_sz := 0
  ) return std_ulogic_vector is
    constant result_width : positive := axi_m2s_w_sz(data_width=>data_width, id_width=>id_width);
    variable result : std_ulogic_vector(result_width - 1 downto 0) := (others => '0');
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

    assert hi = result'high;

    return result;
  end function;

  function to_axi_m2s_w(
    data : std_ulogic_vector;
    data_width : positive range 8 to axi_data_sz;
    id_width : natural range 0 to axi_id_sz := 0
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

    assert hi + offset = data'high;

    return result;
  end function;
  ------------------------------------------------------------------------------

  ------------------------------------------------------------------------------
  function axi_s2m_b_sz(id_width : natural range 0 to axi_id_sz) return positive is
  begin
    -- Excluded member: valid
    return id_width + axi_resp_sz;
  end function;

  function to_slv(
    data : axi_s2m_b_t; id_width : natural range 0 to axi_id_sz
  ) return std_ulogic_vector is
    variable result : std_ulogic_vector(axi_s2m_b_sz(id_width) - 1 downto 0);
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

    assert hi = result'high;

    return result;
  end function;

  function to_axi_s2m_b(
    data : std_ulogic_vector; id_width : natural range 0 to axi_id_sz
  ) return axi_s2m_b_t is
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

    assert hi + offset = data'high;

    return result;
  end function;
  ------------------------------------------------------------------------------

  ------------------------------------------------------------------------------
  function axi_s2m_r_sz(
    data_width : positive range 8 to axi_data_sz; id_width : natural range 0 to axi_id_sz
  ) return positive is
  begin
    assert sanity_check_axi_data_width(data_width)
      report "Invalid data width, see printout above"
      severity failure;

    -- Excluded member: valid.
    -- The 1 is for 'last'.
    return data_width + id_width + axi_resp_sz + 1;
  end function;

  function to_slv(
    data : axi_s2m_r_t;
    data_width : positive range 8 to axi_data_sz;
    id_width : natural range 0 to axi_id_sz)
  return std_ulogic_vector is
    variable result : std_ulogic_vector(axi_s2m_r_sz(data_width, id_width) - 1 downto 0);
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

    assert hi = result'high;

    return result;
  end function;

  function to_axi_s2m_r(
    data : std_ulogic_vector;
    data_width : positive range 8 to axi_data_sz;
    id_width : natural range 0 to axi_id_sz
  ) return axi_s2m_r_t is
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

    assert hi + offset = data'high;

    return result;
  end function;
  ------------------------------------------------------------------------------

  ------------------------------------------------------------------------------
  -- Combine responses, with the "worst" response taking priority. OKAY may be considered
  -- an error if an exclusive access was desired, so OKAY takes priority over EXOKAY.
  function combine_response(resp1, resp2 : axi_resp_t) return axi_resp_t is
    variable resp : axi_resp_t;
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
  ------------------------------------------------------------------------------

end;
