-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the hdl-modules project, a collection of reusable, high-quality,
-- peer-reviewed VHDL building blocks.
-- https://hdl-modules.com
-- https://github.com/hdl-modules/hdl-modules
-- -------------------------------------------------------------------------------------------------
-- Resync a single bit from one clock domain to another, using two ``async_reg`` registers.
--
-- .. figure:: resync_level_transparent.png
--
-- The two registers will be placed in the same slice, in order to maximize metastability recovery,
-- which minimizes mean time between failure (MTBF).
-- This enables proper resynchronization of semi-static "level"-type signals without meta stability
-- on rising/falling edges.
--
-- .. note::
--   This entity has a scoped constraint file that must be used.
--   See the ``scoped_constraints`` folder for the file with the same name.
--
-- .. warning::
--   This entity works only for semi-static "level"-type input signals.
--   This entity can not handle "pulse"-type signals.
--   Pulses can be missed and single-cycle pulse behavior will not work.
--
-- See the corresponding constraint file and
-- `this article <https://www.linkedin.com/pulse/reliable-cdc-constraints-1-lukas-vik-copcf/>`__
-- for information about timing constraints and how this CDC topology is made reliable.
--
-- Deterministic latency
-- _____________________
--
-- If you want a deterministic latency through this resync block, via a ``set_max_delay``
-- constraint, the ``clk_in`` port must be assigned to the clock that drives the input data.
-- If it is not, a simple ``set_false_path`` constraint will
-- be used and the latency can be arbitrary, depending on the placer/router.
--
--
-- Input register
-- ______________
--
-- There is an option to include a register on the input side before the ``async_reg`` flip-flop
-- chain.
-- This option is to prevent sampling of data when the input is in a transient "glitch" state, which
-- can occur if it is driven by a LUT as opposed to a flip-flop. If the input is already driven by
-- a flip-flop, you can safely set the generic to ``false`` in order to save resources.
-- Note that this is a separate issue from meta-stability; they can happen independently of
-- each other.
-- When this option is enabled, the ``clk_in`` port must be driven with the correct clock.
-- -------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

library common;
use common.attribute_pkg.all;


entity resync_level is
  generic (
    -- Enable or disable a register on the input side before the async_reg flip-flip chain.
    -- Must be used if the input can contain glitches. See header for more details.
    -- The 'clk_in' port must be assigned if this generic is set to 'true'.
    enable_input_register : boolean;
    -- Initial value for the output that will be set for a few cycles before the first input
    -- value has propagated.
    default_value : std_ulogic := '0'
  );
  port (
    clk_in : in std_ulogic := 'U';
    data_in : in std_ulogic;
    --# {{}}
    clk_out : in std_ulogic;
    data_out : out std_ulogic := default_value
  );
end entity;

architecture a of resync_level is

  signal data_in_int, data_in_p1, data_out_int : std_ulogic := default_value;

  -- Make sure the input register is not optimized away and that logic is not moved around.
  -- That is, if the register exists via the generic, otherwise it is just a passthrough net.
  attribute dont_touch of data_in_int : signal is "true";

  -- Ensure placement in same slice.
  attribute async_reg of data_in_p1 : signal is "true";
  attribute async_reg of data_out_int : signal is "true";

begin

  data_out <= data_out_int;


  ------------------------------------------------------------------------------
  assign_input : if enable_input_register generate

    ------------------------------------------------------------------------------
    assertions : process
    begin
      -- Assert only once at the beginning of simulation.
      assert clk_in /= 'U' report "Must assign clock when using input register";

      wait;
    end process;


    ------------------------------------------------------------------------------
    input_register : process
    begin
      wait until rising_edge(clk_in);

      data_in_int <= data_in;
    end process;

  else generate

    data_in_int <= data_in;

  end generate;


  ------------------------------------------------------------------------------
  main : process
  begin
    wait until rising_edge(clk_out);

    data_out_int <= data_in_p1;
    data_in_p1 <= data_in_int;
  end process;

end architecture;
