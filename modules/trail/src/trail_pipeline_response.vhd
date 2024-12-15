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


entity trail_pipeline_response is
  generic (
    data_width : trail_data_width_t;
    pipeline_enable : boolean := false;
    pipeline_status : boolean := false;
    pipeline_read_data : boolean := false
  );
  port (
    clk : in std_ulogic;
    --# {{}}
    input_response : in trail_response_t;
    result_response : out trail_response_t := trail_response_init
  );
end entity;

architecture a of trail_pipeline_response is

  constant should_pipeline_enable : boolean := (
    pipeline_enable or pipeline_status or pipeline_read_data
  );

  signal enable_p1 : std_ulogic := '0';
  signal status_p1 : trail_response_status_t := trail_response_status_okay;
  signal read_data_p1 : std_ulogic_vector(data_width - 1 downto 0) := (others => '0');

begin

  ------------------------------------------------------------------------------
  pipeline : process
  begin
    wait until rising_edge(clk);

    if should_pipeline_enable then
      enable_p1 <= input_response.enable;
    end if;

    if pipeline_status then
      status_p1 <= input_response.status;
    end if;

    if pipeline_read_data then
      read_data_p1 <= input_response.read_data(read_data_p1'range);
    end if;
  end process;


  ------------------------------------------------------------------------------
  assign : process(all)
  begin
    result_response <= input_response;

    if should_pipeline_enable then
      result_response.enable <= enable_p1;
    end if;

    if pipeline_status then
      result_response.status <= status_p1;
    end if;

    if pipeline_read_data then
      result_response.read_data(read_data_p1'range) <= read_data_p1;
    end if;
  end process;

end architecture;
