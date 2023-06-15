-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the hdl_modules project, a collection of reusable, high-quality,
-- peer-reviewed VHDL building blocks.
-- https://hdl-modules.com
-- https://gitlab.com/hdl_modules/hdl_modules
-- -------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

library common;
use common.attribute_pkg.all;


entity resync_reset is
  generic (
    active_level : std_ulogic := '1'
  );
  port (
    reset_in : in std_ulogic;
    --# {{}}
    clk_out : in std_ulogic;
    reset_out : out std_ulogic := not active_level
  );
end entity;

architecture a of resync_reset is

  signal reset_register, reset_register_p1 : std_ulogic := not active_level;

  -- Ensure placement in same slice.
  attribute async_reg of reset_register : signal is "true";
  attribute async_reg of reset_register_p1 : signal is "true";
begin

  ------------------------------------------------------------------------------
  main : process(all)
  begin
    if reset_in = active_level then
      reset_register <= active_level;
      reset_register_p1 <= active_level;

    elsif rising_edge(clk_out) then
      reset_register_p1 <= reset_register;
      reset_register <= not active_level;

    end if;
  end process;

  reset_out <= reset_register_p1;

end architecture;
