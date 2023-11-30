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

end package;

package body common_pkg is

  function in_simulation return boolean is
  begin
    -- synthesis translate_off
    return true;
    -- synthesis translate_on

    return false;
  end function;

end package body;
