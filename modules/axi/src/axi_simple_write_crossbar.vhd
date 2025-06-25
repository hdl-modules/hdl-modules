-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the hdl-modules project, a collection of reusable, high-quality,
-- peer-reviewed VHDL building blocks.
-- https://hdl-modules.com
-- https://github.com/hdl-modules/hdl-modules
-- -------------------------------------------------------------------------------------------------
-- Simple N-to-1 crossbar for connecting multiple AXI write masters to one port.
--
-- It is simple in the sense that there is no separation of AXI ``AW``/``W``/``B`` channels
-- with separate queues.
-- After a port has been selected for address transaction, the crossbar is
-- locked on that port until it has finished it's write (``W``) transactions and write
-- response (``B``) transaction. After that, the crossbar moves on to do a new address transaction
-- on, possibly, another port.
--
-- Due to this it has a very small logic footprint but will never reach full
-- utilization of the data channels.
-- In order to reach higher throughput there needs to be separation of the channels so that further
-- ``AW`` transactions are queued up while other ``W`` and ``B`` transactions are running,
-- and further ``W`` transactions are performed while waiting for other ``B`` transactions.
--
-- Arbitration is done in simplest most resource-efficient manner possible, which
-- means that one input port can block others if it continuously sends transactions.
-- -------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

library axi;
use axi.axi_pkg.all;

library common;
use common.types_pkg.all;


entity axi_simple_write_crossbar is
  generic(
    num_inputs : positive
  );
  port(
    clk : in std_ulogic;
    --# {{}}
    input_ports_m2s : in axi_write_m2s_vec_t(0 to num_inputs - 1);
    input_ports_s2m : out axi_write_s2m_vec_t(0 to num_inputs - 1)
      := (others => axi_write_s2m_init);
    --# {{}}
    output_m2s : out axi_write_m2s_t := axi_write_m2s_init;
    output_s2m : in axi_write_s2m_t
  );
end entity;

architecture a of axi_simple_write_crossbar is

  signal input_select : natural range input_ports_m2s'range := 0;

  type state_t is (idle, wait_for_aw_done, wait_for_w_done, wait_for_b_done);
  signal state : state_t := idle;

  signal let_aw_through, let_w_through, let_b_through : std_ulogic := '0';

begin

  ----------------------------------------------------------------------------
  select_input : process
  begin
    wait until rising_edge(clk);

    case state is
      when idle =>
        for input_select_next in input_ports_m2s'range loop
          if input_ports_m2s(input_select_next).aw.valid then
            input_select <= input_select_next;
            state <= wait_for_aw_done;
          end if;
        end loop;

      when wait_for_aw_done =>
        -- We know that 'valid' is high, otherwise we would not have gone to this state, so we
        -- don't have to include it in the condition.
        if output_s2m.aw.ready then
          state <= wait_for_w_done;
        end if;

      when wait_for_w_done =>
        if output_s2m.w.ready and output_m2s.w.valid and output_m2s.w.last then
          state <= wait_for_b_done;
        end if;

      when wait_for_b_done =>
        if output_m2s.b.ready and output_s2m.b.valid then
          state <= idle;
        end if;

    end case;
  end process;

  -- If these were registers set in the process above instead, it would save a little bit of
  -- logical depth in the combinatorial assignment below.
  -- Since it would be one LUT input rather than two.
  let_aw_through <= to_sl(state = wait_for_aw_done);
  let_w_through <= to_sl(state = wait_for_w_done);
  let_b_through <= to_sl(state = wait_for_b_done);


  ----------------------------------------------------------------------------
  assign_bus : process(all)
  begin
    for input_idx in input_ports_s2m'range loop
      input_ports_s2m(input_idx) <= output_s2m;

      input_ports_s2m(input_idx).aw.ready <= (
        output_s2m.aw.ready and to_sl(input_select = input_idx) and let_aw_through
      );
      input_ports_s2m(input_idx).w.ready <= (
        output_s2m.w.ready and to_sl(input_select = input_idx) and let_w_through
      );
      input_ports_s2m(input_idx).b.valid <= (
        output_s2m.b.valid and to_sl(input_select = input_idx) and let_b_through
      );
    end loop;

    output_m2s <= input_ports_m2s(input_select);

    output_m2s.aw.valid <= input_ports_m2s(input_select).aw.valid and let_aw_through;
    output_m2s.w.valid <= input_ports_m2s(input_select).w.valid and let_w_through;
    output_m2s.b.ready <= input_ports_m2s(input_select).b.ready and let_b_through;
  end process;

end architecture;
