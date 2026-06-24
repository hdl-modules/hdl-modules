-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the hdl-modules project, a collection of reusable, high-quality,
-- peer-reviewed VHDL building blocks.
-- https://hdl-modules.com
-- https://github.com/hdl-modules/hdl-modules
-- -------------------------------------------------------------------------------------------------
-- TODO
-- TODO this file is quite messy honestly. Try to make it nicer. Split to blocks?
-- -------------------------------------------------------------------------------------------------

library ieee;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;

library axi;
use axi.axi_pkg.all;

library common;
use common.addr_pkg.all;
use common.types_pkg.all;

use work.trail_pkg.all;


entity axi_to_trail_vector is
  generic (
    axi_address_width : axi_address_width_t;
    axi_id_width : axi_address_width_t;
    data_width : trail_data_width_t;
    base_addresses : addr_vec_t
  );
  port (
    clk_axi : in std_ulogic;
    --# {{}}
    axi_m2s : in axi_m2s_t;
    axi_s2m : out axi_s2m_t := axi_s2m_init;
    --# {{}}
    trail_operations : out trail_operation_vec_t(base_addresses'range) := (
      others => trail_operation_init
    );
    trail_responses : in trail_response_vec_t(base_addresses'range)
  );
end entity;

architecture a of axi_to_trail_vector is

  -- Note: Very important that we call the same function as in 'trail_splitter.vhd'.
  constant base_addresses_and_mask : addr_and_mask_vec_t := calculate_minimal_mask(base_addresses);
  constant pre_split_address_width : positive := addr_bits_needed(addrs=>base_addresses_and_mask);

  signal trail_operation : trail_operation_t := trail_operation_init;
  signal trail_response : trail_response_t := trail_response_init;

begin

  assert axi_address_width >= pre_split_address_width
    report (
      "AXI address width can not hold the specified base addresses (need at least "
      & integer'image(pre_split_address_width)
      & "bits)."
    )
    severity failure;


  ------------------------------------------------------------------------------
  axi_to_trail_inst : entity work.axi_to_trail
    generic map (
      address_width => pre_split_address_width,
      data_width => data_width,
      id_width => axi_id_width
    )
    port map (
      clk => clk_axi,
      --
      axi_m2s => axi_m2s,
      axi_s2m => axi_s2m,
      --
      trail_operation => trail_operation,
      trail_response => trail_response
    );


  ------------------------------------------------------------------------------
  trail_splitter_inst : entity work.trail_splitter
    generic map (
      data_width => data_width,
      address_width => pre_split_address_width,
      base_addresses => base_addresses
    )
    port map (
      clk => clk_axi,
      --
      input_operation => trail_operation,
      input_response => trail_response,
      --
      result_operations => trail_operations,
      result_responses => trail_responses
    );

end architecture;
