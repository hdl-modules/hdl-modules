-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the hdl-modules project, a collection of reusable, high-quality,
-- peer-reviewed VHDL building blocks.
-- https://hdl-modules.com
-- https://github.com/hdl-modules/hdl-modules
-- -------------------------------------------------------------------------------------------------
-- Combinatorially split an AXI-Stream-like handshaking interface, for cases where many slaves
-- are to receive the data.
-- Maintains full throughput and is AXI-stream compliant in its handling of the handshake signals
-- (``valid`` does not wait for ``ready``, ``valid`` does not fall unless a transaction
-- has occurred).
--
-- This entity has no pipelining of the handshake signals, but instead connects
-- them combinatorially.
-- This increases the logic depth for handshake signals where this entity is used.
-- If timing issues occur (on the ``input`` or one of the ``output`` s) a
-- :ref:`common.handshake_pipeline` instance can be used.
-- -------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;


entity handshake_splitter is
  generic (
    num_interfaces : positive
  );
  port (
    clk : in std_ulogic;
    --# {{}}
    input_ready : out std_ulogic := '0';
    input_valid : in std_ulogic;
    --# {{}}
    output_ready : in std_ulogic_vector(0 to num_interfaces - 1);
    output_valid : out std_ulogic_vector(0 to num_interfaces - 1) := (others => '0')
  );
end entity;

architecture a of handshake_splitter is

  -- Keep track of whether a transaction has been performed on each of the output interfaces
  signal transaction_done : std_ulogic_vector(output_valid'range) := (others => '0');

begin

  ------------------------------------------------------------------------------
  output_gen : for output_index in output_valid'range generate
    signal transaction_done_sticky : std_ulogic := '0';
  begin

    ------------------------------------------------------------------------------
    keep_track_of_whether_transaction_has_occurred_for_this_output : process
    begin
      wait until rising_edge(clk);

      transaction_done_sticky <= transaction_done_sticky or transaction_done(output_index);

      -- If an input transaction occurs, that means that a transaction has occurred on
      -- all output interfaces including this one. Reset to indicate that we are not done
      -- with the upcoming transaction.
      if input_ready and input_valid then
        transaction_done_sticky <= '0';
      end if;
    end process;

    transaction_done(output_index) <=
      transaction_done_sticky or (output_ready(output_index) and output_valid(output_index));

    output_valid(output_index) <= input_valid and not transaction_done_sticky;

  end generate;

  -- Pop on the input side once all output interfaces have performed a transaction
  -- (in this clock cycle or earlier)
  input_ready <= and transaction_done;

end architecture;
