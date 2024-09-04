-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the hdl-modules project, a collection of reusable, high-quality,
-- peer-reviewed VHDL building blocks.
-- https://hdl-modules.com
-- https://github.com/hdl-modules/hdl-modules
-- -------------------------------------------------------------------------------------------------
-- A robust way of resyncing a pulse signal from one clock domain to another.
--
-- .. figure:: resync_pulse_transparent.png
--
-- .. note::
--   This entity has a scoped constraint file
--   `resync_pulse.tcl <https://github.com/hdl-modules/hdl-modules/blob/main/modules/resync/scoped_constraints/resync_pulse.tcl>`__
--   that must be used for proper operation.
--   See :ref:`here <scoped_constraints>` for instructions.
--
-- Note that unlike e.g. :ref:`resync.resync_level`, it is safe to drive the input of this entity
-- with a LUT as well as an FF.
--
-- See the
-- `this article <https://www.linkedin.com/pulse/reliable-cdc-constraints-3-pulses-lukas-vik-31tif/>`__
-- for detailed information about timing constraints and how this CDC topology can be used reliably.
--
--
-- Pulse overload
-- ______________
--
-- The barebone pulse CDC is vulnerable to pulse overload, meaning that if multiple pulses arrive
-- close together, some or all of them can be missed.
-- This can happen if the distance between input pulses is not significantly greater than two
-- output clock domain cycles.
--
-- To re-formulate this problem, the design is safe and can not miss pulses if
--
-- 1. The output clock is significantly more than two times faster than the input clock, or
--
-- 2. The user knows from the application that input pulses can not happen often.
--
-- Otherwise it is unsafe, and pulses can be missed.
-- Using the feedback level mechanism, as described below, can mitigate this problem.
--
--
-- Feedback level
-- ______________
--
-- This entity features an optional feedback level and input gating which mitigates the pulse
-- overload problem.
-- When this is enabled and the pulse overload scenario happens, the feedback will guarantee that
-- at least one pulse arrives on the output.
--
-- Note that pulses can still be missed, meaning fewer pulses might arrive on the output than
-- were received on the input.
-- But, once again, the mechanism guarantees that at least one pulse arrives.
--
-- Hence, this CDC in this configuration is not suitable for applications where the exact pulse
-- count is important.
-- It is more suitable for situations where the user wants to know wether or not something has
-- occurred, and not the exact number of times it occurred.
--
-- The feedback level and input gating mechanisms are enabled by the
-- ``enable_feedback`` generic.
-- Note that it has default value ``true``, since that is considered the most robust behavior.
-- -------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

library common;
use common.attribute_pkg.all;
use common.common_pkg.if_then_else;
use common.types_pkg.all;


entity resync_pulse is
  generic (
    -- Set the active pulse level.
    -- When 'pulse_in' assumes this value, it is counted as an active pulse.
    active_level : std_ulogic := '1';
    -- Enable feedback level mechanism to avoid pulse overload.
    -- See file header for details.
    enable_feedback : boolean := true;
    -- Make an RTL assertion when pulse overload occurs.
    assert_false_on_pulse_overload : boolean := true
  );
  port (
    clk_in : in std_ulogic;
    pulse_in : in std_ulogic;
    -- Sticky signal that will be '1' if input pulse overload has ever occurred.
    -- This monitor mechanism works only if 'enable_feedback' is true.
    overload_has_occurred : out std_ulogic := '0';
    --# {{}}
    clk_out : in std_ulogic;
    pulse_out : out std_ulogic := not active_level
  );
end entity;

architecture a of resync_pulse is

  signal level_in : std_ulogic := '0';
  signal level_out_m1, level_out, level_out_p1 : std_ulogic := '0';
  signal level_out_feedback_m1, level_out_feedback : std_ulogic := '0';

  -- These two feed async_reg chains, and it is absolutely crucial that they are driven by FFs.
  -- So place attribute on them so that build tool does not optimize/modify anything.
  attribute dont_touch of level_in : signal is "true";
  attribute dont_touch of level_out : signal is "true";

  -- Ensure FFs are not optimized/modified, and placed in the same slice to minimize MTBF.
  attribute async_reg of level_out_m1 : signal is "true";
  attribute async_reg of level_out : signal is "true";

  -- If feedback is disabled but the attribute is applied as "true", the two registers will present
  -- but unused in the synthesized design.
  -- Hence set "true" only if feedback is enabled.
  constant async_reg_feedback : string := if_then_else(enable_feedback, "true", "false");
  attribute async_reg of level_out_feedback_m1 : signal is async_reg_feedback;
  attribute async_reg of level_out_feedback : signal is async_reg_feedback;

begin

  ------------------------------------------------------------------------------
  input : process
  begin
    wait until rising_edge(clk_in);

    -- Toggle input level.
    if pulse_in = active_level then
      if level_in = level_out_feedback or not enable_feedback then
        -- Pulse to level.
        level_in <= not level_in;
      end if;
    end if;

    -- Pulse overload handling.
    if pulse_in = active_level then
      if enable_feedback then
        if level_in /= level_out_feedback then
          -- Set sticky.
          overload_has_occurred <= '1';

          if assert_false_on_pulse_overload then
            assert false report "Pulse overload";
          end if;
        end if;

      else
        -- No feedback level.
        -- Check for pulse overload only in simulation.
        if level_in /= level_out and assert_false_on_pulse_overload then
          assert false report "Pulse overload";
        end if;
      end if;
    end if;

    if enable_feedback then
      -- CDC path into async_reg chain.
      level_out_feedback <= level_out_feedback_m1;
      level_out_feedback_m1 <= level_out;
    end if;
  end process;


  ------------------------------------------------------------------------------
  level_out_register : process
  begin
    wait until rising_edge(clk_out);

    level_out_p1 <= level_out;

    -- CDC path into async_reg chain.
    level_out <= level_out_m1;
    level_out_m1 <= level_in;
  end process;

  -- Level to pulse.
  pulse_out <= (not active_level) when level_out = level_out_p1 else active_level;

end architecture;
