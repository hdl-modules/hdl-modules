-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the hdl-modules project, a collection of reusable, high-quality,
-- peer-reviewed VHDL building blocks.
-- https://hdl-modules.com
-- https://github.com/hdl-modules/hdl-modules
-- -------------------------------------------------------------------------------------------------
-- AXI-Lite mux, aka simple 1-to-N crossbar.
--
-- The ``base_addresses`` generic is a list of base addresses for the N slaves.
-- If the address requested by the master does not match any base address, this entity
-- will send AXI decode error ``DECERR`` on the response channel (``RRESP`` or ``BRESP``).
-- There will still be proper AXI-Lite handshaking done, so the master will not hang.
-- -------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library math;
use math.math_pkg.all;

library common;
use common.addr_pkg.all;
use common.types_pkg.all;

use work.axi_lite_pkg.all;


entity axi_lite_mux is
  generic (
    base_addresses : addr_vec_t
  );
  port (
    clk : in std_ulogic;
    --# {{}}
    axi_lite_m2s : in axi_lite_m2s_t;
    axi_lite_s2m : out axi_lite_s2m_t := axi_lite_s2m_init;
    --# {{}}
    axi_lite_m2s_vec : out axi_lite_m2s_vec_t(base_addresses'range) := (
      others => axi_lite_m2s_init
    );
    axi_lite_s2m_vec : in axi_lite_s2m_vec_t(base_addresses'range)
  );
end entity;

architecture a of axi_lite_mux is

  constant base_addresses_and_mask : addr_and_mask_vec_t := calculate_mask(base_addresses);

  -- Decode function will return upper index + 1 if no slave matched
  constant slave_decode_error_idx : positive := axi_lite_m2s_vec'length;

  signal read_slave_select, write_slave_select : natural range 0 to slave_decode_error_idx := 0;

  signal let_ar_through, let_r_through : std_ulogic := '0';
  signal let_aw_through, let_w_through, let_b_through : std_ulogic := '0';

begin

  ------------------------------------------------------------------------------
  assign_s2m_read : process(all)
  begin
    -- Default assignments.
    axi_lite_s2m.read.ar <= (ready => '0');
    axi_lite_s2m.read.r <= (valid => '0', data => (others => '-'), resp => (others => '-'));

    if let_ar_through then
      if read_slave_select = slave_decode_error_idx then
        axi_lite_s2m.read.ar <= (ready => '1');
      else
        axi_lite_s2m.read.ar <= axi_lite_s2m_vec(read_slave_select).read.ar;
      end if;
    end if;

    if let_r_through then
      if read_slave_select = slave_decode_error_idx then
        axi_lite_s2m.read.r <= (
          valid => '1', resp => axi_lite_resp_decerr, data => (others => '-')
        );
      else
        axi_lite_s2m.read.r <= axi_lite_s2m_vec(read_slave_select).read.r;
      end if;
    end if;
  end process;


  ------------------------------------------------------------------------------
  assign_s2m_write : process(all)
  begin
    -- Default assignments.
    axi_lite_s2m.write.aw <= (ready => '0');
    axi_lite_s2m.write.w <= (ready => '0');
    axi_lite_s2m.write.b <= (valid => '0', others => (others => '-'));

    if let_aw_through then
      if write_slave_select = slave_decode_error_idx then
        axi_lite_s2m.write.aw <= (ready => '1');
      else
        axi_lite_s2m.write.aw <= axi_lite_s2m_vec(write_slave_select).write.aw;
      end if;
    end if;

    if let_w_through then
      if write_slave_select = slave_decode_error_idx then
        axi_lite_s2m.write.w <= (ready => '1');
      else
        axi_lite_s2m.write.w <= axi_lite_s2m_vec(write_slave_select).write.w;
      end if;
    end if;

    if let_b_through then
      if write_slave_select = slave_decode_error_idx then
        axi_lite_s2m.write.b <= (valid => '1', resp => axi_lite_resp_decerr);
      else
        axi_lite_s2m.write.b <= axi_lite_s2m_vec(write_slave_select).write.b;
      end if;
    end if;
  end process;


  ------------------------------------------------------------------------------
  assign_m2s_vec : process(all)
  begin
    for slave_idx in axi_lite_m2s_vec'range loop
      -- Default assignment.
      axi_lite_m2s_vec(slave_idx) <= axi_lite_m2s;

      axi_lite_m2s_vec(slave_idx).read.ar.valid <=  (
        axi_lite_m2s.read.ar.valid and let_ar_through and to_sl(read_slave_select = slave_idx)
      );
      axi_lite_m2s_vec(slave_idx).read.r.ready <= (
        axi_lite_m2s.read.r.ready and let_r_through and to_sl(read_slave_select = slave_idx)
      );

      axi_lite_m2s_vec(slave_idx).write.aw.valid <= (
        axi_lite_m2s.write.aw.valid and let_aw_through and to_sl(write_slave_select = slave_idx)
      );
      axi_lite_m2s_vec(slave_idx).write.w.valid <= (
        axi_lite_m2s.write.w.valid and let_w_through and to_sl(write_slave_select = slave_idx)
      );
      axi_lite_m2s_vec(slave_idx).write.b.ready <= (
        axi_lite_m2s.write.b.ready and let_b_through and to_sl(write_slave_select = slave_idx)
      );
    end loop;
  end process;


  ------------------------------------------------------------------------------
  select_read : block
    type state_t is (wait_for_input, wait_for_done);
    signal state : state_t := wait_for_input;
  begin

    ------------------------------------------------------------------------------
    select_read_slave : process
    begin
      wait until rising_edge(clk);

      case state is
        when wait_for_input =>
          read_slave_select <= decode(axi_lite_m2s.read.ar.addr, base_addresses_and_mask);

          if axi_lite_m2s.read.ar.valid then
            let_ar_through <= '1';
            let_r_through <= '1';

            state <= wait_for_done;
          end if;

        when wait_for_done =>
          -- AXI standard A3.3.1: slave must wait for AR transaction before asserting RVALID.
          -- Hence it is enough to look only at 'R', no need to check that 'AR' is also done.
          -- We could save one clock cycle by looking at 'ARREADY' and 'RVALID', instead of the
          -- 'let through' signal.
          -- But that would increase fanout of the control signals, which is often critical.
          -- We do send the 'RVALID' signal through ASAP, and it is unlikely the master will have
          -- a new 'ARVALID' back-to-back.
          -- So in practice, this is likely not a throughput limitation.
          if not let_r_through then
            state <= wait_for_input;
          end if;
      end case;

      if axi_lite_s2m.read.ar.ready and axi_lite_m2s.read.ar.valid then
        let_ar_through <= '0';
      end if;

      if axi_lite_m2s.read.r.ready and axi_lite_s2m.read.r.valid then
        let_r_through <= '0';
      end if;
    end process;

  end block;


  ------------------------------------------------------------------------------
  select_write : block
    type state_t is (wait_for_input, wait_for_done);
    signal state : state_t := wait_for_input;
  begin

    ------------------------------------------------------------------------------
    select_write_slave : process
    begin
      wait until rising_edge(clk);

      case state is
        when wait_for_input =>
          write_slave_select <= decode(axi_lite_m2s.write.aw.addr, base_addresses_and_mask);

          if axi_lite_m2s.write.aw.valid then
            let_aw_through <= '1';
            let_w_through <= '1';
            let_b_through <= '1';

            state <= wait_for_done;
          end if;

        when wait_for_done =>
          -- AXI standard A3.3.1: slave must wait for WLAST transaction before asserting BVALID.
          -- This implies that it also has to wait for AW transaction.
          -- Hence it is enough to look only at 'B', no need to check that 'AW' and 'W' are
          -- done also.
          -- Same note on throughput as in the read case.
          if not let_b_through then
            state <= wait_for_input;
          end if;
      end case;

      if axi_lite_s2m.write.aw.ready and axi_lite_m2s.write.aw.valid then
        let_aw_through <= '0';
      end if;

      if axi_lite_s2m.write.w.ready and axi_lite_m2s.write.w.valid then
        let_w_through <= '0';
      end if;

      if axi_lite_m2s.write.b.ready and axi_lite_s2m.write.b.valid then
        let_b_through <= '0';
      end if;
    end process;

  end block;

end architecture;
