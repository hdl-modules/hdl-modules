-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the hdl-modules project, a collection of reusable, high-quality,
-- peer-reviewed VHDL building blocks.
-- https://hdl-modules.com
-- https://github.com/hdl-modules/hdl-modules
-- -------------------------------------------------------------------------------------------------
-- Types and convenience methods for working with VUnit ``queue_t``.
-- Used by some BFMs.
-- -------------------------------------------------------------------------------------------------

library vunit_lib;
use vunit_lib.queue_pkg.all;


package queue_bfm_pkg is

  -- Convenience method for getting vector of BFM/VC elements.
  -- When doing e.g.
  --
  --   constant my_queues : queue_vec_t(0 to 1) := (others => new_queue);
  --
  -- works well in some simulators (GHDL), meaning that the function is evaluated once for each
  -- element of the vector. In e.g. Modelsim the function is only evaluated once, and all elements
  -- get the same value. Hence the need for this function.

  impure function get_new_queues(count : positive) return queue_vec_t;

end package;

package body queue_bfm_pkg is

  impure function get_new_queues(count : positive) return queue_vec_t is
    variable result : queue_vec_t(0 to count - 1) := (others => null_queue);
  begin
    for queue_idx in result'range loop
      result(queue_idx) := new_queue;
    end loop;
    return result;
  end function;

end package body;
