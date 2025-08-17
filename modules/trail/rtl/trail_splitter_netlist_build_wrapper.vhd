-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the hdl-modules project, a collection of reusable, high-quality,
-- peer-reviewed VHDL building blocks.
-- https://hdl-modules.com
-- https://github.com/hdl-modules/hdl-modules
-- -------------------------------------------------------------------------------------------------
-- Wrapper with no complex generics, to be used for netlist builds to keep track of
-- synthesized size.
-- -------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

library common;
use common.addr_pkg.all;

use work.trail_pkg.all;


entity trail_splitter_netlist_build_wrapper is
  generic (
    address_width : trail_address_width_t;
    data_width : trail_data_width_t
  );
  port (
    clk : in std_ulogic;
    --# {{}}
    input_operation : in trail_operation_t;
    input_response : out trail_response_t;
    --# {{}}
    result_operations : out trail_operation_vec_t(0 to 18) := (others => trail_operation_init);
    result_responses : in trail_response_vec_t(0 to 18)
  );
end entity;

architecture a of trail_splitter_netlist_build_wrapper is

  constant base_addresses : addr_vec_t(result_operations'range) := (
    x"0000_0000",
    x"0000_1000",
    x"0000_2000",
    x"0000_3000",
    x"0000_4000",
    x"0000_5000",
    x"0000_6000",
    x"0000_7000",
    x"0000_8000",
    x"0000_9000",
    x"0000_A000",
    x"0000_B000",
    x"0000_C000",
    x"0000_D000",
    x"0000_E000",
    x"0000_F000",
    x"0001_0000",
    x"0002_0000",
    x"0002_0100"
  );

begin

  ------------------------------------------------------------------------------
  trail_splitter_inst : entity work.trail_splitter
    generic map (
      data_width => data_width,
      address_width => address_width,
      base_addresses => base_addresses
    )
    port map (
      clk => clk,
      --
      input_operation => input_operation,
      input_response => input_response,
      --
      result_operations => result_operations,
      result_responses => result_responses
    );

end architecture;
