-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the hdl-modules project, a collection of reusable, high-quality,
-- peer-reviewed VHDL building blocks.
-- https://hdl-modules.com
-- https://github.com/hdl-modules/hdl-modules
-- -------------------------------------------------------------------------------------------------
-- Types and convenience methods for working with VUnit ``memory_t``.
-- Used by some BFMs.
-- -------------------------------------------------------------------------------------------------

library vunit_lib;
use vunit_lib.memory_pkg.all;


package memory_bfm_pkg is

  -- Convenience method for getting vector of BFM/VC elements.
  -- When doing e.g.
  --
  --   constant my_memories : memory_vec_t(0 to 1) := (others => new_memory);
  --
  -- works well in some simulators (GHDL), meaning that the function is evaluated once for each
  -- element of the vector. In e.g. Modelsim the function is only evaluated once, and all elements
  -- get the same value. Hence the need for this function.

  type memory_vec_t is array (integer range <>) of memory_t;
  impure function get_new_memories(count : positive) return memory_vec_t;

  type buffer_vec_t is array (integer range <>) of buffer_t;

end package;

package body memory_bfm_pkg is

  impure function get_new_memories(count : positive) return memory_vec_t is
    variable result : memory_vec_t(0 to count - 1) := (others => null_memory);
  begin
    for memory_idx in result'range loop
      result(memory_idx) := new_memory;
    end loop;
    return result;
  end function;

end package body;
