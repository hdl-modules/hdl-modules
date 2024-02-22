-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the hdl-modules project, a collection of reusable, high-quality,
-- peer-reviewed VHDL building blocks.
-- https://hdl-modules.com
-- https://github.com/hdl-modules/hdl-modules
-- -------------------------------------------------------------------------------------------------
-- Types and functions for the AXI BFMs.
-- -------------------------------------------------------------------------------------------------

library ieee;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;

use work.stall_bfm_pkg.stall_configuration_t;


package axi_bfm_pkg is

  type axi_master_bfm_job_t is record
    address : natural;
    length_bytes : positive;
    id : natural;
  end record;
  constant axi_master_bfm_job_init : axi_master_bfm_job_t := (length_bytes => 1, others => 0);

  constant axi_master_bfm_job_size : positive := 3 * 32;

  function to_slv(job : axi_master_bfm_job_t) return std_ulogic_vector;
  function to_axi_bfm_job(
    data : std_ulogic_vector(axi_master_bfm_job_size - 1 downto 0)
  ) return axi_master_bfm_job_t;

  -- Stall in a way where it is probable that W data arrives a long while before AWVALID.
  constant default_address_stall_config : stall_configuration_t := (
    stall_probability => 0.3,
    min_stall_cycles  => 1,
    max_stall_cycles  => 30
  );

  -- Stall just a little bit, to make sure handshaking works properly on all the channels.
  constant default_data_stall_config : stall_configuration_t := (
    stall_probability => 0.3,
    min_stall_cycles  => 1,
    max_stall_cycles  => 4
  );

  -- From a desired length, return the highest possible length that does not cross a 4k barrier
  function get_byte_length_that_does_not_cross_4k(
    address : natural;
    length_bytes : positive
  ) return positive;

end package;

package body axi_bfm_pkg is

  function to_slv(job : axi_master_bfm_job_t) return std_ulogic_vector is
    variable result : std_ulogic_vector(axi_master_bfm_job_size - 1 downto 0) := (others => '0');
  begin
    result(31 downto 0) := std_logic_vector(to_unsigned(job.address, 32));
    result(63 downto 32) := std_logic_vector(to_unsigned(job.length_bytes, 32));
    result(95 downto 64) := std_logic_vector(to_unsigned(job.id, 32));
    return result;
  end function;

  function to_axi_bfm_job(
    data : std_ulogic_vector(axi_master_bfm_job_size - 1 downto 0)
  ) return axi_master_bfm_job_t is
    variable result : axi_master_bfm_job_t := axi_master_bfm_job_init;
  begin
    result.address := to_integer(unsigned(data(31 downto 0)));
    result.length_bytes := to_integer(unsigned(data(63 downto 32)));
    result.id := to_integer(unsigned(data(95 downto 64)));
    return result;
  end function;

  function get_byte_length_that_does_not_cross_4k(
    address : natural;
    length_bytes : positive
  ) return positive is
    constant current_page : natural := address / 4096;
    constant next_4k_limit : positive := 4096 * (current_page + 1);
    constant bytes_until_next_4k : positive := next_4k_limit - address;
  begin
    return minimum(length_bytes, bytes_until_next_4k);
  end function;

end package body;
