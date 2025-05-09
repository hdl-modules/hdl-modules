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

  -- Handle for AXI-Lite master BFM.
  -- All fields are private, do not use directly.
  type bfm_master_t is record
    p_bus_handle : bus_master_t;
    p_ar_stall_config : stall_configuration_t;
    p_r_stall_config : stall_configuration_t;
    p_aw_stall_config : stall_configuration_t;
    p_w_stall_config : stall_configuration_t;
    p_b_stall_config : stall_configuration_t;
    p_logger_name_suffix : string;
  end record;
  constant null_bus_master : bus_master_t := (
    p_actor => null_actor,
    p_data_length => 0,
    p_address_length => 0,
    p_byte_length => 0,
    p_logger => null_logger
  );
  constant null_bfm_master : bfm_master_t := (
    p_bus_handle => null_bus_master,
    p_logger_name_suffix => "",
    others => zero_stall_configuration
  );

  -- Create new handle for AXI-Lite master BFM.
  impure function new_bfm_master(
    bus_handle : bus_master_t := register_bus_master;
    logger_name_suffix : string := "";
    ar_stall_config : stall_configuration_t := default_address_stall_config;
    r_stall_config : stall_configuration_t := default_data_stall_config;
    aw_stall_config : stall_configuration_t := default_address_stall_config;
    w_stall_config : stall_configuration_t := default_data_stall_config;
    b_stall_config : stall_configuration_t := default_data_stall_config
  ) return bfm_master_t;
  -- Deferred constant to avoid compiler warning.
  constant default_bfm_master : bfm_master_t;

  -- Wait until all previously queued operations have been completed.
  procedure wait_until_bfm_idle(
    signal net : inout network_t;
    constant bus_handle : bus_master_t
  );
  procedure wait_until_bfm_idle(
    signal net : inout network_t;
    constant bfm_master : bfm_master_t := default_bfm_master
  );

  -- Read and check a value on the bus.
  -- This procedure is non-blocking, meaning it will queue up the operation and then
  -- return immediately.
  procedure check_bfm(
    signal net : inout network_t;
    constant index : natural;
    constant data : register_t;
    constant response : axi_lite_resp_t := axi_lite_resp_okay;
    constant bus_handle : bus_master_t
  );
  procedure check_bfm(
    signal net : inout network_t;
    constant index : natural;
    constant data : register_t;
    constant response : axi_lite_resp_t := axi_lite_resp_okay;
    constant bfm_master : bfm_master_t := default_bfm_master
  );

  -- Read and check a value on the bus.
  -- This procedure is blocking, meaning it will perform the operation and return only when it
  -- is fully finished.
  procedure check_await_bfm(
    signal net : inout network_t;
    constant index : natural;
    constant data : register_t;
    constant response : axi_lite_resp_t := axi_lite_resp_okay;
    constant bus_handle : bus_master_t
  );
  procedure check_await_bfm(
    signal net : inout network_t;
    constant index : natural;
    constant data : register_t;
    constant response : axi_lite_resp_t := axi_lite_resp_okay;
    constant bfm_master : bfm_master_t := default_bfm_master
  );

  -- Write a value on the bus.
  -- This procedure is non-blocking, meaning it will queue up the operation and then
  -- return immediately.
  procedure write_bfm(
    signal net : inout network_t;
    constant index : natural;
    constant data : register_t;
    constant response : axi_lite_resp_t := axi_lite_resp_okay;
    constant bus_handle : bus_master_t
  );
  procedure write_bfm(
    signal net : inout network_t;
    constant index : natural;
    constant data : register_t;
    constant response : axi_lite_resp_t := axi_lite_resp_okay;
    constant bfm_master : bfm_master_t := default_bfm_master
  );

  -- Write a value on the bus.
  -- This procedure is blocking, meaning it will perform the operation and return only when it
  -- is fully finished.
  procedure write_await_bfm(
    signal net : inout network_t;
    constant index : natural;
    constant data : register_t;
    constant response : axi_lite_resp_t := axi_lite_resp_okay;
    constant bus_handle : bus_master_t
  );
  procedure write_await_bfm(
    signal net : inout network_t;
    constant index : natural;
    constant data : register_t;
    constant response : axi_lite_resp_t := axi_lite_resp_okay;
    constant bfm_master : bfm_master_t := default_bfm_master
  );

  constant bfm_check_msg : msg_type_t := new_msg_type("check bfm");
  constant bfm_write_msg : msg_type_t := new_msg_type("write bfm");
  constant bfm_read_count_msg : msg_type_t := new_msg_type("read count bfm");
  constant bfm_write_count_msg : msg_type_t := new_msg_type("write count bfm");

end package;

package body axi_lite_bfm_pkg is

  impure function new_bfm_master(
    bus_handle : bus_master_t := register_bus_master;
    logger_name_suffix : string := "";
    ar_stall_config : stall_configuration_t := default_address_stall_config;
    r_stall_config : stall_configuration_t := default_data_stall_config;
    aw_stall_config : stall_configuration_t := default_address_stall_config;
    w_stall_config : stall_configuration_t := default_data_stall_config;
    b_stall_config : stall_configuration_t := default_data_stall_config
  ) return bfm_master_t is
  begin
    return (
      p_bus_handle => bus_handle,
      p_ar_stall_config => ar_stall_config,
      p_r_stall_config => r_stall_config,
      p_aw_stall_config => aw_stall_config,
      p_w_stall_config => w_stall_config,
      p_b_stall_config => b_stall_config,
      p_logger_name_suffix => logger_name_suffix
    );
  end function;

  -- Deferred constant.
  constant default_bfm_master : bfm_master_t := new_bfm_master(bus_handle=>register_bus_master);

  procedure wait_until_bfm_idle(
    signal net : inout network_t;
    constant bus_handle : bus_master_t
  ) is
  begin
    wait_until_idle(net=>net, bus_handle=>bus_handle);
  end procedure;

  procedure wait_until_bfm_idle(
    signal net : inout network_t;
    constant bfm_master : bfm_master_t := default_bfm_master
  ) is
  begin
    wait_until_idle(net=>net, bus_handle=>bfm_master.p_bus_handle);
  end procedure;

  -- Internal procedure.
  procedure push_to_bfm(
    signal net : inout network_t;
    constant index : natural;
    constant data : register_t;
    constant response : axi_lite_resp_t;
    constant bus_handle : bus_master_t;
    constant msg_type : msg_type_t;
    variable reference : inout bus_reference_t
  ) is
    constant data_length_bytes : positive := data_length(bus_handle) / 8;
    constant address : std_logic_vector := to_address(
      bus_handle=>bus_handle, address=>data_length_bytes * index
    );
    alias request_msg : msg_t is reference;
  begin
    request_msg := new_msg(msg_type);

    push_std_ulogic_vector(request_msg, address);
    push_std_ulogic_vector(request_msg, data);
    push_std_ulogic_vector(request_msg, response);

    send(net, bus_handle.p_actor, request_msg);
  end procedure;

  procedure check_bfm(
    signal net : inout network_t;
    constant index : natural;
    constant data : register_t;
    constant response : axi_lite_resp_t := axi_lite_resp_okay;
    constant bus_handle : bus_master_t
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

  procedure check_bfm(
    signal net : inout network_t;
    constant index : natural;
    constant data : register_t;
    constant response : axi_lite_resp_t := axi_lite_resp_okay;
    constant bfm_master : bfm_master_t := default_bfm_master
  ) is
  begin
    check_bfm(
      net=>net,
      index=>index,
      data=>data,
      response=>response,
      bus_handle=>bfm_master.p_bus_handle
    );
  end procedure;

  procedure check_await_bfm(
    signal net : inout network_t;
    constant index : natural;
    constant data : register_t;
    constant response : axi_lite_resp_t := axi_lite_resp_okay;
    constant bus_handle : bus_master_t
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

  procedure check_await_bfm(
    signal net : inout network_t;
    constant index : natural;
    constant data : register_t;
    constant response : axi_lite_resp_t := axi_lite_resp_okay;
    constant bfm_master : bfm_master_t := default_bfm_master
  ) is
  begin
    check_await_bfm(
      net=>net,
      index=>index,
      data=>data,
      response=>response,
      bus_handle=>bfm_master.p_bus_handle
    );
  end procedure;

  procedure write_bfm(
    signal net : inout network_t;
    constant index : natural;
    constant data : register_t;
    constant response : axi_lite_resp_t := axi_lite_resp_okay;
    constant bus_handle : bus_master_t
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

  procedure write_bfm(
    signal net : inout network_t;
    constant index : natural;
    constant data : register_t;
    constant response : axi_lite_resp_t := axi_lite_resp_okay;
    constant bfm_master : bfm_master_t := default_bfm_master
  ) is
  begin
    write_bfm(
      net=>net,
      index=>index,
      data=>data,
      response=>response,
      bus_handle=>bfm_master.p_bus_handle
    );
  end procedure;

  procedure write_await_bfm(
    signal net : inout network_t;
    constant index : natural;
    constant data : register_t;
    constant response : axi_lite_resp_t := axi_lite_resp_okay;
    constant bus_handle : bus_master_t
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

  procedure write_await_bfm(
    signal net : inout network_t;
    constant index : natural;
    constant data : register_t;
    constant response : axi_lite_resp_t := axi_lite_resp_okay;
    constant bfm_master : bfm_master_t := default_bfm_master
  ) is
  begin
    write_await_bfm(
      net=>net,
      index=>index,
      data=>data,
      response=>response,
      bus_handle=>bfm_master.p_bus_handle
    );
  end procedure;

end package body;
