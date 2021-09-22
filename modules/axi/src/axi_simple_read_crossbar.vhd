-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the tsfpga project.
-- https://tsfpga.com
-- https://gitlab.com/tsfpga/tsfpga
-- -------------------------------------------------------------------------------------------------
-- Simple N-to-1 crossbar for connecting multiple AXI read masters to one port.
--
-- Uses round-robin scheduling for the inputs. It is simple in the sense that
-- there is no separation of AXI AR and R channels with separate queues.
-- After a channel has been selected for address transaction, the crossbar is
-- locked on that channel until it has finished it's read response transactions.
-- After that the crossbar moves on to do a new address transaction on, possibly,
-- another channel.
--
-- Due to this it has a very small logic footprint but will never reach full
-- utilization of the data channels. In order to get higher throughput, further address transactions
-- should be queued up to the slave while a read response burst is running.
-- -------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

library axi;
use axi.axi_pkg.all;

library common;
use common.types_pkg.all;


entity axi_simple_read_crossbar is
  generic(
    num_inputs : integer
  );
  port(
    clk : in std_logic;
    --
    input_ports_m2s : in axi_read_m2s_vec_t(0 to num_inputs - 1) := (others => axi_read_m2s_init);
    input_ports_s2m : out axi_read_s2m_vec_t(0 to num_inputs - 1) := (others => axi_read_s2m_init);
    --
    output_m2s : out axi_read_m2s_t := axi_read_m2s_init;
    output_s2m : in axi_read_s2m_t := axi_read_s2m_init
  );
end entity;

architecture a of axi_simple_read_crossbar is

  constant no_input_selected : integer := input_ports_m2s'high + 1;

  -- Max num outstanding address transactions
  constant max_addr_fifo_depth : integer := 128;

  signal input_select : integer range 0 to no_input_selected := no_input_selected;
  signal input_select_turn_counter : integer range input_ports_m2s'range := 0;

  type state_t is (wait_for_ar_valid, wait_for_ar_done, wait_for_r_done);
  signal state : state_t := wait_for_ar_valid;

begin

  ----------------------------------------------------------------------------
  select_input : process
    variable ar_done, r_done : std_logic;
    variable num_outstanding_addr_transactions : integer range 0 to max_addr_fifo_depth := 0;
  begin
    wait until rising_edge(clk);

    ar_done := output_s2m.ar.ready and output_m2s.ar.valid;
    r_done := output_m2s.r.ready and output_s2m.r.valid and output_s2m.r.last;

    num_outstanding_addr_transactions := num_outstanding_addr_transactions
      + to_int(ar_done) - to_int(r_done);

    case state is
      when wait_for_ar_valid =>
        -- Rotate around to find an input that requests a transaction
        if input_ports_m2s(input_select_turn_counter).ar.valid then
          input_select <= input_select_turn_counter;
          state <= wait_for_ar_done;
        end if;

        if input_select_turn_counter = input_ports_m2s'high then
          input_select_turn_counter <= 0;
        else
          input_select_turn_counter <= input_select_turn_counter + 1;
        end if;

      when wait_for_ar_done =>
        -- Wait for address transaction so that num_outstanding_addr_transactions
        -- is updated and this input actually gets to do a transaction
        if ar_done then
          state <= wait_for_r_done;
        end if;

      when wait_for_r_done =>
        -- Wait until all of this input's negotiated bursts are done, and then
        -- go back to choose a new input
        if num_outstanding_addr_transactions = 0 then
          input_select <= no_input_selected;
          state <= wait_for_ar_valid;
        end if;

    end case;
  end process;


  ----------------------------------------------------------------------------
  assign_bus : process(all)
  begin
    output_m2s.ar <= (
      valid => '0',
      burst => (others => '-'),
      others => (others => '-')
    );
    output_m2s.r <= (ready => '0');

    for idx in input_ports_m2s'range loop
      -- Default assignment of all members. Non-selected inputs will be zero'd out below.
      input_ports_s2m(idx) <= output_s2m;

      if idx = input_select then
        -- Assign whole M2S bus from the selected input
        output_m2s <= input_ports_m2s(idx);
      else
        -- Non-selected inputs shall have their control signal zero'd out.
        -- Other members of the bus (r.data, etc.) can still be assigned.
        input_ports_s2m(idx).ar.ready <= '0';
        input_ports_s2m(idx).r.valid <= '0';
      end if;
    end loop;
  end process;

end architecture;
