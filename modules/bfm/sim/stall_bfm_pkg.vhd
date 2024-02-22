-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the hdl-modules project, a collection of reusable, high-quality,
-- peer-reviewed VHDL building blocks.
-- https://hdl-modules.com
-- https://github.com/hdl-modules/hdl-modules
-- -------------------------------------------------------------------------------------------------
-- Types and methods for creating random stall in a testbench or BFM.
-- -------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

library osvvm;
use osvvm.RandomPkg.RandomPType;


package stall_bfm_pkg is

  -- This is a clone of the 'stall_config_t' from VUnit 'axi_stream_pkg'.
  -- We use this type instead so that we don't have to include the huge 'axi_stream_pkg' in
  -- small testbenches, thereby saving simulation startup time.
  type stall_configuration_t is record
    stall_probability : real range 0.0 to 1.0;
    min_stall_cycles : natural;
    max_stall_cycles : natural;
  end record;
  constant zero_stall_configuration : stall_configuration_t := (
    stall_probability=>0.0, min_stall_cycles=>0, max_stall_cycles=>0
  );

  procedure random_stall(
    stall_config : in stall_configuration_t;
    rnd : inout RandomPType;
    signal clk : in std_ulogic
  );

end package;

package body stall_bfm_pkg is

  procedure random_stall(
    stall_config : in stall_configuration_t;
    rnd : inout RandomPType;
    signal clk : in std_ulogic
  ) is
    variable num_stall_cycles : natural := 0;
  begin
    if rnd.Uniform(0.0, 1.0) < stall_config.stall_probability then
      num_stall_cycles := rnd.FavorSmall(
        stall_config.min_stall_cycles,
        stall_config.max_stall_cycles
      );

      for stall in 1 to num_stall_cycles loop
        wait until rising_edge(clk);
      end loop;
    end if;
  end procedure;

end package body;
