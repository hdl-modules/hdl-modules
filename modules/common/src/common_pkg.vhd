-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the hdl_modules project.
-- https://hdl-modules.com
-- https://gitlab.com/tsfpga/hdl_modules
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
