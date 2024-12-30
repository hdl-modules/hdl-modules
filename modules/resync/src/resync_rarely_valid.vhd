-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the hdl-modules project, a collection of reusable, high-quality,
-- peer-reviewed VHDL building blocks.
-- https://hdl-modules.com
-- https://github.com/hdl-modules/hdl-modules
-- -------------------------------------------------------------------------------------------------
-- Simple CDC where a ``data`` word, qualified with a ``valid`` signal, is resynchronized from
-- one clock domain to another.
-- The ``input_valid`` must be pulsed for one clock cycle when the ``input_data`` is valid,
-- which will result in one ``result_valid`` pulse once data has propagated.
--
-- This CDC features no feedback and no backpressure, and will fail if ``input`` words arrive
-- too close together.
-- It is up to the user to make sure that this does not happen.
-- There needs to be at least 1 ``input`` clock cycle and 3 ``result`` clock cycles between
-- between each word.
--
-- .. warning::
--   This CDC topology is inherently unsafe and should be used with a lot of caution.
--   If ``input`` words arrive too close together, there will be corrupted and/or metastable
--   ``result`` words.
--   There is no monitoring/detection/reporting mechanism for such events.
--
--   Use this entity only if
--
--   1. you are absolutely sure, due to the design of upstream logic, that ``input`` words
--      will never arrive "too close", or
--   2. you have some status feedback mechanism outside of this entity.
--
-- The name of this CDC topology comes from the fact that ``valid`` may only arrive quite rarely.
-- And also, due to its inherent unsafe nature, it is rarely a valid choice to use this CDC.
--
-- This CDC features no ``ready`` signals for backpressure.
-- See e.g. :ref:`resync.resync_twophase_handshake` or :ref:`fifo.asynchronous_fifo`
-- instead if backpressure is needed, or if the flow of data is unknown.
--
-- .. warning::
--   This entity is in active development.
--   Using it is NOT recommended at this point.
--
-- .. note::
--   This entity has a scoped constraint file
--   `resync_rarely_valid.tcl <https://github.com/hdl-modules/hdl-modules/blob/main/modules/resync/scoped_constraints/resync_rarely_valid.tcl>`__
--   that must be used for proper operation.
--   See :ref:`here <scoped_constraints>` for instructions.
--
-- .. note::
--   TODO:
--
--   * Add constraints.
--   * Run post synthesis simulation.
--   * Test on hardware.
-- -------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

library common;
use common.attribute_pkg.all;


entity resync_rarely_valid is
  generic (
    data_width : positive
  );
  port (
    input_clk : in std_ulogic;
    input_valid : in std_ulogic;
    input_data : in std_ulogic_vector(data_width - 1 downto 0);
    --# {{}}
    result_clk : in std_ulogic;
    result_valid : out std_ulogic := '0';
    result_data : out std_ulogic_vector(data_width - 1 downto 0) := (others => '0')
  );
end entity;

architecture a of resync_rarely_valid is

  signal input_data_sampled, result_data_int : std_ulogic_vector(input_data'range) := (
    others => '0'
  );

  -- We apply constraints to these two signals, and they are crucial for the function of the CDC.
  -- Do not allow the tool to optimize these or move any logic.
  attribute dont_touch of input_data_sampled : signal is "true";
  attribute dont_touch of result_data_int : signal is "true";

  signal input_level : std_ulogic := '0';
  signal output_level_m1, output_level, output_level_p1 : std_ulogic := '0';

  -- This feeds an async_reg, and it is absolutely crucial that it is driven by a FF.
  -- So place attribute so that build tool does not optimize/modify anything.
  attribute dont_touch of input_level : signal is "true";

  -- Ensure FFs are not optimized/modified, and placed in the same slice to minimize MTBF.
  attribute async_reg of output_level_m1 : signal is "true";
  attribute async_reg of output_level : signal is "true";

begin

  ------------------------------------------------------------------------------
  handle_input : process
  begin
    wait until rising_edge(input_clk);

    if input_valid then
      input_data_sampled <= input_data;
      input_level <= not input_level;
    end if;
  end process;


  ------------------------------------------------------------------------------
  handle_output : process
  begin
    wait until rising_edge(result_clk);

    -- Default assignment.
    result_valid <= '0';

    if output_level /= output_level_p1 then
      result_valid <= '1';

      -- Parallel CDC path.
      result_data_int <= input_data_sampled;
    end if;

    output_level_p1 <= output_level;

    -- CDC path into async_reg chain.
    output_level <= output_level_m1;
    output_level_m1 <= input_level;
  end process;

  result_data <= result_data_int;

end architecture;
