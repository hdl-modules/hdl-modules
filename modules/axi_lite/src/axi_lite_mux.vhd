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
-- There will still be proper AXI handshaking done, so the master will not be stalled.
--
-- .. warning::
--   This entity is written to be used in a register bus, and is designed for simplicity and low
--   resource utilization.
--   An assumption is made that the AXI-Lite master does not queue up reads or writes.
--   I.e. after an ``AR`` transaction, it does not send another ``ARVALID`` before the
--   ``R`` transaction has happened.
--   Same for ``AW`` and ``W``/``B``.
--
--   If the AXI-Lite does queue up transactions it can lead to locking the bus.
--
--   However, if you are using this entity then you probably have a :ref:`axi_lite.axi_to_axi_lite`
--   instance upstream.
--   This entity will by design not queue up transactions.
-- -------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library axi;
use axi.axi_pkg.all;

library math;
use math.math_pkg.all;

library common;
use common.addr_pkg.all;

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
  constant decode_failed : positive := axi_lite_m2s_vec'length;

  constant slave_decode_error_idx : positive := decode_failed;
  constant slave_not_selected_idx : positive := decode_failed + 1;

  signal read_slave_select, write_slave_select : natural range 0 to slave_not_selected_idx
    := slave_not_selected_idx;

  signal read_decode_error_s2m : axi_lite_read_s2m_t := axi_lite_read_s2m_init;
  signal write_decode_error_s2m : axi_lite_write_s2m_t := axi_lite_write_s2m_init;

begin

  ------------------------------------------------------------------------------
  assign_s2m_read : process(all)
  begin
    if read_slave_select = slave_not_selected_idx then
      -- Wait for the master to assert address valid so that we can select the correct slave
      axi_lite_s2m.read.ar <= (ready => '0');
      axi_lite_s2m.read.r <= (valid => '0', data => (others => '-'), resp => (others => '-'));

    elsif read_slave_select = slave_decode_error_idx then
      -- Master requested a slave address that does not exist. Return decode error.
      -- State machine will perform handshake on the different channels.
      axi_lite_s2m.read.ar <= (ready => read_decode_error_s2m.ar.ready);
      axi_lite_s2m.read.r <= (
        valid => read_decode_error_s2m.r.valid,
        resp => axi_resp_decerr,
        data => (others => '-')
      );

    else
      -- Connect the selected slave. State machine will un-select when all transactions are done.
      axi_lite_s2m.read <= axi_lite_s2m_vec(read_slave_select).read;
    end if;
  end process;


  ------------------------------------------------------------------------------
  assign_s2m_write : process(all)
  begin
    if write_slave_select = slave_not_selected_idx then
      -- Wait for the master to assert address valid so that we can select the correct slave
      axi_lite_s2m.write.aw <= (ready => '0');
      axi_lite_s2m.write.w <= (ready => '0');
      axi_lite_s2m.write.b <= (valid => '0', others => (others => '-'));

    elsif write_slave_select = slave_decode_error_idx then
      -- Master requested a slave address that does not exist. Return decode error.
      -- State machine will perform handshake on the different channels.
      axi_lite_s2m.write.aw <= (ready => write_decode_error_s2m.aw.ready);
      axi_lite_s2m.write.w <= (ready => write_decode_error_s2m.w.ready);
      axi_lite_s2m.write.b <= (
        valid => write_decode_error_s2m.b.valid, resp => axi_resp_decerr
      );

    else
      -- Connect the selected slave. State machine will un-select when all transactions are done.
      axi_lite_s2m.write <= axi_lite_s2m_vec(write_slave_select).write;
    end if;
  end process;


  ------------------------------------------------------------------------------
  assign_m2s_vec : process(all)
  begin
    for slave in axi_lite_m2s_vec'range loop
      axi_lite_m2s_vec(slave) <= axi_lite_m2s;

      if write_slave_select /= slave then
        axi_lite_m2s_vec(slave).write.aw.valid <= '0';
        axi_lite_m2s_vec(slave).write.w.valid <= '0';
        axi_lite_m2s_vec(slave).write.b.ready <= '0';
      end if;

      if read_slave_select /= slave then
        axi_lite_m2s_vec(slave).read.ar.valid <= '0';
        axi_lite_m2s_vec(slave).read.r.ready <= '0';
      end if;
    end loop;
  end process;


  ------------------------------------------------------------------------------
  select_read : block
    type state_t is (waiting, decode_error, reading);
    signal state : state_t := waiting;
  begin

    ------------------------------------------------------------------------------
    select_read_slave : process
      variable decoded_idx : natural range 0 to decode_failed;
    begin
      wait until rising_edge(clk);

      case state is
        when waiting =>
          if axi_lite_m2s.read.ar.valid then
            decoded_idx := decode(axi_lite_m2s.read.ar.addr, base_addresses_and_mask);

            if decoded_idx = decode_failed then
              -- If there is no AXI-Lite slave on the requested address, we have to complete the
              -- transaction via this state machine, as to not stall the AXI-Lite master.
              -- Should return error on the response channel.
              read_slave_select <= slave_decode_error_idx;

              -- Complete the AR transaction.
              -- Note that m2s valid is high, so transaction will occur straight away.
              assert not axi_lite_s2m.read.ar.ready;
              read_decode_error_s2m.ar.ready <= '1';

              assert not axi_lite_s2m.read.r.valid;
              read_decode_error_s2m.r.valid <= '1';

              state <= decode_error;
            else
              -- If the requested address has a corresponding slave, select that and
              -- wait until transaction is finished.
              read_slave_select <= decoded_idx;
              state <= reading;
            end if;
          end if;

        when decode_error =>
          read_decode_error_s2m.ar.ready <= '0';

          if axi_lite_m2s.read.r.ready and axi_lite_s2m.read.r.valid then
            read_decode_error_s2m.r.valid <= '0';

            read_slave_select <= slave_not_selected_idx;
            state <= waiting;
          end if;

        when reading =>
          if axi_lite_m2s.read.r.ready and axi_lite_s2m.read.r.valid then
            read_slave_select <= slave_not_selected_idx;
            state <= waiting;
          end if;
      end case;
    end process;

  end block;


  ------------------------------------------------------------------------------
  select_write : block
    type state_t is (waiting, decode_error_w, decode_error_b, writing);
    signal state : state_t := waiting;
  begin

    ------------------------------------------------------------------------------
    select_write_slave : process
      variable decoded_idx : natural range 0 to decode_failed;
    begin
      wait until rising_edge(clk);

      case state is
        when waiting =>
          if axi_lite_m2s.write.aw.valid then
            decoded_idx := decode(axi_lite_m2s.write.aw.addr, base_addresses_and_mask);

            if decoded_idx = decode_failed then
              -- If there is no AXI-Lite slave on the requested address, we have to complete the
              -- transaction via this state machine, as to not stall the AXI-Lite master.
              -- Should return error on the response channel.
              write_slave_select <= slave_decode_error_idx;

              -- Complete the AW transaction.
              -- Note that m2s valid is high, so transaction will occur straight away.
              assert not axi_lite_s2m.write.aw.ready;
              write_decode_error_s2m.aw.ready <= '1';

              assert not axi_lite_s2m.write.w.ready;
              write_decode_error_s2m.w.ready <= '1';

              state <= decode_error_w;
            else
              -- If the requested address has a corresponding slave, select that and
              -- wait until transaction is finished.
              write_slave_select <= decoded_idx;
              state <= writing;
            end if;
          end if;

        when decode_error_w =>
          write_decode_error_s2m.aw.ready <= '0';

          if axi_lite_s2m.write.w.ready and axi_lite_m2s.write.w.valid then
            write_decode_error_s2m.w.ready <= '0';

            assert not axi_lite_s2m.write.b.valid;
            write_decode_error_s2m.b.valid <= '1';

            state <= decode_error_b;
          end if;

        when decode_error_b =>
          if axi_lite_m2s.write.b.ready and axi_lite_s2m.write.b.valid then
            write_decode_error_s2m.b.valid <= '0';

            write_slave_select <= slave_not_selected_idx;
            state <= waiting;
          end if;

        when writing =>
          if axi_lite_m2s.write.b.ready and axi_lite_s2m.write.b.valid then
            write_slave_select <= slave_not_selected_idx;
            state <= waiting;
          end if;
      end case;
    end process;

  end block;

end architecture;
