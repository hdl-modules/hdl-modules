-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the hdl-modules project, a collection of reusable, high-quality,
-- peer-reviewed VHDL building blocks.
-- https://hdl-modules.com
-- https://github.com/hdl-modules/hdl-modules
-- -------------------------------------------------------------------------------------------------
-- Bus Functional Model (BFM) to read/write/check values on an AXI-Lite bus.
-- This BFM is a custom implementation, and an alternative to :ref:`bfm.axi_lite_master`, which is
-- a wrapper around a VUnit VC.
--
-- .. warning::
--   While this file and this eco-system is stable and usable, it is in a state of development.
--   Expect API changes in the future.
--
--
-- Usage
-- _____
--
-- This BFM operates very much like other VUnit verification components using the "bus master"
-- eco-system.
-- Currently there are some subtle differences, which could probably be unified with VUnit.
-- But for now, the recommended way to use this BFM is with the
-- ``check_bfm``, ``check_await_bfm``, ``write_bfm``, and ``write_await_bfm`` procedures
-- in :ref:`bfm.axi_lite_bfm_pkg`.
--
-- See e.g. the file ``tb_axi_lite_register_file.vhd`` for a usage example.
--
--
--
-- Randomization
-- _____________
--
-- This BFM will inject random handshake stall/jitter, for good verification coverage.
-- Modify the ``*_stall_config`` generics to get your desired behavior.
-- The random seed is provided by a VUnit mechanism
-- (see the "seed" portion of `this document <https://vunit.github.io/run/user_guide.html>`__).
-- Use the ``--seed`` command line argument if you need to set a static seed.
--
--
-- Differences compared to VUnit VC
-- ________________________________
--
-- Compared to the VUnit Verification Components (VC) that is wrapped in :ref:`bfm.axi_lite_master`,
-- this BFM:
--
-- 1. Supports synchronous reset.
-- 2. Unlike VUnit bus master eco-system, the register ``check`` procedures for this BFM performs
--    the check in the BFM, not the procedure call.
--    This means that check calls are not blocking, and multiple checks (or other operations) can
--    be queued up and executed back-to-back.
-- 3. Fully randomized stall of ``RREADY`` and ``BREADY``.
--
--    a. The signals can be '1' even when it is not supposed to receive a reply, and fall to '0'
--       even when it is expecting a reply.
-- 4. Independent randomized stall of ``AW`` and ``W`` channels.
--
--    a. ``WVALID`` can arrive before ``AWVALID``.
--       Potentially multiple ``W`` transactions before the first ``AWVALID``.
--    b. Potentially multiple ``AW`` transactions before the first ``WVALID``.
-- 5. Supports transactions without bubble cycles on all the channels.
--
-- Limitations
--
-- 1. No strobe (byte enable) support.
-- 2. Does not, at this point, support the regular e.g. ``read_bus`` calls.
--
-- All of this could be supported in the future.
-- -------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
use vunit_lib.bus_master_pkg.all;
use vunit_lib.check_pkg.all;
use vunit_lib.com_pkg.all;
use vunit_lib.com_types_pkg.all;
use vunit_lib.queue_pkg.all;
use vunit_lib.sync_pkg.all;

library register_file;
use register_file.register_operations_pkg.register_bus_master;

library axi_lite;
use axi_lite.axi_lite_pkg.all;

library common;
use common.types_pkg.all;

use work.axi_bfm_pkg.all;
use work.axi_lite_bfm_pkg.all;
use work.stall_bfm_pkg.all;


entity axi_lite_master_bfm is
  generic (
    bus_handle : bus_master_t := register_bus_master;
    -- Stall configuration for the AW/AR/W channel masters and the R/B channel slaves.
    ar_stall_config : stall_configuration_t := default_address_stall_config;
    r_stall_config : stall_configuration_t := default_data_stall_config;
    aw_stall_config : stall_configuration_t := default_address_stall_config;
    w_stall_config : stall_configuration_t := default_data_stall_config;
    b_stall_config : stall_configuration_t := default_data_stall_config;
    -- Suffix for error log messages. Can be used to differentiate between multiple instances.
    logger_name_suffix : string := "";
    -- When 'ARVALID'/'AWVALID'/'WVALID' is zero, the associated output ports will be driven with
    -- this value.
    -- This is to avoid a DUT sampling the values in the wrong clock cycle.
    drive_invalid_value : std_ulogic := 'X'
  );
  port (
    clk : in std_ulogic;
    reset : in std_ulogic := '0';
    --# {{}}
    axi_lite_m2s : out axi_lite_m2s_t := axi_lite_m2s_init;
    axi_lite_s2m : in axi_lite_s2m_t
  );
end entity;

architecture a of axi_lite_master_bfm is

  subtype address_range is natural range address_length(bus_handle) - 1 downto 0;
  subtype data_range is natural range data_length(bus_handle) - 1 downto 0;

  type queues_t is record
    address : queue_t;
    data : queue_t;
    response : queue_t;
    response_address : queue_t;
    reply : queue_t;
  end record;

  constant read_queues, write_queues : queues_t := (others => new_queue);

begin

  ------------------------------------------------------------------------------
  main : process
    procedure push_operation(queues : queues_t; request_msg : inout msg_t) is
      constant address : u_unsigned(address_range) := u_unsigned(
        pop_std_ulogic_vector(request_msg)
      );
    begin
      push(queues.address, address);
      push(queues.data, pop_std_ulogic_vector(request_msg));
      push(queues.response, pop_std_ulogic_vector(request_msg));
      push(queues.response_address, address);

      push(queues.reply, request_msg);
    end procedure;

    impure function is_idle return boolean is
    begin
      return is_empty(read_queues.reply) and is_empty(write_queues.reply);
    end function;

    variable request_msg : msg_t := null_msg;
    variable msg_type : msg_type_t := null_msg_type;
  begin
    receive(net, bus_handle.p_actor, request_msg);
    msg_type := message_type(request_msg);

    if msg_type = bfm_check_msg then
      push_operation(queues=>read_queues, request_msg=>request_msg);

    elsif msg_type = bfm_write_msg then
      push_operation(queues=>write_queues, request_msg=>request_msg);

    elsif msg_type = wait_until_idle_msg then
      if not is_idle then
        wait until is_idle and rising_edge(clk);
      end if;
      handle_wait_until_idle(net, msg_type, request_msg);

    else
      unexpected_msg_type(msg_type);

    end if;
  end process;


  ------------------------------------------------------------------------------
  read_block : block
  begin

    ------------------------------------------------------------------------------
    ar_block : block
      signal data_is_valid : std_ulogic := '0';
      signal addr_target : u_unsigned(address_range) := (others => '0');
    begin

      ------------------------------------------------------------------------------
      set_ar : process
      begin
        while is_empty(read_queues.address) loop
          wait until rising_edge(clk);
        end loop;

        if reset then
          flush(read_queues.address);
        else
          addr_target <= pop(read_queues.address);
          data_is_valid <= '1';

          wait until (
            ((axi_lite_s2m.read.ar.ready and axi_lite_m2s.read.ar.valid) or reset)
            and rising_edge(clk)
          );

          data_is_valid <= '0';
        end if;
      end process;


      ------------------------------------------------------------------------------
      handshake_master_inst : entity work.handshake_master
        generic map (
          stall_config => ar_stall_config
        )
        port map (
          clk => clk,
          --
          data_is_valid => data_is_valid,
          --
          ready => axi_lite_s2m.read.ar.ready,
          valid => axi_lite_m2s.read.ar.valid
        );

      -- Set the bus members only when bus is valid.
      axi_lite_m2s.read.ar.addr(addr_target'range) <=
        addr_target when axi_lite_m2s.read.ar.valid else (others => drive_invalid_value);


      ------------------------------------------------------------------------------
      ar_protocol_checker_inst : entity common.axi_stream_protocol_checker
        generic map (
          logger_name_suffix => " - axi_lite_read_master - AR" & logger_name_suffix
        )
        port map (
          clk => clk,
          --
          ready => axi_lite_s2m.read.ar.ready
        );

    end block;


    ------------------------------------------------------------------------------
    r_block : block
      constant data_width : positive := data_length(bus_handle);
      alias got_data is axi_lite_s2m.read.r.data(data_width - 1 downto 0);
    begin

      ------------------------------------------------------------------------------
      check_r : process
        function get_message(name : string) return string is
        begin
          return (
            "axi_lite_read_master"
            & logger_name_suffix
            & " - R - '"
            & name
            & "' mismatch when reading address "
          );
        end function;
        constant resp_message : string := get_message("resp");
        constant data_message : string := get_message("data");

        variable read_address : u_unsigned(address_range) := (others => '0');
        variable expected_data : std_ulogic_vector(got_data'range) := (others => '0');

        variable request_msg, reply_msg : msg_t := null_msg;
      begin
        wait until (
          ((axi_lite_m2s.read.r.ready and axi_lite_s2m.read.r.valid) or reset)
          and rising_edge(clk)
        );

        if reset then
          flush(read_queues.data);
          flush(read_queues.response);
          flush(read_queues.response_address);
          flush(read_queues.reply);
        else
          read_address := pop(read_queues.response_address);

          check_equal(
            axi_lite_s2m.read.r.resp,
            pop_std_ulogic_vector(read_queues.response),
            resp_message & to_string(read_address)
          );

          expected_data := pop(read_queues.data);
          if axi_lite_s2m.read.r.resp = axi_lite_resp_okay then
            check_equal(
              got_data, expected_data, data_message & to_string(read_address)
            );
          end if;

          request_msg := pop(read_queues.reply);
          reply_msg := new_msg;
          push_std_ulogic_vector(msg=>reply_msg, value=>got_data);
          reply(net=>net, request_msg=>request_msg, reply_msg=>reply_msg);
          delete(request_msg);
        end if;
      end process;


      ------------------------------------------------------------------------------
      handshake_slave_inst : entity work.handshake_slave
        generic map (
          stall_config => r_stall_config
        )
        port map (
          clk => clk,
          --
          ready => axi_lite_m2s.read.r.ready,
          valid => axi_lite_s2m.read.r.valid
        );


      ------------------------------------------------------------------------------
      r_protocol_checker_inst : entity common.axi_stream_protocol_checker
        generic map (
          data_width => got_data'length,
          user_width => axi_lite_s2m.read.r.resp'length,
          logger_name_suffix => " - axi_lite_read_master - R" & logger_name_suffix
        )
        port map (
          clk => clk,
          reset => reset,
          --
          ready => axi_lite_m2s.read.r.ready,
          valid => axi_lite_s2m.read.r.valid,
          data => got_data,
          user => axi_lite_s2m.read.r.resp
        );

    end block;

  end block;


  ------------------------------------------------------------------------------
  write_block : block
  begin

    ------------------------------------------------------------------------------
    aw_block : block
      signal data_is_valid : std_ulogic := '0';
      signal addr_target : u_unsigned(axi_lite_m2s.write.aw.addr'range) := (
        others => drive_invalid_value
      );
    begin

      ------------------------------------------------------------------------------
      set_aw : process
      begin
        while is_empty(write_queues.address) loop
          wait until rising_edge(clk);
        end loop;

        if reset then
          flush(write_queues.address);
        else
          addr_target(address_range) <= pop(write_queues.address);
          data_is_valid <= '1';

          wait until (
            ((axi_lite_s2m.write.aw.ready and axi_lite_m2s.write.aw.valid) or reset)
            and rising_edge(clk)
          );

          data_is_valid <= '0';
        end if;
      end process;


      ------------------------------------------------------------------------------
      handshake_master_inst : entity work.handshake_master
        generic map (
          stall_config => aw_stall_config
        )
        port map (
          clk => clk,
          --
          data_is_valid => data_is_valid,
          --
          ready => axi_lite_s2m.write.aw.ready,
          valid => axi_lite_m2s.write.aw.valid
        );

      -- Set the bus members only when bus is valid.
      axi_lite_m2s.write.aw.addr <=
        addr_target when axi_lite_m2s.write.aw.valid else (others => drive_invalid_value);


      ------------------------------------------------------------------------------
      aw_protocol_checker_inst : entity common.axi_stream_protocol_checker
        generic map (
          logger_name_suffix => " - axi_lite_write_master - AW" & logger_name_suffix
        )
        port map (
          clk => clk,
          --
          ready => axi_lite_s2m.write.aw.ready
        );

    end block;


    ------------------------------------------------------------------------------
    w_block : block
      signal data_is_valid : std_ulogic := '0';
      signal data_target : std_ulogic_vector(axi_lite_m2s.write.w.data'range) := (
        others => drive_invalid_value
      );
      constant strb_target : std_ulogic_vector(axi_lite_m2s.write.w.strb'range) := to_axi_lite_strb(
        data_width=>data_length(bus_handle)
      );
    begin

      ------------------------------------------------------------------------------
      set_w : process
      begin
        while is_empty(write_queues.data) loop
          wait until rising_edge(clk);
        end loop;

        if reset then
          flush(write_queues.data);
        else
          data_target(data_range) <= pop(write_queues.data);
          data_is_valid <= '1';

          wait until (
            ((axi_lite_s2m.write.w.ready and axi_lite_m2s.write.w.valid) or reset)
            and rising_edge(clk)
          );

          data_is_valid <= '0';
        end if;
      end process;


      ------------------------------------------------------------------------------
      handshake_master_inst : entity work.handshake_master
        generic map (
          stall_config => w_stall_config
        )
        port map (
          clk => clk,
          --
          data_is_valid => data_is_valid,
          --
          ready => axi_lite_s2m.write.w.ready,
          valid => axi_lite_m2s.write.w.valid
        );

      -- Set the bus members only when bus is valid.
      axi_lite_m2s.write.w.data <=
        data_target when axi_lite_m2s.write.w.valid else (others => drive_invalid_value);

      axi_lite_m2s.write.w.strb <=
        strb_target when axi_lite_m2s.write.w.valid else (others => drive_invalid_value);


      ------------------------------------------------------------------------------
      w_protocol_checker_inst : entity common.axi_stream_protocol_checker
        generic map (
          logger_name_suffix => " - axi_lite_write_master - W" & logger_name_suffix
        )
        port map (
          clk => clk,
          --
          ready => axi_lite_s2m.write.w.ready
        );

    end block;


    ------------------------------------------------------------------------------
    b_block : block
    begin

      ------------------------------------------------------------------------------
      check_b : process
        constant resp_message : string := (
          "axi_lite_read_master"
          & logger_name_suffix
          & " - B - 'resp' mismatch when writing address "
        );

        variable write_address : u_unsigned(address_range) := (others => '0');
        variable request_msg, reply_msg : msg_t := null_msg;
      begin
        wait until (
          ((axi_lite_m2s.write.b.ready and axi_lite_s2m.write.b.valid) or reset)
          and rising_edge(clk)
        );

        if reset then
          flush(write_queues.response);
          flush(write_queues.response_address);
          flush(write_queues.reply);
        else
          write_address := pop(write_queues.response_address);

          check_equal(
            axi_lite_s2m.write.b.resp,
            pop_std_ulogic_vector(write_queues.response),
            resp_message & to_string(write_address)
          );

          request_msg := pop(write_queues.reply);
          reply_msg := new_msg;
          reply(net=>net, request_msg=>request_msg, reply_msg=>reply_msg);
          delete(request_msg);
        end if;
      end process;


      ------------------------------------------------------------------------------
      handshake_slave_inst : entity work.handshake_slave
        generic map (
          stall_config => b_stall_config
        )
        port map (
          clk => clk,
          --
          ready => axi_lite_m2s.write.b.ready,
          valid => axi_lite_s2m.write.b.valid
        );


      ------------------------------------------------------------------------------
      b_protocol_checker_inst : entity common.axi_stream_protocol_checker
        generic map (
          data_width => axi_lite_s2m.write.b.resp'length,
          logger_name_suffix => " - axi_lite_write_master - B" & logger_name_suffix
        )
        port map (
          clk => clk,
          reset => reset,
          --
          ready => axi_lite_m2s.write.b.ready,
          valid => axi_lite_s2m.write.b.valid,
          data => axi_lite_s2m.write.b.resp
        );

    end block;

  end block;

end architecture;
