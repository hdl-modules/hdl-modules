-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the tsfpga project.
-- https://tsfpga.com
-- https://gitlab.com/tsfpga/tsfpga
-- -------------------------------------------------------------------------------------------------
-- Wrapper, for netlist build and formal flow, that sets an appropriate generic.
-- -------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

library axi;
use axi.axi_lite_pkg.all;

-- TODO there is some problem in our formal flow related to the work library.
-- Doing simply "use work.reg_file_pkg.all;" does not work here. The issue seems to be
-- isolated to the top level however, since axi_lite_reg_file.vhd uses "work" completely fine.
--
-- Appending "--work=reg_file" in the sby_writer.py ghdl elaborate call did not immediately solve
-- the issue.
library reg_file;
use reg_file.reg_file_pkg.all;


entity axi_lite_reg_file_wrapper is
  port (
    clk : in std_logic;
    --
    axi_lite_m2s : in axi_lite_m2s_t;
    axi_lite_s2m : out axi_lite_s2m_t;
    --
    regs_up : in reg_vec_t(0 to 15 - 1);
    regs_down : out reg_vec_t(0 to 15 - 1);
    --
    reg_was_read : out std_logic_vector(0 to 15 - 1);
    reg_was_written : out std_logic_vector(0 to 15 - 1)
  );
end entity;

architecture a of axi_lite_reg_file_wrapper is

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

begin

  axi_lite_reg_file_inst : entity reg_file.axi_lite_reg_file
    generic map (
      regs => regs
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
