-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the hdl-modules project, a collection of reusable, high-quality,
-- peer-reviewed VHDL building blocks.
-- https://hdl-modules.com
-- https://github.com/hdl-modules/hdl-modules
-- -------------------------------------------------------------------------------------------------
-- Types and convenience methods used to implement the BFMs.
-- -------------------------------------------------------------------------------------------------

library ieee;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;

library vunit_lib;
use vunit_lib.axi_slave_pkg.all;
use vunit_lib.axi_stream_pkg.all;
use vunit_lib.bus_master_pkg.all;
use vunit_lib.integer_array_pkg.all;
use vunit_lib.logger_pkg.all;
use vunit_lib.memory_pkg.all;
use vunit_lib.queue_pkg.all;

library osvvm;
use osvvm.RandomPkg.RandomPType;


package bfm_pkg is

  impure function concatenate_integer_arrays(
    base_array : integer_array_t;
    end_array : integer_array_t
  ) return integer_array_t;

  -- Some convenience methods for getting vectors of BFM/VC elements.
  -- When doing e.g.
  --   constant my_masters : axi_stream_master_vec_t(0 to 1) :=
  --     (others => new_axi_stream_master(...));
  -- works well in some simulators (GHDL), meaning that the function is evaluated once for each
  -- element of the vector. In e.g. Modelsim the function is only evaluated once, and all elements
  -- get the same value. Hence the need for this function.

  impure function get_new_queues(count : positive) return queue_vec_t;

  type memory_vec_t is array (integer range <>) of memory_t;
  impure function get_new_memories(count : positive) return memory_vec_t;

  type buffer_vec_t is array (integer range <>) of buffer_t;

  type axi_slave_vec_t is array (integer range <>) of axi_slave_t;

  type axi_stream_master_vec_t is array (integer range <>) of axi_stream_master_t;
  impure function get_new_axi_stream_masters(
    count : positive;
    data_width : positive;
    user_width : natural := 0;
    logger_name : string;
    stall_config : stall_config_t
  ) return axi_stream_master_vec_t;

  type axi_stream_slave_vec_t is array (integer range <>) of axi_stream_slave_t;
  impure function get_new_axi_stream_slaves(
    count : positive;
    data_width : positive;
    user_width : natural := 0;
    logger_name : string;
    stall_config : stall_config_t
  ) return axi_stream_slave_vec_t;

  type bus_master_vec_t is array (integer range <>) of bus_master_t;

end package;

package body bfm_pkg is

  ------------------------------------------------------------------------------
  -- Concatenate two arrays with data.
  -- Will copy contents to new array, will not deallocate either of the input arrays.
  impure function concatenate_integer_arrays(
    base_array : integer_array_t;
    end_array : integer_array_t
  ) return integer_array_t is
    constant total_length : natural := length(base_array) + length(end_array);
    variable result : integer_array_t := new_1d(
      length=>total_length,
      bit_width=>bit_width(base_array),
      is_signed=>is_signed(base_array)
    );
  begin
    assert bit_width(base_array) = bit_width(end_array)
      report "Can only concatenate similar arrays";
    assert is_signed(base_array) = is_signed(end_array)
      report "Can only concatenate similar arrays";

    assert height(base_array) = 1 report "Can only concatenate one dimensional arrays";
    assert height(end_array) = 1 report "Can only concatenate one dimensional arrays";

    assert depth(base_array) = 1 report "Can only concatenate one dimensional arrays";
    assert depth(end_array) = 1 report "Can only concatenate one dimensional arrays";

    for byte_idx in 0 to length(base_array) - 1 loop
      set(
        arr=>result,
        idx=>byte_idx,
        value=>get(arr=>base_array, idx=>byte_idx)
      );
    end loop;

    for byte_idx in 0 to length(end_array) - 1 loop
      set(
        arr=>result,
        idx=>length(base_array) + byte_idx,
        value=>get(arr=>end_array, idx=>byte_idx)
      );
    end loop;

    return result;
  end function;
  ------------------------------------------------------------------------------

  ------------------------------------------------------------------------------
  impure function get_new_queues(count : positive) return queue_vec_t is
    variable result : queue_vec_t(0 to count - 1) := (others => null_queue);
  begin
    for queue_idx in result'range loop
      result(queue_idx) := new_queue;
    end loop;
    return result;
  end function;
  ------------------------------------------------------------------------------

  ------------------------------------------------------------------------------
  impure function get_new_memories(count : positive) return memory_vec_t is
    variable result : memory_vec_t(0 to count - 1) := (others => null_memory);
  begin
    for memory_idx in result'range loop
      result(memory_idx) := new_memory;
    end loop;
    return result;
  end function;
  ------------------------------------------------------------------------------

  ------------------------------------------------------------------------------
  impure function get_new_axi_stream_masters(
    count : positive;
    data_width : positive;
    user_width : natural := 0;
    logger_name : string;
    stall_config : stall_config_t
  ) return axi_stream_master_vec_t is
    variable result : axi_stream_master_vec_t(0 to count - 1) := (others => null_axi_stream_master);
  begin
    for result_idx in result'range loop
      result(result_idx) := new_axi_stream_master(
        data_length => data_width,
        user_length => user_width,
        protocol_checker => new_axi_stream_protocol_checker(
          logger => get_logger(logger_name),
          data_length => data_width,
          user_length => user_width
        ),
        stall_config => stall_config
      );
    end loop;
    return result;
  end function;
  ------------------------------------------------------------------------------

  ------------------------------------------------------------------------------
  impure function get_new_axi_stream_slaves(
    count : positive;
    data_width : positive;
    user_width : natural := 0;
    logger_name : string;
    stall_config : stall_config_t
  ) return axi_stream_slave_vec_t is
    variable result : axi_stream_slave_vec_t(0 to count - 1) := (others => null_axi_stream_slave);
  begin
    for result_idx in result'range loop
      result(result_idx) := new_axi_stream_slave(
        data_length => data_width,
        user_length => user_width,
        protocol_checker => new_axi_stream_protocol_checker(
          logger => get_logger(logger_name),
          data_length => data_width,
          user_length => user_width
        ),
        stall_config => stall_config
      );
    end loop;
    return result;
  end function;
  ------------------------------------------------------------------------------

end package body;
