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
use ieee.numeric_std.all;

use work.trail_pkg.all;


entity trail_pipeline_operation is
  generic (
    address_width : trail_address_width_t;
    data_width : trail_data_width_t;
    pipeline_enable : boolean := false;
    pipeline_address : boolean := false;
    pipeline_write_enable : boolean := false;
    pipeline_write_data : boolean := false
  );
  port (
    clk : in std_ulogic;
    --# {{}}
    input_operation : in trail_operation_t;
    result_operation : out trail_operation_t := trail_operation_init
  );
end entity;

architecture a of trail_pipeline_operation is

  constant num_unaligned_address_bits : natural := trail_num_unaligned_address_bits(
    data_width=>data_width
  );

  constant should_pipeline_enable : boolean := (
    pipeline_enable or pipeline_address or pipeline_write_enable or pipeline_write_data
  );

  signal enable_p1 : std_ulogic := '0';
  signal address_p1 : u_unsigned(address_width - 1 downto num_unaligned_address_bits) := (
    others => '0'
  );
  signal write_enable_p1 : std_ulogic := '0';
  signal write_data_p1 : std_ulogic_vector(data_width - 1 downto 0) := (others => '0');

begin

  ------------------------------------------------------------------------------
  pipeline : process
  begin
    wait until rising_edge(clk);

    if should_pipeline_enable then
      enable_p1 <= input_operation.enable;
    end if;

    if pipeline_address then
      address_p1 <= input_operation.address(address_p1'range);
    end if;

    if pipeline_write_enable then
      write_enable_p1 <= input_operation.write_enable;
    end if;

    if pipeline_write_data then
      write_data_p1 <= input_operation.write_data(write_data_p1'range);
    end if;
  end process;


  ------------------------------------------------------------------------------
  assign : process(all)
  begin
    result_operation <= input_operation;

    if should_pipeline_enable then
      result_operation.enable <= enable_p1;
    end if;

    if pipeline_address then
      result_operation.address(address_p1'range) <= address_p1;
    end if;

    if pipeline_write_enable then
      result_operation.write_enable <= write_enable_p1;
    end if;

    if pipeline_write_data then
      result_operation.write_data(write_data_p1'range) <= write_data_p1;
    end if;
  end process;

end architecture;
