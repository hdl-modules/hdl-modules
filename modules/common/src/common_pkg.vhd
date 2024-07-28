-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the hdl-modules project, a collection of reusable, high-quality,
-- peer-reviewed VHDL building blocks.
-- https://hdl-modules.com
-- https://github.com/hdl-modules/hdl-modules
-- -------------------------------------------------------------------------------------------------
-- Package with common features that do not fit in anywhere else, and are not significant enough
-- to warrant their own package.
-- -------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;


package common_pkg is

  function in_simulation return boolean;

  -- The ternary conditional operator, or if-then-else.
  -- Equivalent to
  --   condition ? value_if_true : value_if_false
  -- in C-like languages.
  -- Function can be overloaded for other value data types.
  function if_then_else(
    condition : boolean; value_if_true : string; value_if_false : string
  ) return string;

end package;

package body common_pkg is

  function in_simulation return boolean is
  begin
    -- synthesis translate_off
    return true;
    -- synthesis translate_on

    return false;
  end function;

  function if_then_else(
    condition : boolean; value_if_true : string; value_if_false : string
  ) return string is
  begin
    if condition then
      return value_if_true;
    end if;

    return value_if_false;
  end function;

end package body;
