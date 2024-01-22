-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the hdl-modules project, a collection of reusable, high-quality,
-- peer-reviewed VHDL building blocks.
-- https://hdl-modules.com
-- https://github.com/hdl-modules/hdl-modules
-- -------------------------------------------------------------------------------------------------
-- Performs throttling of an AXI write bus with the goal of making the AXI write master
-- well behaved.
-- This entity makes sure that ``AWVALID`` is asserted in the same clock cycle as the first
-- ``WVALID`` of the corresponding data burst.
--
-- This, along with the two conditions below, realize the most strict condition imaginable for an
-- AXI write master interface being well behaved.
-- It guarantees that not a single clock cycle is wasted on the ``throttled`` interface.
--
-- 1. Should be used in conjunction with a data FIFO (:ref:`fifo.fifo`
--    or :ref:`fifo.asynchronous_fifo`) on the ``input.w`` side that has packet mode enabled.
--    This ensures that once ``WVALID`` has been asserted, it remains high until the
--    ``WLAST`` transaction has occurred.
--
-- 2. The ``input.b.ready`` signal should be statically ``'1'``.
--    This ensures that ``B`` master on the ``throttled`` side is never stalled.
--
-- .. digraph:: my_graph
--
--   graph [dpi=300];
--   rankdir="LR";
--
--   aw [shape=none label="AW"];
--   w [shape=none label="W"];
--   b [shape=none label="B"];
--
--   {
--     rank=same;
--     aw;
--     w;
--     b;
--   }
--
--   w_fifo [label="" shape=none image="fifo.png"];
--   w -> w_fifo;
--
--   axi_write_throttle [shape=box label="AXI write\nthrottle"];
--   aw:e -> axi_write_throttle;
--   w_fifo:e -> axi_write_throttle;
--   b -> axi_write_throttle [dir="back"];
--
--   axi_slave [shape=box label="AXI slave" height=2];
--
--   axi_write_throttle -> axi_slave [dir="both" label="AXI\nwrite"];
--
-- The imagined use case for this entity is with an AXI crossbar where the throughput should not
-- be limited by one port starving out the others by being ill-behaved.
-- In this case it makes sense to use this throttler on each port.
--
-- However if a crossbar is not used, and the AXI bus goes directly to an AXI slave that has FIFOs
-- on the ``AW`` and ``W`` channels, then there is no point to using this throttler.
-- These FIFOs can be either in logic (in e.g. an AXI DDR4 controller) or in the "hard"
-- AXI controller in e.g. a Xilinx Zynq device.
-- -------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

library axi;
use axi.axi_pkg.all;

library common;
use common.types_pkg.all;


entity axi_write_throttle is
  port(
    clk : in std_ulogic;
    --# {{}}
    input_m2s : in axi_write_m2s_t;
    input_s2m : out axi_write_s2m_t := axi_write_s2m_init;
    --# {{}}
    throttled_m2s : out axi_write_m2s_t := axi_write_m2s_init;
    throttled_s2m : in axi_write_s2m_t
  );
end entity;

architecture a of axi_write_throttle is

  type state_t is (wait_for_input_valid, let_w_burst_pass);
  signal state : state_t := wait_for_input_valid;

begin

  ------------------------------------------------------------------------------
  main : process
  begin
    wait until rising_edge(clk);

    if throttled_s2m.aw.ready and throttled_m2s.aw.valid then
      throttled_m2s.aw.valid <= '0';
    end if;

    case state is
      when wait_for_input_valid =>
        -- Wait until any previous AW transaction has finished.
        -- Proceed once we have valid AW and W. A W FIFO on the 'input' side being in
        -- packet mode means that we will send one AW transaction and one W burst without holes.
        if (not throttled_m2s.aw.valid) and input_m2s.aw.valid and input_m2s.w.valid then
          throttled_m2s.aw.valid <= '1';

          state <= let_w_burst_pass;
        end if;

      when let_w_burst_pass =>
        if input_s2m.w.ready and input_m2s.w.valid and input_m2s.w.last then
          state <= wait_for_input_valid;
        end if;
    end case;
  end process;


  ------------------------------------------------------------------------------
  assign : process(all)
  begin
    -- AW
    -- All M2S fields except for 'valid', which is set by the state machine.
    throttled_m2s.aw.id <= input_m2s.aw.id;
    throttled_m2s.aw.addr <= input_m2s.aw.addr;
    throttled_m2s.aw.len <= input_m2s.aw.len;
    throttled_m2s.aw.size <= input_m2s.aw.size;
    throttled_m2s.aw.burst <= input_m2s.aw.burst;

    input_s2m.aw.ready <= throttled_s2m.aw.ready and throttled_m2s.aw.valid;

    -- W
    throttled_m2s.w <= input_m2s.w;
    throttled_m2s.w.valid <= input_m2s.w.valid and to_sl(state = let_w_burst_pass);

    input_s2m.w <= throttled_s2m.w;
    input_s2m.w.ready <= throttled_s2m.w.ready and to_sl(state = let_w_burst_pass);

    -- B
    throttled_m2s.b <= input_m2s.b;

    input_s2m.b <= throttled_s2m.b;
  end process;

end architecture;
