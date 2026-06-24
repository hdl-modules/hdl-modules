-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the hdl-modules project, a collection of reusable, high-quality,
-- peer-reviewed VHDL building blocks.
-- https://hdl-modules.com
-- https://github.com/hdl-modules/hdl-modules
-- -------------------------------------------------------------------------------------------------
-- Pipelining of a TRAIL response, to be used when build timing issues require a decrease in
-- critical path and/or fanout.
-- Use the ``pipeline_*`` generics to enable pipelining of the fields that are causing
-- timing issues.
--
-- Pipelining of a TRAIL response is incredibly resource-efficient due
-- to :ref:`rule 2 and 4 <trail_rules>`.
-- We only have to pipeline ``enable`` along with any payload fields that have timing issues.
-- All other fields can be left as a pass-through.
-- This can save a lot of resources compared to a full pipeline, since it is commonly only a
-- specific field that is causing issues.
--
-- Note that if ``pipeline_*`` is activated for any payload, pipelining of the ``enable``
-- signal is also activated internally.
-- Regardless of the ``pipeline_enable`` generic.
--
--
-- Resource utilization
-- ____________________
--
-- This entity consumes one FF for each bit in the fields that are pipelined.
-- See the :ref:`resource utilization <trail.trail_pipeline.resource_utilization>`
-- of :ref:`trail.trail_pipeline` for some actual numbers.
--
--
-- Examples
-- ________
--
-- The example below shows first a typical ``input`` TRAIL response.
--
-- Secondly it shows what happens when only ``pipeline_enable`` is activated.
-- I.e. how you would parameterize if you have timing issues with the ``enable`` signal.
--
-- Lastly it shows what happens when ``pipeline_read_data`` (and possibly ``pipeline_enable``)
-- is activated.
-- I.e. how you would parameterize if you have timing issues with the ``read_data`` signal.
--
-- .. wavedrom::
--
--   {
--     "signal": [
--       { "name": "clk",          "wave": "p...." },
--       {},
--       { "name": "enable",       "wave": "010.." },
--       { "name": "status",       "wave": "x6..." },
--       { "name": "read_data",    "wave": "x6..." },
--       {},
--       { "name": "enable",       "wave": "0.10." },
--       { "name": "status",       "wave": "x6..." },
--       { "name": "read_data",    "wave": "x6..." },
--       {},
--       { "name": "enable",       "wave": "0.10." },
--       { "name": "status",       "wave": "x6..." },
--       { "name": "read_data",    "wave": "xx7.." },
--     ],
--     "foot": {
--       "text": "TRAIL response pipelining."
--     },
--   }
-- -------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

use work.trail_pkg.all;


entity trail_pipeline_response is
  generic (
    data_width : trail_data_width_t;
    pipeline_enable : boolean := false;
    pipeline_status : boolean := false;
    pipeline_read_data : boolean := false
  );
  port (
    clk : in std_ulogic;
    --# {{}}
    input_response : in trail_response_t;
    result_response : out trail_response_t := trail_response_init
  );
end entity;

architecture a of trail_pipeline_response is

  constant should_pipeline_enable : boolean := (
    pipeline_enable or pipeline_status or pipeline_read_data
  );

  signal enable_p1 : std_ulogic := '0';
  signal status_p1 : trail_response_status_t := trail_response_status_okay;
  signal read_data_p1 : std_ulogic_vector(data_width - 1 downto 0) := (others => '0');

begin

  ------------------------------------------------------------------------------
  pipeline : process
  begin
    wait until rising_edge(clk);

    if should_pipeline_enable then
      enable_p1 <= input_response.enable;
    end if;

    if pipeline_status then
      status_p1 <= input_response.status;
    end if;

    if pipeline_read_data then
      read_data_p1 <= input_response.read_data(read_data_p1'range);
    end if;
  end process;


  ------------------------------------------------------------------------------
  assign : process(all)
  begin
    result_response <= input_response;

    if should_pipeline_enable then
      result_response.enable <= enable_p1;
    end if;

    if pipeline_status then
      result_response.status <= status_p1;
    end if;

    if pipeline_read_data then
      result_response.read_data(read_data_p1'range) <= read_data_p1;
    end if;
  end process;

end architecture;
