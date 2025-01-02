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
use work.register_file_netlist_pkg.all;


entity axi_lite_register_file_netlist_build_wrapper is
  port (
    clk : in std_ulogic;
    --
    axi_lite_m2s : in axi_lite_m2s_t;
    axi_lite_s2m : out axi_lite_s2m_t;
    --
    regs_up : in register_vec_t(regs'range);
    regs_down : out register_vec_t(regs'range);
    --
    reg_was_read : out std_ulogic_vector(regs'range);
    reg_was_written : out std_ulogic_vector(regs'range)
  );
end entity;

architecture a of axi_lite_register_file_netlist_build_wrapper is

begin

  ------------------------------------------------------------------------------
  axi_lite_register_file_inst : entity work.axi_lite_register_file
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
