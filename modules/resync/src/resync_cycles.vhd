-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the hdl-modules project, a collection of reusable, high-quality,
-- peer-reviewed VHDL building blocks.
-- https://hdl-modules.com
-- https://github.com/hdl-modules/hdl-modules
-- -------------------------------------------------------------------------------------------------
-- Resynchronizes a bit, so that the output bit is asserted as many clock cycles as the input bit.
--
-- .. note::
--   This entity instantiates :ref:`resync.resync_counter` which has a
--   :ref:`scoped constraint <scoped_constraints>` file that must be used.
--
-- This module counts each ``clk_in`` cycle the input bit is asserted.
-- The counter is resynchronized to ``clk_out``, and used as a reference to know
-- how many ``clk_out`` cycles the output bit should be asserted.
--
-- Note that unlike e.g. :ref:`resync.resync_level`, it is safe to drive the input of this entity
-- with LUTs as well as FFs.
--
--
-- Counter width
-- _____________
--
-- The module may fail when ``clk_out`` is slower than ``clk_in`` and the input is
-- asserted many cycles in a row.
-- An RTL assertion is made to check for this error in simulation.
-- Increasing ``counter_width`` increases the tolerance for this error.
-- -------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library common;
use common.common_pkg.in_simulation;
use common.types_pkg.all;

library math;
use math.math_pkg.all;


entity resync_cycles is
  generic (
    counter_width : positive;
    active_level : std_ulogic := '1'
  );
  port (
    clk_in : in std_ulogic;
    data_in : in std_ulogic;
    --# {{}}
    clk_out : in std_ulogic;
    data_out : out std_ulogic := (not active_level)
  );
end entity;

architecture a of resync_cycles is

  signal counter_in, counter_in_resync, counter_out : u_unsigned(counter_width - 1 downto 0) := (
    others => '0'
  );

begin

  ------------------------------------------------------------------------------
  input : process
  begin
    wait until rising_edge(clk_in);

    if data_in = active_level then
      counter_in <= counter_in + 1;
    end if;
  end process;


  ------------------------------------------------------------------------------
  counter_in_resync_inst : entity work.resync_counter
    generic map (
      width => counter_width
    )
    port map (
      clk_in => clk_in,
      counter_in => counter_in,
      --
      clk_out => clk_out,
      counter_out => counter_in_resync
    );


  ------------------------------------------------------------------------------
  output : process
  begin
    wait until rising_edge(clk_out);

    if counter_out /= counter_in_resync then
      data_out <= active_level;
      counter_out <= counter_out + 1;
    else
      data_out <= not active_level;
    end if;
  end process;


  ------------------------------------------------------------------------------
  assertions_gen : if in_simulation generate
    signal counter_in_p1 : u_unsigned(counter_in'range) := (others => '0');
  begin

    ------------------------------------------------------------------------------
    assertions : process
    begin
      wait until rising_edge(clk_out);

      if counter_in = counter_out then
        assert counter_in_p1 = counter_in
          report "Too dense inputs, outputs will be lost!";
      end if;

      counter_in_p1 <= counter_in;
    end process;

end generate;

end architecture;
