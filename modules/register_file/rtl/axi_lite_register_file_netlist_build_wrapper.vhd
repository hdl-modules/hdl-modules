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
    regs_up : in register_vec_t(0 to 18 - 1);
    regs_down : out register_vec_t(0 to 18 - 1);
    --
    reg_was_read : out std_ulogic_vector(0 to 18 - 1);
    reg_was_written : out std_ulogic_vector(0 to 18 - 1)
  );
end entity;

architecture a of axi_lite_register_file_netlist_build_wrapper is

  -- Sum of utilized_widths: 340
  constant regs : register_definition_vec_t(regs_up'range) := (
    (index=>0, mode=>r, utilized_width=>24),
    (index=>1, mode=>w, utilized_width=>20),
    (index=>2, mode=>r_w, utilized_width=>16),
    (index=>3, mode=>wpulse, utilized_width=>32),
    (index=>4, mode=>r_wpulse, utilized_width=>24),
    (index=>5, mode=>wmasked, utilized_width=>12),
    (index=>6, mode=>r, utilized_width=>16),
    (index=>7, mode=>w, utilized_width=>28),
    (index=>8, mode=>r_w, utilized_width=>24),
    (index=>9, mode=>wpulse, utilized_width=>20),
    (index=>10, mode=>r_wpulse, utilized_width=>24),
    (index=>11, mode=>wmasked, utilized_width=>8),
    (index=>12, mode=>r, utilized_width=>24),
    (index=>13, mode=>w, utilized_width=>20),
    (index=>14, mode=>r_w, utilized_width=>24),
    (index=>15, mode=>wpulse, utilized_width=>28),
    (index=>16, mode=>r_wpulse, utilized_width=>16),
    (index=>17, mode=>wmasked, utilized_width=>16)
  );

  constant default_values : register_vec_t(regs'range) := (
    0 => x"00d3e0e6",
    1 => x"000e4bfd",
    2 => x"0000475b",
    3 => x"8c4c3891",
    4 => x"00f0a113",
    5 => x"00000af8",
    6 => x"0000f339",
    7 => x"017f0a63",
    8 => x"003665c6",
    9 => x"000f6857",
    10 => x"0001a7d0",
    11 => x"000000df",
    12 => x"00974c0b",
    13 => x"000b0394",
    14 => x"00b5d0fc",
    15 => x"06130210",
    16 => x"00005653",
    17 => x"00005653"
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
