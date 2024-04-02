-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the hdl-modules project, a collection of reusable, high-quality,
-- peer-reviewed VHDL building blocks.
-- https://hdl-modules.com
-- https://github.com/hdl-modules/hdl-modules
-- -------------------------------------------------------------------------------------------------
-- A robust way of resyncing a pulse signal from one clock domain to another.
--
-- .. note::
--   This entity instantiates :ref:`resync.resync_level` which has a scoped constraint file
--   that must be used.
--
-- This entity features a feedback input gating which makes it robust in all configurations.
-- Without input gating, if multiple pulses arrive close to each other, pulse overload will occur
-- and some, or even all of them, can be missed and not arrive on the output.
-- With input gating, if multiple pulses arrive one and only one will arrive on the output.
--
-- Note that unlike e.g. :ref:`resync.resync_level`, it is safe to drive the input of this entity
-- with LUTs as well as FFs.
-- -------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

library common;
use common.types_pkg.all;


entity resync_pulse is
  generic (
    assert_false_on_pulse_overload : boolean := true
  );
  port (
    clk_in : in std_ulogic;
    pulse_in : in std_ulogic;
    --# {{}}
    clk_out : in std_ulogic;
    pulse_out : out std_ulogic := '0'
  );
end entity;

architecture a of resync_pulse is

  signal level_in, level_out, level_out_p1, level_out_feedback : std_ulogic := '0';

begin

  ------------------------------------------------------------------------------
  input : process
  begin
    wait until rising_edge(clk_in);

    if pulse_in then
      if level_in = level_out_feedback then
        level_in <= not level_in;

      elsif assert_false_on_pulse_overload then
        assert false report "Pulse overload";
      end if;
    end if;
  end process;


  ------------------------------------------------------------------------------
  level_in_resync_inst : entity work.resync_level
    generic map (
      -- Value is drive by a FF so this is not needed
      enable_input_register => false
    )
    port map (
      clk_in => clk_in,
      data_in => level_in,
      --
      clk_out => clk_out,
      data_out => level_out
    );


  ------------------------------------------------------------------------------
  level_out_resync_inst : entity work.resync_level
    generic map (
      -- Value is drive by a FF so this is not needed
      enable_input_register => false
    )
    port map (
      clk_in => clk_out,
      data_in => level_out,
      --
      clk_out => clk_in,
      data_out => level_out_feedback
    );


  ------------------------------------------------------------------------------
  output : process
  begin
    wait until rising_edge(clk_out);

    pulse_out <= to_sl(level_out /= level_out_p1);
    level_out_p1 <= level_out;
  end process;

end architecture;
