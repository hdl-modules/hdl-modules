-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the hdl-modules project, a collection of reusable, high-quality,
-- peer-reviewed VHDL building blocks.
-- https://hdl-modules.com
-- https://github.com/hdl-modules/hdl-modules
-- -------------------------------------------------------------------------------------------------
-- Pipelining of a TRAIL operation, to be used when build timing issues require a decrease in
-- critical path and/or fanout.
-- Use the ``pipeline_*`` generics to enable pipelining of the fields that are causing
-- timing issues.
--
-- Pipelining of a TRAIL operation is incredibly resource-efficient due
-- to :ref:`rule 2 and 3 <trail_rules>`.
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
-- It saves a few FFs if the address is pipelined by skipping the unaligned lowest address
-- bits which are assumed to be zero.
--
-- See the :ref:`resource utilization <trail.trail_pipeline.resource_utilization>`
-- of :ref:`trail.trail_pipeline` for some actual numbers.
--
--
-- Examples
-- ________
--
-- The example below shows first a typical ``input`` TRAIL operation.
--
-- Secondly it shows what happens when only ``pipeline_enable`` is activated.
-- I.e. how you would parameterize if you have downstream timing issues with the ``enable`` signal.
--
-- Lastly it shows what happens when ``pipeline_address`` (and possibly ``pipeline_enable``)
-- is activated.
-- I.e. how you would parameterize if you have downstream timing issues with the ``address`` signal.
--
-- .. wavedrom::
--
--   {
--     "signal": [
--       { "name": "clk",          "wave": "p...." },
--       {},
--       { "name": "enable",       "wave": "010.." },
--       { "name": "address",      "wave": "x6..." },
--       { "name": "write_enable", "wave": "x6..." },
--       { "name": "write_data",   "wave": "x6..." },
--       {},
--       { "name": "enable",       "wave": "0.10." },
--       { "name": "address",      "wave": "x6..." },
--       { "name": "write_enable", "wave": "x6..." },
--       { "name": "write_data",   "wave": "x6..." },
--       {},
--       { "name": "enable",       "wave": "0.10." },
--       { "name": "address",      "wave": "xx7.." },
--       { "name": "write_enable", "wave": "x6..." },
--       { "name": "write_data",   "wave": "x6..." },
--     ],
--     "foot": {
--       "text": "TRAIL operation pipelining."
--     },
--   }
-- -------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.trail_pkg.all;


entity trail_pipeline_operation is
  generic (
    address_width : trail_address_width_t;
    data_width : trail_data_width_t;
    pipeline_enable : boolean := false;
    pipeline_address : boolean := false;
    pipeline_write_enable : boolean := false;
    pipeline_write_data : boolean := false
  );
  port (
    clk : in std_ulogic;
    --# {{}}
    input_operation : in trail_operation_t;
    result_operation : out trail_operation_t := trail_operation_init
  );
end entity;

architecture a of trail_pipeline_operation is

  constant num_unaligned_address_bits : natural := trail_num_unaligned_address_bits(
    data_width=>data_width
  );

  constant should_pipeline_enable : boolean := (
    pipeline_enable or pipeline_address or pipeline_write_enable or pipeline_write_data
  );

  signal enable_p1 : std_ulogic := '0';
  signal address_p1 : u_unsigned(address_width - 1 downto num_unaligned_address_bits) := (
    others => '0'
  );
  signal write_enable_p1 : std_ulogic := '0';
  signal write_data_p1 : std_ulogic_vector(data_width - 1 downto 0) := (others => '0');

begin

  ------------------------------------------------------------------------------
  pipeline : process
  begin
    wait until rising_edge(clk);

    if should_pipeline_enable then
      enable_p1 <= input_operation.enable;
    end if;

    if pipeline_address then
      address_p1 <= input_operation.address(address_p1'range);
    end if;

    if pipeline_write_enable then
      write_enable_p1 <= input_operation.write_enable;
    end if;

    if pipeline_write_data then
      write_data_p1 <= input_operation.write_data(write_data_p1'range);
    end if;
  end process;


  ------------------------------------------------------------------------------
  assign : process(all)
  begin
    result_operation <= input_operation;

    if should_pipeline_enable then
      result_operation.enable <= enable_p1;
    end if;

    if pipeline_address then
      result_operation.address(address_p1'range) <= address_p1;
    end if;

    if pipeline_write_enable then
      result_operation.write_enable <= write_enable_p1;
    end if;

    if pipeline_write_data then
      result_operation.write_data(write_data_p1'range) <= write_data_p1;
    end if;
  end process;

end architecture;
