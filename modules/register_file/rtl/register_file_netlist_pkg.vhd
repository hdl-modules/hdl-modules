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

use work.register_file_pkg.all;


package register_file_netlist_pkg is

  -- Sum of utilized_widths: 268
  constant regs : register_definition_vec_t(0 to 14) := (
    (index=>0, mode=>r, utilized_width=>24),
    (index=>1, mode=>w, utilized_width=>18),
    (index=>2, mode=>r_w, utilized_width=>17),
    (index=>3, mode=>wpulse, utilized_width=>31),
    (index=>4, mode=>r_wpulse, utilized_width=>22),
    (index=>5, mode=>r, utilized_width=>14),
    (index=>6, mode=>w, utilized_width=>30),
    (index=>7, mode=>r_w, utilized_width=>27),
    (index=>8, mode=>wpulse, utilized_width=>19),
    (index=>9, mode=>r_wpulse, utilized_width=>22),
    (index=>10, mode=>r, utilized_width=>25),
    (index=>11, mode=>w, utilized_width=>19),
    (index=>12, mode=>r_w, utilized_width=>22),
    (index=>13, mode=>wpulse, utilized_width=>26),
    (index=>14, mode=>r_wpulse, utilized_width=>18)
  );

  constant default_values : register_vec_t(regs'range) := (
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
