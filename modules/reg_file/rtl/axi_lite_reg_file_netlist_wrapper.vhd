-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the hdl-modules project, a collection of reusable, high-quality,
-- peer-reviewed VHDL building blocks.
-- https://hdl-modules.com
-- https://github.com/hdl-modules/hdl-modules
-- -------------------------------------------------------------------------------------------------
-- Wrapper for netlist build, that sets an appropriate generic.
--
-- main:
-- {
--   "Total LUTs": 202,
--   "Logic LUTs": 202,
--   "LUTRAMs": 0,
--   "SRLs": 0,
--   "FFs": 447,
--   "RAMB36": 0,
--   "RAMB18": 0,
--   "DSP Blocks": 0
-- }
-- Logic level distribution:
-- +-----------------+-------------+-----+-----+-----+----+
-- | End Point Clock | Requirement |  1  |  2  |  3  |  4 |
-- +-----------------+-------------+-----+-----+-----+----+
-- | (none)          | 0.000ns     | 466 | 102 | 400 | 32 |
-- +-----------------+-------------+-----+-----+-----+----+
--
-- After first, quite shitty optimization:
-- {
--   "Total LUTs": 158,
--   "Logic LUTs": 158,
--   "LUTRAMs": 0,
--   "SRLs": 0,
--   "FFs": 329,
--   "RAMB36": 0,
--   "RAMB18": 0,
--   "DSP Blocks": 0
-- }
-- Logic level distribution:
-- +-----------------+-------------+-----+-----+----+-----+----+
-- | End Point Clock | Requirement |  0  |  1  |  2 |  3  |  4 |
-- +-----------------+-------------+-----+-----+----+-----+----+
-- | (none)          | 0.000ns     | 211 | 332 | 84 | 294 | 17 |
-- +-----------------+-------------+-----+-----+----+-----+----+
--
-- After second optimization:
-- Size of reg_file.axi_lite_reg_file after synthesis:
-- {
--   "Total LUTs": 173,
--   "Logic LUTs": 173,
--   "LUTRAMs": 0,
--   "SRLs": 0,
--   "FFs": 338,
--   "RAMB36": 0,
--   "RAMB18": 0,
--   "DSP Blocks": 0
-- }
-- Logic level distribution:
-- +-----------------+-------------+-----+-----+-----+----+----+
-- | End Point Clock | Requirement |  0  |  1  |  2  |  3 |  4 |
-- +-----------------+-------------+-----+-----+-----+----+----+
-- | (none)          | 0.000ns     | 179 | 332 | 397 | 17 | 17 |
-- +-----------------+-------------+-----+-----+-----+----+----+
--
-- Third optimization saved one LUT.
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

  -- Sum of widths: 268
  constant regs : reg_definition_vec_t(regs_up'range) := (
    (idx=>0, reg_type=>r, width=>24),
    (idx=>1, reg_type=>w, width=>18),
    (idx=>2, reg_type=>r_w, width=>17),
    (idx=>3, reg_type=>wpulse, width=>31),
    (idx=>4, reg_type=>r_wpulse, width=>22),
    (idx=>5, reg_type=>r, width=>14),
    (idx=>6, reg_type=>w, width=>30),
    (idx=>7, reg_type=>r_w, width=>27),
    (idx=>8, reg_type=>wpulse, width=>19),
    (idx=>9, reg_type=>r_wpulse, width=>22),
    (idx=>10, reg_type=>r, width=>25),
    (idx=>11, reg_type=>w, width=>19),
    (idx=>12, reg_type=>r_w, width=>22),
    (idx=>13, reg_type=>wpulse, width=>26),
    (idx=>14, reg_type=>r_wpulse, width=>18)
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
