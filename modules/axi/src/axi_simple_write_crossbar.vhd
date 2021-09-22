-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the tsfpga project.
-- https://tsfpga.com
-- https://gitlab.com/tsfpga/tsfpga
-- -------------------------------------------------------------------------------------------------
-- Simple N-to-1 crossbar for connecting multiple AXI write masters to one port.
--
-- Uses round-robin scheduling for the inputs. It is simple in the sense that
-- there is no separation of AXI AW/W/B channels with separate queues.
-- After a channel has been selected for address transaction, the crossbar is
-- locked on that channel until it has finished it's write (W) transactions and write
-- response (B) transaction. After that the crossbar moves on to do a new address transaction
-- on, possibly, another channel.
--
-- Due to this it has a very small logic footprint but will never reach full
-- utilization of the data channels. In order to reach higher throughput there needs to be
-- separation of the channels so that further AW transactions are queued up while other W and B
-- transactions are running, and further W transactions are performed while waiting for other
-- B transactions.
-- -------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

library axi;
use axi.axi_pkg.all;

library common;
use common.types_pkg.all;


entity axi_simple_write_crossbar is
  generic(
    num_inputs : integer
  );
  port(
    clk : in std_logic;
    --
    input_ports_m2s : in axi_write_m2s_vec_t(0 to num_inputs - 1) := (others => axi_write_m2s_init);
    input_ports_s2m : out axi_write_s2m_vec_t(0 to num_inputs - 1) := (others => axi_write_s2m_init);
    --
    output_m2s : out axi_write_m2s_t := axi_write_m2s_init;
    output_s2m : in axi_write_s2m_t := axi_write_s2m_init
  );
end entity;

architecture a of axi_simple_write_crossbar is

  constant no_input_selected : integer := input_ports_m2s'high + 1;

  -- Max num outstanding address transactions
  constant max_addr_fifo_depth : integer := 128;

  signal input_select : integer range 0 to no_input_selected := no_input_selected;
  signal input_select_turn_counter : integer range input_ports_s2m'range := 0;

  type state_t is (wait_for_aw_valid, wait_for_aw_done, wait_for_b_done);
  signal state : state_t := wait_for_aw_valid;

begin

  ----------------------------------------------------------------------------
  select_input : process
    variable aw_done, b_done : std_logic;
    variable num_outstanding_addr_transactions : integer range 0 to max_addr_fifo_depth := 0;
  begin
    wait until rising_edge(clk);

    aw_done := output_s2m.aw.ready and output_m2s.aw.valid;
    b_done := output_m2s.b.ready and output_s2m.b.valid;

    num_outstanding_addr_transactions := num_outstanding_addr_transactions
      + to_int(aw_done) - to_int(b_done);

    case state is
      when wait_for_aw_valid =>
        -- Rotate around to find an input that requests a transaction
        if input_ports_m2s(input_select_turn_counter).aw.valid then
          input_select <= input_select_turn_counter;
          state <= wait_for_aw_done;
        end if;

        if input_select_turn_counter = input_ports_m2s'high then
          input_select_turn_counter <= 0;
        else
          input_select_turn_counter <= input_select_turn_counter + 1;
        end if;

      when wait_for_aw_done =>
        -- Wait for address transaction so that num_outstanding_addr_transactions
        -- is updated and this input actually gets to do a transaction
        if aw_done then
          state <= wait_for_b_done;
        end if;

      when wait_for_b_done =>
        -- Wait until all of this input's negotiated bursts are done, and then
        -- go back to choose a new input
        if num_outstanding_addr_transactions = 0 then
          input_select <= no_input_selected;
          state <= wait_for_aw_valid;
        end if;

    end case;
  end process;


  ----------------------------------------------------------------------------
  assign_bus : process(all)
  begin
    output_m2s.aw <= (
      valid => '0',
      burst => (others => '-'),
      others => (others => '-')
    );
    output_m2s.w <= (
      valid => '0',
      last => '-',
      id=> (others => '-'),
      others => (others => '-')
    );
    output_m2s.b <= (ready => '0');

    for idx in input_ports_s2m'range loop
      -- Default assignment of all members. Non-selected inputs will be zero'd out below.
      input_ports_s2m(idx) <= output_s2m;

      if idx = input_select then
        -- Assign whole M2S bus from the selected input
        output_m2s <= input_ports_m2s(idx);
      else
        -- Non-selected inputs shall have their control signal zero'd out.
        -- Other members of the bus (b.resp, etc.) can still be assigned.
        input_ports_s2m(idx).aw.ready <= '0';
        input_ports_s2m(idx).w.ready <= '0';
        input_ports_s2m(idx).b.valid <= '0';
      end if;
    end loop;
  end process;

end architecture;
