-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the hdl-modules project, a collection of reusable, high-quality,
-- peer-reviewed VHDL building blocks.
-- https://hdl-modules.com
-- https://github.com/hdl-modules/hdl-modules
-- -------------------------------------------------------------------------------------------------
-- Register setup for netlist builds.
-- -------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

use work.reg_file_pkg.all;


package reg_file_netlist_pkg is

  constant regs : reg_definition_vec_t(0 to 14) := (
    (idx=>0, reg_type=>r),
    (idx=>1, reg_type=>w),
    (idx=>2, reg_type=>r_w),
    (idx=>3, reg_type=>wpulse),
    (idx=>4, reg_type=>r_wpulse),
    (idx=>5, reg_type=>r),
    (idx=>6, reg_type=>w),
    (idx=>7, reg_type=>r_w),
    (idx=>8, reg_type=>wpulse),
    (idx=>9, reg_type=>r_wpulse),
    (idx=>10, reg_type=>r),
    (idx=>11, reg_type=>w),
    (idx=>12, reg_type=>r_w),
    (idx=>13, reg_type=>wpulse),
    (idx=>14, reg_type=>r_wpulse)
  );

  constant default_values : reg_vec_t(regs'range) := (
    0 => x"dcd3e0e6",
    1 => x"323e4bfd",
    2 => x"7ddd475b",
    3 => x"0c4c3891",
    4 => x"cb40a113",
    5 => x"f8c6f339",
    6 => x"a17f0a63",
    7 => x"333665c6",
    8 => x"136f6857",
    9 => x"9901a7d0",
    10 => x"45974c0b",
    11 => x"067b0394",
    12 => x"c5b5d0fc",
    13 => x"86130210",
    14 => x"ad1f5653"
  );

end package;
