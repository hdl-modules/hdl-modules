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

use work.reg_file_pkg.all;


entity axi_lite_reg_file_netlist_wrapper is
  port (
    clk : in std_ulogic;
    --
    axi_lite_m2s : in axi_lite_m2s_t;
    axi_lite_s2m : out axi_lite_s2m_t;
    --
    regs_up : in reg_vec_t(0 to 15 - 1);
    regs_down : out reg_vec_t(0 to 15 - 1);
    --
    reg_was_read : out std_ulogic_vector(0 to 15 - 1);
    reg_was_written : out std_ulogic_vector(0 to 15 - 1)
  );
end entity;

architecture a of axi_lite_reg_file_netlist_wrapper is

  constant regs : reg_definition_vec_t(regs_up'range) := (
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

begin

  ------------------------------------------------------------------------------
  axi_lite_reg_file_inst : entity work.axi_lite_reg_file
    generic map (
      regs => regs,
      default_values => default_values
    )
    port map (
      clk => clk,
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
