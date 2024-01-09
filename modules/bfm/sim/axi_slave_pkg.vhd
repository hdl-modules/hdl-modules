-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the hdl-modules project, a collection of reusable, high-quality,
-- peer-reviewed VHDL building blocks.
-- https://hdl-modules.com
-- https://github.com/hdl-modules/hdl-modules
-- -------------------------------------------------------------------------------------------------
-- Package with an init value for the ``axi_slave_t`` type.
-- -------------------------------------------------------------------------------------------------

library vunit_lib;
use vunit_lib.axi_slave_pkg.all;
use vunit_lib.memory_pkg.all;
context vunit_lib.com_context;
context vunit_lib.vunit_context;


package axi_slave_pkg is

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
