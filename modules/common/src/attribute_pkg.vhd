-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the tsfpga project.
-- https://tsfpga.com
-- https://gitlab.com/tsfpga/tsfpga
-- -------------------------------------------------------------------------------------------------

package attribute_pkg is

  -- Commonly used attributes. Descriptions from UG901 and UG912.

  -- Prevent optimizations where signals are either optimized or absorbed into logic
  -- blocks. Works in the same way as KEEP or KEEP_HIERARCHY attributes; However unlike
  -- KEEP and KEEP_HIERARCHY, DONT_TOUCH is forward-annotated to place and route to
  -- prevent logic optimization.
  --
  -- Use the DONT_TOUCH attribute in place of KEEP or KEEP_HIERARCHY.
  --
  -- Valid values: "true", "false"
  attribute dont_touch : string;

  -- Inform the tool that a register is capable of receiving asynchronous data in the D
  -- input pin relative to the source clock, or that the register is a synchronizing
  -- register within a synchronization chain.
  --
  -- Valid values: "true", "false"
  attribute async_reg : string;

  -- Instructs the Vivado synthesis tool on how to infer memory. Accepted values are:
  -- * block: Instructs the tool to infer RAMB type components.
  -- * distributed: Instructs the tool to infer the LUT RAMs.
  -- * registers: Instructs the tool to infer registers instead of RAMs.
  -- * ultra: Instructs the tool to use the UltraScale+TM URAM primitives.
  attribute ram_style : string;
  type ram_style_t is (
    ram_style_block,
    ram_style_distributed,
    ram_style_registers,
    ram_style_ultra,
    ram_style_auto);
  function to_attribute(ram_style_enum : ram_style_t) return string;

  -- instructs the synthesis tool how to deal with synthesis arithmetic structures. By
  -- default, unless there are timing concerns or threshold limits, synthesis attempts to
  -- infer mults, mult-add, mult-sub, and mult-accumulate type structures into DSP blocks.
  -- Adders, subtracters, and accumulators can go into these blocks also, but by default
  -- are implemented with the logic instead of with DSP blocks.
  --
  -- Valid values: "yes", "no", "logic"
  attribute use_dsp : string;

  -- Indicates if a register should go into the I/O buffer. Place this attribute on the
  -- register that you want in the I/O buffer.
  --
  -- Valid values: "true", "false"
  attribute iob : string;

  -- PULLUP applies a weak logic High on a tri-stateable output or bidirectional port to prevent it
  -- from floating. The PULLUP property guarantees a logic High level to allow tri-stated nets to
  -- avoid floating when not being driven.
  --
  -- Valid values: "true", "yes", "false", "no"
  attribute pullup : string;

  -- PULLDOWN applies a weak logic low level on a tri-stateable output or bidirectional port to
  -- prevent it from floating. The PULLDOWN property guarantees a logic Low level to allow
  -- tri-stated nets to avoid floating when not being driven.
  --
  -- Valid values: "true", "yes", "false", "no"
  attribute pulldown : string;

end package;

package body attribute_pkg is

  function to_attribute(ram_style_enum : ram_style_t) return string is
  begin
    case ram_style_enum is
      when ram_style_block =>
        return "block";
      when ram_style_distributed =>
        return "distributed";
      when ram_style_registers =>
        return "registers";
      when ram_style_ultra =>
        return "ultra";
      when ram_style_auto =>
        return "auto";
      when others =>
        assert false severity failure;
        return "error";
    end case;
  end function;

end package body;
