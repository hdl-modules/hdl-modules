-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the hdl-modules project, a collection of reusable, high-quality,
-- peer-reviewed VHDL building blocks.
-- https://hdl-modules.com
-- https://github.com/hdl-modules/hdl-modules
-- -------------------------------------------------------------------------------------------------
-- TODO
-- -------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

use work.trail_pkg.all;


entity trail_pipeline is
  generic (
    address_width : trail_address_width_t;
    data_width : trail_data_width_t;
    pipeline_operation_enable : boolean := false;
    pipeline_operation_address : boolean := false;
    pipeline_operation_write_enable : boolean := false;
    pipeline_operation_write_data : boolean := false;
    pipeline_response_enable : boolean := false;
    pipeline_response_status : boolean := false;
    pipeline_response_read_data : boolean := false
  );
  port (
    clk : in std_ulogic;
    --# {{}}
    operation : in trail_operation_t;
    pipelined_operation : out trail_operation_t := trail_operation_init;
    --# {{}}
    response : in trail_response_t;
    pipelined_response : out trail_response_t := trail_response_init
  );
end entity;

architecture a of trail_pipeline is

begin

  ------------------------------------------------------------------------------
  trail_pipeline_operation_inst : entity work.trail_pipeline_operation
    generic map (
      address_width => address_width,
      data_width => data_width,
      pipeline_enable => pipeline_operation_enable,
      pipeline_address => pipeline_operation_address,
      pipeline_write_enable => pipeline_operation_write_enable,
      pipeline_write_data => pipeline_operation_write_data
    )
    port map (
      clk => clk,
      --
      input_operation => operation,
      -- TODO rename port
      result_operation => pipelined_operation
    );


  ------------------------------------------------------------------------------
  trail_pipeline_response_inst : entity work.trail_pipeline_response
    generic map (
      data_width => data_width,
      pipeline_enable => pipeline_response_enable,
      pipeline_status => pipeline_response_status,
      pipeline_read_data => pipeline_response_read_data
    )
    port map (
      clk => clk,
      --
      input_response => response,
      result_response => pipelined_response
    );

end architecture;
