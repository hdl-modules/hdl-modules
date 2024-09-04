-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the hdl-modules project, a collection of reusable, high-quality,
-- peer-reviewed VHDL building blocks.
-- https://hdl-modules.com
-- https://github.com/hdl-modules/hdl-modules
-- -------------------------------------------------------------------------------------------------
-- Free-running two-phase handshaking CDC for resynchronizing a data vector from one clock domain
-- to another.
-- Unlike e.g. :ref:`resync.resync_slv_level`, this entity contains a mechanism that guarantees
-- bit coherency.
--
-- .. figure:: resync_slv_level_coherent_transparent.png
--
-- A level signal is rotated around between input and output side, with three registers in each
-- direction. The level toggles for each roundtrip, and data is sampled on each side upon a level
-- transition.
-- This ensures that data is sampled on the output side only when we know that the sampled
-- input data is stable. Conversely, input data is only sampled when we know that data has been
-- sampled on the output in a stable fashion.
--
-- .. note::
--   This entity is free-running, meaning that it will sample and resync input data back-to-back.
--   See :ref:`resync.resync_slv_handshake` for a version that AXI-Stream-like handshaking on the
--   input and result sides.
--
-- This entity is suitable for resynchronizing e.g. a control/status register or a counter value,
-- which are scenarios where bit coherency is crucial.
-- It will not be able to handle pulses in the input data, it is very likely that pulses will
-- be missed.
-- Hence the "level" part in the name.
--
-- .. note::
--   This entity has a scoped constraint file
--   `resync_slv_level_coherent.tcl <https://github.com/hdl-modules/hdl-modules/blob/main/modules/resync/scoped_constraints/resync_slv_level_coherent.tcl>`__
--   that must be used for proper operation.
--   See :ref:`here <scoped_constraints>` for instructions.
--
-- Note that unlike e.g. :ref:`resync.resync_level`, it is safe to drive the input of this entity
-- with LUTs as well as FFs.
--
--
-- Latency and resource utilization
-- ________________________________
--
-- The latency is less than or equal to
--
--   3 * period(clk_in) + 3 * period(clk_out)
--
-- This is also the sampling period of the signal. As such this resync is not suitable for signals
-- that change quickly. It is instead typically used for e.g. slow moving counters and status
-- words, or other data where the different bits are correlated.
--
-- The LUT utilization is always 3. The FF utilization increases linearly at a rate
-- of ``2 * width``.
--
-- Compared to :ref:`resync.resync_counter` this entity has lower LUT and FF usage in all scenarios.
-- It does however have higher latency.
--
-- Another way of achieving the same functionality is to use a shallow :ref:`fifo.asynchronous_fifo`
-- with ``write_valid`` and ``read_ready`` statically set to ``1``.
-- The FIFO will however have higher LUT usage.
-- FF usage is higher for the FIFO, up to around width 32 where this entity will consume more FF.
-- Latency is about the same for both.
-- -------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

library common;
use common.attribute_pkg.all;


entity resync_slv_level_coherent is
  generic (
    width : positive;
    -- Initial value for the output that will be set for a few cycles before the first input
    -- value has propagated.
    default_value : std_ulogic_vector(width - 1 downto 0) := (others => '0')
  );
  port (
    clk_in : in std_ulogic;
    data_in : in std_ulogic_vector(default_value'range);
    --# {{}}
    clk_out : in std_ulogic;
    data_out : out std_ulogic_vector(default_value'range) := default_value
  );
end entity;

architecture a of resync_slv_level_coherent is

  signal data_in_sampled, data_out_int : std_ulogic_vector(data_in'range) := default_value;

  -- We apply constraints to these two signals, and they are crucial for the function of the CDC.
  -- Do not allow the tool to optimize these or move any logic.
  attribute dont_touch of data_in_sampled : signal is "true";
  attribute dont_touch of data_out_int : signal is "true";

  signal input_level_m1, input_level, input_level_not_p1 : std_ulogic := '0';
  signal output_level_m1, output_level, output_level_p1 : std_ulogic := '0';

  -- These two feed async_reg chains, and it is absolutely crucial that they are driven by FFs.
  -- So place attribute on them so that build tool does not optimize/modify anything.
  attribute dont_touch of input_level_not_p1 : signal is "true";
  attribute dont_touch of output_level_p1 : signal is "true";

  -- Ensure FFs are not optimized/modified, and placed in the same slice to minimize MTBF.
  attribute async_reg of input_level_m1 : signal is "true";
  attribute async_reg of input_level : signal is "true";
  attribute async_reg of output_level_m1 : signal is "true";
  attribute async_reg of output_level : signal is "true";

begin

  ------------------------------------------------------------------------------
  handle_input : process
  begin
    wait until rising_edge(clk_in);

    if input_level = input_level_not_p1 then
      data_in_sampled <= data_in;
    end if;

    input_level_not_p1 <= not input_level;

    -- CDC path into async_reg chain.
    input_level <= input_level_m1;
    input_level_m1 <= output_level_p1;
  end process;


  ------------------------------------------------------------------------------
  handle_output : process
  begin
    wait until rising_edge(clk_out);

    if output_level /= output_level_p1 then
      -- Parallel CDC path.
      data_out_int <= data_in_sampled;
    end if;

    output_level_p1 <= output_level;

    -- CDC path into async_reg chain.
    output_level <= output_level_m1;
    output_level_m1 <= input_level_not_p1;
  end process;

  data_out <= data_out_int;

end architecture;
