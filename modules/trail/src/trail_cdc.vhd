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

library resync;

use work.trail_pkg.all;


entity trail_cdc is
  generic (
    address_width : trail_address_width_t;
    data_width : trail_data_width_t;
    -- In devices that support using LUTs as RAM, a lot of resources can be saved by
    -- enabling this option.
    use_lutram : boolean;
    -- If 'use_lutram' is enabled, optionally improve critical path and/or fanout of LUTRAM output
    -- by sampling it in a register.
    use_lutram_output_register : boolean := false
  );
  port (
    input_clk : in std_ulogic;
    input_operation : in trail_operation_t;
    input_response : out trail_response_t := trail_response_init;
    --# {{}}
    result_clk : in std_ulogic;
    result_operation : out trail_operation_t := trail_operation_init;
    result_response : in trail_response_t
  );
end entity;

architecture a of trail_cdc is

begin

  ------------------------------------------------------------------------------
  trail_cdc_operation_inst : entity work.trail_cdc_operation
    generic map (
      address_width => address_width,
      data_width => data_width,
      use_lutram => use_lutram,
      use_lutram_output_register => use_lutram_output_register
    )
    port map (
      input_clk => input_clk,
      input_operation => input_operation,
      --
      result_clk => result_clk,
      result_operation => result_operation
    );


  ------------------------------------------------------------------------------
  trail_cdc_response_inst : entity work.trail_cdc_response
    generic map (
      data_width => data_width,
      use_lutram => use_lutram,
      use_lutram_output_register => use_lutram_output_register
    )
    port map (
      input_clk => result_clk,
      input_response => result_response,
      --
      result_clk => input_clk,
      result_response => input_response
    );

end architecture;
