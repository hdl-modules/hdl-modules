-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the hdl-modules project, a collection of reusable, high-quality,
-- peer-reviewed VHDL building blocks.
-- https://hdl-modules.com
-- https://github.com/hdl-modules/hdl-modules
-- -------------------------------------------------------------------------------------------------
-- TODO
--
--
-- Resource utilization
-- ____________________
--
-- This entity consumes two FFs for each payload bit, and a little overhead for ``enable``.
-- See the :ref:`resource utilization <trail.trail_cdc.resource_utilization>`
-- of :ref:`trail.trail_cdc` for some actual numbers.
-- -------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library resync;

use work.trail_pkg.all;


entity trail_cdc_response is
  generic (
    data_width : trail_data_width_t;
    -- In devices that support using LUTs as RAM, a lot of resources can be saved by
    -- enabling this option.
    use_lutram : boolean;
    -- If 'use_lutram' is enabled, optionally improve critical path and/or fanout of LUTRAM output
    -- by sampling it in a register.
    use_lutram_output_register : boolean
  );
  port (
    input_clk : in std_ulogic;
    input_response : in trail_response_t;
    --# {{}}
    result_clk : in std_ulogic;
    result_response : out trail_response_t := trail_response_init
  );
end entity;

architecture a of trail_cdc_response is

  signal input_valid, result_valid : std_ulogic := '0';
  signal input_slv, result_slv : std_ulogic_vector(
    trail_response_width(data_width=>data_width) - 1 downto 0
  ) := (others => '0');

begin

  ------------------------------------------------------------------------------
  use_lutram_gen : if use_lutram generate

    ------------------------------------------------------------------------------
    resync_rarely_valid_lutram_inst : entity resync.resync_rarely_valid_lutram
      generic map (
        data_width => input_slv'length,
        enable_output_register => use_lutram_output_register
      )
      port map (
        input_clk => input_clk,
        input_valid => input_valid,
        input_data => input_slv,
        --
        result_clk => result_clk,
        result_valid => result_valid,
        result_data => result_slv
      );

  ------------------------------------------------------------------------------
  else generate

    ------------------------------------------------------------------------------
    resync_rarely_valid_inst : entity resync.resync_rarely_valid
      generic map (
        data_width => input_slv'length
      )
      port map (
        input_clk => input_clk,
        input_valid => input_valid,
        input_data => input_slv,
        --
        result_clk => result_clk,
        result_valid => result_valid,
        result_data => result_slv
      );

  end generate;


  input_valid <= input_response.enable;
  input_slv <= to_slv(data=>input_response, data_width=>data_width);

  result_response <= to_trail_response(
    data=>result_slv, enable=>result_valid, data_width=>data_width
  );

end architecture;
