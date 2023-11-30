-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the hdl-modules project, a collection of reusable, high-quality,
-- peer-reviewed VHDL building blocks.
-- https://hdl-modules.com
-- https://github.com/hdl-modules/hdl-modules
-- -------------------------------------------------------------------------------------------------
-- Package with functions for the hard FIFO wrappers.
-- -------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


package hard_fifo_pkg is

  type fifo_primitive_t is (primitive_fifo36e2);

  function get_fifo_width(target_width : positive) return positive;

  function get_fifo_depth(target_width : positive) return positive;

end package;

package body hard_fifo_pkg is

  function get_fifo_width(target_width : positive) return positive is
  begin
    -- Per UG573 table 1-21 and UG974 page 98
    if target_width <= 4 then
      return 4;
    elsif target_width <= 9 then
      return 9;
    elsif target_width <= 18 then
      return 18;
    elsif target_width <= 36 then
      return 36;
    elsif target_width <= 72 then
      return 72;
    end if;

    assert false
      report "Could not handle this width: " & integer'image(target_width)
      severity failure;
    return 36;
  end function;

  function get_fifo_depth(target_width : positive) return positive is
    constant fifo_width : positive := get_fifo_width(target_width=>target_width);
  begin
    -- Per UG573 table 1-21.

    if fifo_width = 4 then
      -- Special case: 1024 * 36 / 4.5
      return 8192;
    end if;

    return 1024 * 36 / fifo_width;
  end function;

end package body;
