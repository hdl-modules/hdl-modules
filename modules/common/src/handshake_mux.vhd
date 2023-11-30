-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the hdl-modules project, a collection of reusable, high-quality,
-- peer-reviewed VHDL building blocks.
-- https://hdl-modules.com
-- https://github.com/hdl-modules/hdl-modules
-- -------------------------------------------------------------------------------------------------
-- Multiplex between many AXI-Stream-like inputs towards one output bus.
-- Will lock onto one ``input`` and let its data through until a packet has passed, as indicated
-- by the ``last`` signal.
--
-- The implementation is simple, which comes with a few limitations:
--
-- .. warning::
--
--   If there are holes in an ``input`` packet stream after ``valid`` has been asserted, this
--   multiplexer will be unnecessarily stalled even if another ``input`` has data available.
--   It is up to the user to make sure that this does not occur, using e.g. a :ref:`fifo.fifo`
--   in packet mode, or calculate that the system throughput is still sufficient.
--
--   The arbitration is done in the most resource-efficient round-robin manner possible, which
--   means that one ``input`` can starve out the others if it continuously sends data.
-- -------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.types_pkg.all;


entity handshake_mux is
  generic (
    num_inputs : positive;
    data_width : positive
  );
  port (
    clk : in std_ulogic;
    --# {{}}
    input_ready : out std_ulogic_vector(0 to num_inputs - 1) := (others => '0');
    input_valid : in std_ulogic_vector(0 to num_inputs - 1);
    input_last : in std_ulogic_vector(0 to num_inputs - 1);
    input_data : in slv_vec_t(0 to num_inputs - 1)(data_width - 1 downto 0);
    input_strobe : in slv_vec_t(0 to num_inputs - 1)(data_width / 8 - 1 downto 0) :=
      (others => (others => '1'));
    --# {{}}
    result_ready : in std_ulogic;
    result_valid : out std_ulogic := '0';
    result_last : out std_ulogic := '0';
    result_data : out std_ulogic_vector(data_width - 1 downto 0) := (others => '0');
    result_strobe : out std_ulogic_vector(data_width / 8 - 1 downto 0) := (others => '0');
    -- The input port index where the packet originated
    result_id : out natural range 0 to num_inputs - 1 := 0
  );
end entity;

architecture a of handshake_mux is

  type state_t is (wait_for_valid_input, wait_for_data_packet_done);
  signal state : state_t := wait_for_valid_input;

  signal input_select : natural range input_valid'range := 0;

begin

  ------------------------------------------------------------------------------
  main : process
  begin
    wait until rising_edge(clk);

    case state is
      when wait_for_valid_input =>
        for input_idx in input_valid'range loop
          if input_valid(input_idx) then
            input_select <= input_idx;

            state <= wait_for_data_packet_done;
          end if;
        end loop;

      when wait_for_data_packet_done =>
        if result_ready and result_valid and result_last then
          state <= wait_for_valid_input;
        end if;

    end case;
  end process;


  ------------------------------------------------------------------------------
  assign : process(all)
  begin
    input_ready <= (others => '0');

    result_valid <= '0';

    -- Can alway be assigned, valid is only ever '1' if we have locked on to a valid input
    result_last <= input_last(input_select);
    result_data <= input_data(input_select);
    result_strobe <= input_strobe(input_select);
    result_id <= input_select;

    if state = wait_for_data_packet_done then
      input_ready(input_select) <= result_ready;

      result_valid <= input_valid(input_select);
    end if;
  end process;

end architecture;
