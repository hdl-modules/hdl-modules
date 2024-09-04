-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the hdl-modules project, a collection of reusable, high-quality,
-- peer-reviewed VHDL building blocks.
-- https://hdl-modules.com
-- https://github.com/hdl-modules/hdl-modules
-- -------------------------------------------------------------------------------------------------
-- Two-phase handshaking CDC for resynchronizing a data vector from one clock domain to another.
-- Features an AXI-Stream-like handshaking interface on both the ``input`` and ``result`` side.
--
-- .. figure:: resync_slv_handshake_transparent.png
--
-- In many ways this entity is a superset of :ref:`resync.resync_slv_level_coherent`, so see that
-- for some more insight.
-- But this one features ``ready``/``valid`` handshaking, which enables backpressure but increases
-- :ref:`resync.resync_slv_handshake.resource_utilization` slightly.
--
-- .. note::
--   This entity has a scoped constraint file
--   `resync_slv_handshake.tcl <https://github.com/hdl-modules/hdl-modules/blob/main/modules/resync/scoped_constraints/resync_slv_handshake.tcl>`__
--   that must be used for proper operation.
--   See :ref:`here <scoped_constraints>` for instructions.
--
-- Note that unlike e.g. :ref:`resync.resync_level`, it is safe to drive the input of this entity
-- with LUTs as well as FFs.
--
--
-- Latency
-- _______
--
-- The latency from ``input`` to ``result`` is less than or equal to
--
--   period(input_clk) + 3 * period(result_clk),
--
--
-- Throughput
-- __________
--
-- The sampling period (inverse of throughput) of is roughly equal to
--
--   3 * period(input_clk) + 3 * period(result_clk).
--
-- If ``result_ready`` is stalling, new ``input`` can be sampled before the previous
-- ``result`` is sent out, which aids throughput in this scenario.
-- -------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

library common;
use common.attribute_pkg.all;


entity resync_slv_handshake is
  generic (
    data_width : positive
  );
  port (
    input_clk : in std_ulogic;
    input_ready : out std_ulogic := '0';
    input_valid : in std_ulogic;
    input_data : in std_ulogic_vector(data_width - 1 downto 0);
    --# {{}}
    result_clk : in std_ulogic;
    result_ready : in std_ulogic;
    result_valid : out std_ulogic := '0';
    result_data : out std_ulogic_vector(data_width - 1 downto 0) := (others => '0')
  );
end entity;

architecture a of resync_slv_handshake is

  signal input_data_sampled, result_data_int : std_ulogic_vector(input_data'range) := (
    others => '0'
  );

  -- We apply constraints to these two signals, and they are crucial for the function of the CDC.
  -- Do not allow the tool to optimize these or move any logic.
  attribute dont_touch of input_data_sampled : signal is "true";
  attribute dont_touch of result_data_int : signal is "true";

  signal input_level_p1 : std_ulogic := '0';
  signal result_level_m1, result_level, result_level_handshake : std_ulogic := '0';
  -- Different default value than the others, to trigger the first 'input_ready' event.
  signal input_level_m1, input_level, result_level_feedback : std_ulogic := '1';

  -- These two feed async_reg chains, and it is absolutely crucial that they are driven by FFs.
  -- So place attribute on them so that build tool does not optimize/modify anything.
  attribute dont_touch of input_level_p1 : signal is "true";
  attribute dont_touch of result_level_feedback : signal is "true";

  -- Ensure FFs are not optimized/modified, and placed in the same slice to minimize MTBF.
  attribute async_reg of input_level_m1 : signal is "true";
  attribute async_reg of input_level : signal is "true";
  attribute async_reg of result_level_m1 : signal is "true";
  attribute async_reg of result_level : signal is "true";

begin

  ------------------------------------------------------------------------------
  handle_input : process
  begin
    wait until rising_edge(input_clk);

    if input_ready then
      -- Sample regardless of 'valid' or not. Is handled below.
      input_data_sampled <= input_data;
    end if;

    if input_valid then
      -- If we have 'input_ready', this assignment will
      -- 1. lower 'input_ready'.
      -- 2. toggle the level to the 'result' side, indicating that a new data word is available.
      --
      -- If 'input_ready' is low, this assignment does nothing.
      input_level_p1 <= input_level;
    end if;

    -- CDC path into async_reg chain.
    input_level <= input_level_m1;
    input_level_m1 <= result_level_feedback;
  end process;

  input_ready <= input_level xor input_level_p1;


  ------------------------------------------------------------------------------
  handle_result : process
  begin
    wait until rising_edge(result_clk);

    -- A new result level means that there is new data sampled on the 'input' side.
    -- Sample it and send it out, but NOT if we still have an older data word that has not
    -- been popped yet.
    -- This backpressure mechanism adds a FF and few LUTs but roughly doubles the throughput in
    -- some scenarios.
    if (result_level xor result_level_handshake) and not result_valid then
      result_valid <= '1';

      -- Parallel CDC path.
      result_data_int <= input_data_sampled;

      -- We have now sampled the data on the 'result' side, update the feedback level so
      -- the the 'input' side can sample a new value there.
      -- Regardless of whether the 'result' data word has been sent out or not.
      result_level_feedback <= not result_level_feedback;
    end if;

    if result_ready and result_valid then
      result_valid <= '0';

      -- Toggle the level so that valid is not raised again until we have new 'input' data.
      result_level_handshake <= not result_level_handshake;
    end if;

    -- CDC path into async_reg chain.
    result_level <= result_level_m1;
    result_level_m1 <= input_level_p1;
  end process;

  result_data <= result_data_int;

end architecture;
