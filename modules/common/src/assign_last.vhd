-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the hdl-modules project, a collection of reusable, high-quality,
-- peer-reviewed VHDL building blocks.
-- https://hdl-modules.com
-- https://github.com/hdl-modules/hdl-modules
-- -------------------------------------------------------------------------------------------------
-- Calculate the ``last`` indicator for an AXI-Stream-like handshaking data flow.
-- Can be used the enable packet-based processing from a data source that does not provide
-- a ``last`` signal.
--
-- The packet length is specified at compile-time using the ``packet_length_beats`` generic.
-- ``last`` will be asserted every ``packet_length_beats``'th beat that passes.
--
-- This entity shall be instantiated in parallel with the data bus.
-- The ``ready`` and ``valid`` ports must be assigned combinatorially.
-- The ``last`` shall be assigned combinatorially alongside the ``ready`` and ``valid`` signals
-- that go towards the data sink.
-- -------------------------------------------------------------------------------------------------

library ieee;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;

library common;
use common.types_pkg.all;

library math;
use math.math_pkg.all;


entity assign_last is
  generic (
    packet_length_beats : in positive
  );
  port (
    clk : in std_ulogic;
    --# {{}}
    ready : in std_ulogic;
    valid : in std_ulogic;
    last : out std_ulogic := '0'
  );
end entity;

architecture a of assign_last is

  constant power_of_two_length : boolean := is_power_of_two(packet_length_beats);

  signal beat_counter : natural range 0 to packet_length_beats - 1 := 0;

begin

  last <= to_sl(beat_counter = packet_length_beats - 1);


  ------------------------------------------------------------------------------
  main : process
  begin
    wait until rising_edge(clk);

    if ready and valid then
      if power_of_two_length then
        -- Efficient implementation.
        beat_counter <= (beat_counter + 1) mod packet_length_beats;

      else
        -- Slightly less efficient.
        if beat_counter = packet_length_beats - 1 then
          beat_counter <= 0;
        else
          beat_counter <= beat_counter + 1;
        end if;
      end if;
    end if;
  end process;

end architecture;
