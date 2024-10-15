-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the hdl-modules project, a collection of reusable, high-quality,
-- peer-reviewed VHDL building blocks.
-- https://hdl-modules.com
-- https://github.com/hdl-modules/hdl-modules
-- -------------------------------------------------------------------------------------------------
-- Resync a sticky status bit from one clock domain to another.
-- If ``input_event`` is high at any point, the ``result_sticky`` will be raised and will
-- remain high.
-- There is no way to reset this value.
-- Typical use case is to CDC a critical error bit, which might exhibit a pulse-like behavior,
-- from one clock domain to another.
--
-- This entity is a very small wrapper around :ref:`resync.resync_level`.
--
-- Latency
-- _______
--
-- By default, the ``enable_input_register`` generic which is propagated to
-- :ref:`resync.resync_level` is ``false``.
-- This will result in a ``set_false_path`` constraint for the level signal that crosses
-- clock domains.
-- This will yield an arbitrary build-dependent latency.
-- If a deterministic and bounded latency is required, set the ``enable_input_register`` to ``true``
-- to get a ``set_max_delay`` constraint.
-- -------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;


entity resync_sticky_level is
  generic (
    -- Enable to get deterministic latency, see header for details.
    enable_input_register : boolean := false
  );
  port (
    input_clk : in std_ulogic;
    input_event : in std_ulogic;
    --# {{}}
    result_clk : in std_ulogic ;
    result_sticky : out std_ulogic := '0'
  );
end entity;

architecture a of resync_sticky_level is

  signal event_sticky : std_ulogic := '0';

begin

  ------------------------------------------------------------------------------
  set_sticky : process
  begin
    wait until rising_edge(input_clk);

    event_sticky <= event_sticky or input_event;
  end process;


  ------------------------------------------------------------------------------
  resync_level_inst : entity work.resync_level
    generic map (
      enable_input_register => enable_input_register
    )
    port map (
      clk_in => input_clk,
      data_in => event_sticky,
      --
      clk_out => result_clk,
      data_out => result_sticky
    );

end architecture;
