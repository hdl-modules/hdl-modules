-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the hdl-modules project, a collection of reusable, high-quality,
-- peer-reviewed VHDL building blocks.
-- https://hdl-modules.com
-- https://github.com/hdl-modules/hdl-modules
-- -------------------------------------------------------------------------------------------------
-- Types and convenience methods for working with VUnit ``bus_master_t``.
-- Used by some BFMs.
-- -------------------------------------------------------------------------------------------------

library vunit_lib;
use vunit_lib.bus_master_pkg.bus_master_t;


package bfm_bus_master_pkg is

  type bus_master_vec_t is array (integer range <>) of bus_master_t;

end package;
