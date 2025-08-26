-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the hdl-modules project, a collection of reusable, high-quality,
-- peer-reviewed VHDL building blocks.
-- https://hdl-modules.com
-- https://github.com/hdl-modules/hdl-modules
-- -------------------------------------------------------------------------------------------------
-- TODO
-- TODO this file is quite messy honestly. Try to make it nicer. Split to blocks?
-- -------------------------------------------------------------------------------------------------

library ieee;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;

library axi;
use axi.axi_pkg.all;

library common;
use common.types_pkg.all;

use work.trail_pkg.all;


entity axi_to_trail is
  generic (
    address_width : trail_address_width_t;
    data_width : trail_data_width_t;
    id_width : axi_id_width_t
  );
  port (
    clk : in std_ulogic;
    --# {{}}
    axi_m2s : in axi_m2s_t;
    axi_s2m : out axi_s2m_t := axi_s2m_init;
    --# {{}}
    trail_operation : out trail_operation_t := trail_operation_init;
    trail_response : in trail_response_t
  );
end entity;

architecture a of axi_to_trail is

  constant num_unaligned_address_bits : natural := trail_num_unaligned_address_bits(
    data_width=>data_width
  );
  subtype aligned_address_range is natural range
    address_width - 1 downto num_unaligned_address_bits;

  subtype data_range is natural range data_width - 1 downto 0;

  signal axi_id : u_unsigned(id_width - 1 downto 0) := (others => '0');

  constant expected_len : axi_a_len_t := to_len(burst_length_beats=>1);
  constant expected_size : axi_a_size_t := to_size(data_width_bits=>data_width);
  constant expected_unaligned_address : u_unsigned(num_unaligned_address_bits - 1 downto 0) := (
    others => '0'
  );
  constant expected_strobe : std_ulogic_vector(data_width / 8 - 1 downto 0) := (others => '1');

  type state_t is (idle, reading, writing, reading_error, writing_error);
  signal state : state_t := idle;

  signal response_enable_sticky, response_enable_sticky_next : std_ulogic := '0';
  signal axi_response : axi_resp_t := axi_resp_okay;

begin

  ------------------------------------------------------------------------------
  main : process
  begin
    wait until rising_edge(clk);

    axi_s2m.read.ar.ready <= '0';

    axi_s2m.write.aw.ready <= '0';
    axi_s2m.write.w.ready <= '0';

    trail_operation.enable <= '0';

    response_enable_sticky <= response_enable_sticky_next;

    case state is
      when idle =>
        -- Default assignments for a write operation. Read will take precedence below.
        trail_operation.write_enable <= '1';
        trail_operation.address(aligned_address_range) <= axi_m2s.write.aw.addr(
          aligned_address_range
        );
        axi_id <= axi_m2s.write.aw.id(axi_id'range);

        if axi_m2s.read.ar.valid then
          trail_operation.write_enable <= '0';
          trail_operation.address(aligned_address_range) <= axi_m2s.read.ar.addr(
            aligned_address_range
          );
          axi_id <= axi_m2s.read.ar.id(axi_id'range);
        end if;

        -- Sample data so that we can pop W straight away.
        trail_operation.write_data(data_range) <= axi_m2s.write.w.data(data_range);

        if axi_m2s.read.ar.valid then
          axi_s2m.read.ar.ready <= '1';

          if (
            (
              axi_m2s.read.ar.addr(expected_unaligned_address'range)
              /= expected_unaligned_address
            )
            or axi_m2s.read.ar.len /= expected_len
            or axi_m2s.read.ar.size /= expected_size
          ) then
            state <= reading_error;
          else
            trail_operation.enable <= '1';
            state <= reading;
          end if;

        elsif axi_m2s.write.aw.valid and axi_m2s.write.w.valid then
          -- Pop AW and W, regardless if there is an error condition or not.
          -- When we return to this state we know that the previous transactions will have been
          -- popped since we spend at least one cycle in another state.
          axi_s2m.write.aw.ready <= '1';
          axi_s2m.write.w.ready <= '1';

          if (
            (
              axi_m2s.write.aw.addr(expected_unaligned_address'range)
              /= expected_unaligned_address
            )
            or axi_m2s.write.aw.len /= expected_len
            or axi_m2s.write.aw.size /= expected_size
            or axi_m2s.write.w.strb(expected_strobe'range) /= expected_strobe
          ) then
            state <= writing_error;
          else
            trail_operation.enable <= '1';
            state <= writing;
          end if;

        end if;

      when reading =>
        if response_enable_sticky_next and axi_m2s.read.r.ready then
          -- Lower 'valid' after this rising edge.
          response_enable_sticky <= '0';

          state <= idle;
        end if;

      when writing =>
        if response_enable_sticky_next and axi_m2s.write.b.ready then
          -- Lower 'valid' after this rising edge.
          response_enable_sticky <= '0';

          state <= idle;
        end if;

      when reading_error =>
        -- We set 'valid' combinatorially when in this state, so it is enough to check only 'ready'.
        if axi_m2s.read.r.ready then
          state <= idle;
        end if;

      when writing_error =>
        -- We set 'valid' combinatorially when in this state, so it is enough to check only 'ready'.
        if axi_m2s.write.b.ready then
          state <= idle;
        end if;

    end case;

  end process;

  -- Since 'response.enable' is asserted for only one cycle, and does not take any handshaking
  -- into account, we need to keep track of it.
  -- Otherwise we would fail if e.g. BREADY is low for a while.
  response_enable_sticky_next <= response_enable_sticky or trail_response.enable;

  axi_s2m.read.r.valid <= (
    to_sl(state = reading_error) or (to_sl(state = reading) and response_enable_sticky_next)
  );
  axi_s2m.read.r.id(axi_id'range) <= axi_id;
  axi_s2m.read.r.data(data_range) <= trail_response.read_data(data_range);
  axi_s2m.read.r.resp <= axi_response;
  axi_s2m.read.r.last <= '1';

  axi_s2m.write.b.valid <= (
    to_sl(state = writing_error) or (to_sl(state = writing) and response_enable_sticky_next)
  );
  axi_s2m.write.b.id(axi_id'range) <= axi_id;
  axi_s2m.write.b.resp <= axi_response;


  ------------------------------------------------------------------------------
  assign_response : process(all)
  begin
    if trail_response.status = trail_response_status_okay then
      axi_response <= axi_resp_okay;
    else
      axi_response <= axi_resp_slverr;
    end if;

    if state = reading_error or state = writing_error then
      axi_response <= axi_resp_slverr;
    end if;
  end process;

end architecture;
