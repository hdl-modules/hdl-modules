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

library trail;
use trail.trail_pkg.all;

use work.register_file_pkg.all;
use work.register_file_netlist_pkg.all;


entity trail_register_file_netlist_build_wrapper is
  port (
    clk : in std_ulogic;
    --
    trail_operation : in trail_operation_t;
    trail_response : out trail_response_t := trail_response_init;
    --
    regs_up : in register_vec_t(0 to 15 - 1);
    regs_down : out register_vec_t(0 to 15 - 1);
    --
    reg_was_read : out std_ulogic_vector(0 to 15 - 1);
    reg_was_written : out std_ulogic_vector(0 to 15 - 1)
  );
end entity;

architecture a of trail_register_file_netlist_build_wrapper is

begin

  ------------------------------------------------------------------------------
  trail_register_file_inst : entity work.trail_register_file
    generic map (
      registers => regs,
      default_values => default_values
    )
    port map (
      clk => clk,
      --
      trail_operation => trail_operation,
      trail_response => trail_response,
      --
      regs_up => regs_up,
      regs_down => regs_down,
      --
      reg_was_read => reg_was_read,
      reg_was_written => reg_was_written
    );

end architecture;
