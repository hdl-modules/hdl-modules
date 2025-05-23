-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the hdl-modules project, a collection of reusable, high-quality,
-- peer-reviewed VHDL building blocks.
-- https://hdl-modules.com
-- https://github.com/hdl-modules/hdl-modules
-- -------------------------------------------------------------------------------------------------
-- Wrapper for netlist build, that sets an appropriate generic.
-- -------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

library axi_lite;
use axi_lite.axi_lite_pkg.all;

use work.register_file_pkg.all;


entity axi_lite_register_file_netlist_build_wrapper is
  generic (
    enable_reset : boolean
  );
  port (
    clk : in std_ulogic;
    reset : in std_ulogic;
    --
    axi_lite_m2s : in axi_lite_m2s_t;
    axi_lite_s2m : out axi_lite_s2m_t;
    --
    regs_up : in register_vec_t(0 to 15 - 1);
    regs_down : out register_vec_t(0 to 15 - 1);
    --
    reg_was_read : out std_ulogic_vector(0 to 15 - 1);
    reg_was_written : out std_ulogic_vector(0 to 15 - 1)
  );
end entity;

architecture a of axi_lite_register_file_netlist_build_wrapper is

  -- Sum of utilized_widths: 268
  constant regs : register_definition_vec_t(regs_up'range) := (
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

  signal reset_actual : std_ulogic := '0';

begin

  reset_actual <= reset when enable_reset else '0';


  ------------------------------------------------------------------------------
  axi_lite_register_file_inst : entity work.axi_lite_register_file
    generic map (
      registers => regs,
      default_values => default_values
    )
    port map (
      clk => clk,
      reset => reset_actual,
      --
      axi_lite_m2s => axi_lite_m2s,
      axi_lite_s2m => axi_lite_s2m,
      --
      regs_up => regs_up,
      regs_down => regs_down,
      --
      reg_was_read => reg_was_read,
      reg_was_written => reg_was_written
    );

end architecture;
