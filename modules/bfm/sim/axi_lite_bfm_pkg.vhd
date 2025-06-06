-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the hdl-modules project, a collection of reusable, high-quality,
-- peer-reviewed VHDL building blocks.
-- https://hdl-modules.com
-- https://github.com/hdl-modules/hdl-modules
-- -------------------------------------------------------------------------------------------------
-- Types and functions for the custom AXI-Lite BFM in hdl-modules (:ref:`bfm.axi_lite_master_bfm`).
-- It is only used by this BFM, not the other AXI-Lite BFMs which are wrappers around VUnit VCs.
--
-- .. warning::
--   While this file and this eco-system is stable and usable, it is in a state of development.
--   Expect API changes in the future.
-- -------------------------------------------------------------------------------------------------

library ieee;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;

library vunit_lib;
use vunit_lib.bus_master_pkg.all;
use vunit_lib.com_pkg.all;
use vunit_lib.com_types_pkg.all;
use vunit_lib.logger_pkg.all;

library axi_lite;
use axi_lite.axi_lite_pkg.all;

library register_file;
use register_file.register_file_pkg.register_t;
use register_file.register_operations_pkg.register_bus_master;

use work.axi_bfm_pkg.all;
use work.stall_bfm_pkg.all;


package axi_lite_bfm_pkg is

  -- Wait until all previous operations have been fully completed.
  procedure wait_until_bfm_idle(
    signal net : inout network_t;
    bus_handle : bus_master_t := register_bus_master
  );

  -- Read and check a value on the bus.
  -- This procedure is non-blocking, meaning it will queue up the operation and then
  -- return immediately.
  procedure check_bfm(
    signal net : inout network_t;
    index : natural;
    data : register_t;
    response : axi_lite_resp_t := axi_lite_resp_okay;
    bus_handle : bus_master_t := register_bus_master
  );
  procedure check_bfm(
    signal net : inout network_t;
    address : u_unsigned;
    data : register_t;
    response : axi_lite_resp_t := axi_lite_resp_okay;
    bus_handle : bus_master_t := register_bus_master
  );

  -- Read and check a value on the bus.
  -- This procedure is blocking, meaning it will perform the operation and return only when it
  -- is fully finished.
  procedure check_await_bfm(
    signal net : inout network_t;
    index : natural;
    data : register_t;
    response : axi_lite_resp_t := axi_lite_resp_okay;
    bus_handle : bus_master_t := register_bus_master
  );

  -- Write a value on the bus.
  -- This procedure is non-blocking, meaning it will queue up the operation and then
  -- return immediately.
  procedure write_bfm(
    signal net : inout network_t;
    address : u_unsigned;
    data : register_t;
    response : axi_lite_resp_t := axi_lite_resp_okay;
    bus_handle : bus_master_t := register_bus_master
  );
  procedure write_bfm(
    signal net : inout network_t;
    index : natural;
    data : register_t;
    response : axi_lite_resp_t := axi_lite_resp_okay;
    bus_handle : bus_master_t := register_bus_master
  );

  -- Write a value on the bus.
  -- This procedure is blocking, meaning it will perform the operation and return only when it
  -- is fully finished.
  procedure write_await_bfm(
    signal net : inout network_t;
    index : natural;
    data : register_t;
    response : axi_lite_resp_t := axi_lite_resp_okay;
    bus_handle : bus_master_t := register_bus_master
  );

  constant bfm_check_msg : msg_type_t := new_msg_type("check bfm");
  constant bfm_write_msg : msg_type_t := new_msg_type("write bfm");

end package;

package body axi_lite_bfm_pkg is

  procedure wait_until_bfm_idle(
    signal net : inout network_t;
    bus_handle : bus_master_t := register_bus_master
  ) is
  begin
    wait_until_idle(net=>net, bus_handle=>bus_handle);
  end procedure;

  -- Internal procedure.
  procedure push_to_bfm(
    signal net : inout network_t;
    address : std_ulogic_vector;
    data : register_t;
    response : axi_lite_resp_t;
    bus_handle : bus_master_t;
    msg_type : msg_type_t;
    reference : inout bus_reference_t
  ) is
    alias request_msg : msg_t is reference;
  begin
    request_msg := new_msg(msg_type);

    push_std_ulogic_vector(request_msg, address);
    push_std_ulogic_vector(request_msg, data);
    push_std_ulogic_vector(request_msg, response);

    send(net, bus_handle.p_actor, request_msg);
  end procedure;

  -- Internal procedure.
  procedure push_to_bfm(
    signal net : inout network_t;
    index : natural;
    data : register_t;
    response : axi_lite_resp_t;
    bus_handle : bus_master_t;
    msg_type : msg_type_t;
    reference : inout bus_reference_t
  ) is
    constant data_length_bytes : positive := data_length(bus_handle) / 8;
    constant address : std_ulogic_vector := to_address(
      bus_handle=>bus_handle, address=>data_length_bytes * index
    );
  begin
    push_to_bfm(
      net=>net,
      address=>address,
      data=>data,
      response=>response,
      bus_handle=>bus_handle,
      msg_type=>msg_type,
      reference=>reference
    );
  end procedure;

  procedure check_bfm(
    signal net : inout network_t;
    address : u_unsigned;
    data : register_t;
    response : axi_lite_resp_t := axi_lite_resp_okay;
    bus_handle : bus_master_t := register_bus_master
  ) is
    variable unused_reference : bus_reference_t := null_msg;
  begin
    push_to_bfm(
      net=>net,
      address=>std_ulogic_vector(address),
      data=>data,
      response=>response,
      bus_handle=>bus_handle,
      reference=>unused_reference,
      msg_type=>bfm_check_msg
    );
  end procedure;

  procedure check_bfm(
    signal net : inout network_t;
    index : natural;
    data : register_t;
    response : axi_lite_resp_t := axi_lite_resp_okay;
    bus_handle : bus_master_t := register_bus_master
  ) is
    variable unused_reference : bus_reference_t := null_msg;
  begin
    push_to_bfm(
      net=>net,
      index=>index,
      data=>data,
      response=>response,
      bus_handle=>bus_handle,
      reference=>unused_reference,
      msg_type=>bfm_check_msg
    );
  end procedure;

  procedure check_await_bfm(
    signal net : inout network_t;
    index : natural;
    data : register_t;
    response : axi_lite_resp_t := axi_lite_resp_okay;
    bus_handle : bus_master_t := register_bus_master
  ) is
    variable reference : bus_reference_t := null_msg;
    variable unused_reply_data : std_ulogic_vector(data_length(bus_handle) - 1 downto 0) := (
      others => '0'
    );
  begin
    push_to_bfm(
      net=>net,
      index=>index,
      data=>data,
      response=>response,
      bus_handle=>bus_handle,
      reference=>reference,
      msg_type=>bfm_check_msg
    );
    await_read_bus_reply(net=>net, reference=>reference, data=>unused_reply_data);
  end procedure;

  procedure write_bfm(
    signal net : inout network_t;
    address : u_unsigned;
    data : register_t;
    response : axi_lite_resp_t := axi_lite_resp_okay;
    bus_handle : bus_master_t := register_bus_master
  ) is
    variable unused_reference : bus_reference_t := null_msg;
  begin
    push_to_bfm(
      net=>net,
      address=>std_ulogic_vector(address),
      data=>data,
      response=>response,
      bus_handle=>bus_handle,
      reference=>unused_reference,
      msg_type=>bfm_write_msg
    );
  end procedure;

  procedure write_bfm(
    signal net : inout network_t;
    index : natural;
    data : register_t;
    response : axi_lite_resp_t := axi_lite_resp_okay;
    bus_handle : bus_master_t := register_bus_master
  ) is
    variable unused_reference : bus_reference_t := null_msg;
  begin
    push_to_bfm(
      net=>net,
      index=>index,
      data=>data,
      response=>response,
      bus_handle=>bus_handle,
      reference=>unused_reference,
      msg_type=>bfm_write_msg
    );
  end procedure;

  procedure write_await_bfm(
    signal net : inout network_t;
    index : natural;
    data : register_t;
    response : axi_lite_resp_t := axi_lite_resp_okay;
    bus_handle : bus_master_t := register_bus_master
  ) is
    variable reference : bus_reference_t := null_msg;

    -- Like 'await_read_bus_reply' but simpler.
    procedure await_reply is
      variable reply_msg : msg_t := null_msg;
    begin
      receive_reply(net=>net, request_msg=>reference, reply_msg=>reply_msg);
      delete(reference);
      delete(reply_msg);
    end procedure;
  begin
    push_to_bfm(
      net=>net,
      index=>index,
      data=>data,
      response=>response,
      bus_handle=>bus_handle,
      reference=>reference,
      msg_type=>bfm_write_msg
    );
    await_reply;
  end procedure;

end package body;
