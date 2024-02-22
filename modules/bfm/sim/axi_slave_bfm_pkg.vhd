-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the hdl-modules project, a collection of reusable, high-quality,
-- peer-reviewed VHDL building blocks.
-- https://hdl-modules.com
-- https://github.com/hdl-modules/hdl-modules
-- -------------------------------------------------------------------------------------------------
-- Types and convenience methods for working with VUnit ``axi_slave_t``.
-- Used by some BFMs.
-- -------------------------------------------------------------------------------------------------

library vunit_lib;
use vunit_lib.axi_slave_pkg.axi_slave_t;
use vunit_lib.com_types_pkg.null_actor;
use vunit_lib.logger_pkg.null_logger;
use vunit_lib.memory_pkg.null_memory;


package axi_slave_bfm_pkg is

  type axi_slave_vec_t is array (integer range <>) of axi_slave_t;

  -- Perhaps this should be commited to VUnit's axi_slave_pkg (under the name null_axi_slave)?
  constant axi_slave_init : axi_slave_t := (
    p_initial_address_fifo_depth => 1,
    p_initial_write_response_fifo_depth => 1,
    p_initial_check_4kbyte_boundary => false,
    p_initial_address_stall_probability => 0.0,
    p_initial_data_stall_probability => 0.0,
    p_initial_write_response_stall_probability => 0.0,
    p_initial_min_response_latency => 0 fs,
    p_initial_max_response_latency => 0 fs,
    p_actor => null_actor,
    p_memory => null_memory,
    p_logger => null_logger
  );

end package;
