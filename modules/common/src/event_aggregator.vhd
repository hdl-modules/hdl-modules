-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the hdl-modules project, a collection of reusable, high-quality,
-- peer-reviewed VHDL building blocks.
-- https://hdl-modules.com
-- https://github.com/hdl-modules/hdl-modules
-- -------------------------------------------------------------------------------------------------
-- Aggregate events/pulses so that ``aggregated_event`` happens more sparsely than
-- ``input_event``.
-- This is commonly used in an interrupt-based system control flow to avoid bogging
-- down the CPU with too many interrupts.
--
-- It is suitable in situations where knowledge of whether something has occurred is more important
-- than the exact number of times it occurred.
-- An ``input_event`` will always trigger an eventual ``aggregated_event``, but the information
-- of how many ``input_event`` pulses have been received is lost.
--
--
-- Details
-- _______
--
-- The ``event_count`` mechanism sends out an ``aggregated_event`` pulse after a certain number of
-- ``input_event`` pulses have been received.
--
-- The ``tick_count`` mechanism periodically sends out an ``aggregated_event`` pulse at a specified
-- interval, provided that at least one ``input_event`` pulse has been received
-- during the interval.
--
-- The two mechanisms can be combined, in which case the ``aggregated_event`` pulse is sent out
-- after either condition is met.
-- Either condition being met resets the counter for the other condition.
-- This is the most common mode of usage, since it makes sure that events are never too delayed
-- and never too piled up.
-- -------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.types_pkg.all;


entity event_aggregator is
  generic (
    event_count : positive := 1;
    tick_count : positive := 1
  );
  port (
    clk : in std_ulogic;
    --# {{}}
    input_event : in std_ulogic;
    aggregated_event : out std_ulogic := '0'
  );
end entity;

architecture a of event_aggregator is

  constant should_count_events : boolean := event_count > 1;
  constant should_count_ticks : boolean := tick_count > 1;

  constant should_do_anything : boolean := should_count_events or should_count_ticks;

begin

  ------------------------------------------------------------------------------
  passthrough_gen : if not should_do_anything generate

    aggregated_event <= input_event;


  ------------------------------------------------------------------------------
  else generate
    signal event_counter : natural range 0 to event_count - 1 := 0;

    signal tick_counter : natural range 0 to tick_count - 1 := 0;
    signal got_at_least_one_event_this_tick_period : std_ulogic := '0';
  begin

    assert event_count = 1 or event_count > 2
      report "Too small values give corner cases that have not been analyzed"
      severity failure;

    assert tick_count = 1 or tick_count > 2
      report "Too small values give corner cases that have not been analyzed"
      severity failure;


    ------------------------------------------------------------------------------
    main : process
    begin
      wait until rising_edge(clk);

      aggregated_event <= '0';

      if should_count_events then
        if input_event then
          if event_counter = event_count - 1 then
            event_counter <= 0;
            aggregated_event <= '1';
          else
            event_counter <= event_counter + 1;
          end if;
        end if;

        if aggregated_event then
          -- If there is an 'input_event' in this clock cycle it will be lost.
          -- This is deemed fine, we could consider that to be part of the previous
          -- aggregated event.
          -- Assigning 'to_int(input_event)' here increases the LUT usage by a few.
          event_counter <= 0;
        end if;
      end if;

      if should_count_ticks then
        if tick_counter = tick_count - 1 then
          tick_counter <= 0;
          aggregated_event <= got_at_least_one_event_this_tick_period;
        else
          tick_counter <= tick_counter + 1;
        end if;

        if aggregated_event then
          got_at_least_one_event_this_tick_period <= '0';
        else
          got_at_least_one_event_this_tick_period <= (
            got_at_least_one_event_this_tick_period or input_event
          );
        end if;
      end if;
    end process;

  end generate;

end architecture;
