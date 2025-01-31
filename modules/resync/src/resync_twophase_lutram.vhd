-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the hdl-modules project, a collection of reusable, high-quality,
-- peer-reviewed VHDL building blocks.
-- https://hdl-modules.com
-- https://github.com/hdl-modules/hdl-modules
-- -------------------------------------------------------------------------------------------------
-- Free-running two-phase handshaking CDC for resynchronizing a vector of correlated data from one
-- clock domain to another.
-- Very similar to :ref:`resync.resync_twophase` but uses LUTRAM instead of registers,
-- making it extremely
-- :ref:`resource efficient <resync.resync_twophase_lutram.resource_utilization>`.
--
-- .. warning::
--   This entity is in active development.
--   Using it is NOT recommended at this point.
--
-- .. note::
--   This entity has a scoped constraint file
--   `resync_twophase_lutram.tcl <https://github.com/hdl-modules/hdl-modules/blob/main/modules/resync/scoped_constraints/resync_twophase_lutram.tcl>`__
--   that must be used for proper operation.
--   See :ref:`here <scoped_constraints>` for instructions.
--
-- .. figure:: resync_twophase_lutram.png
-- -------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

library common;
use common.attribute_pkg.all;
use common.types_pkg.all;


entity resync_twophase_lutram is
  generic (
    width : positive;
    -- Initial value for the output that will be set for a few cycles before the first input
    -- value has propagated.
    default_value : std_ulogic_vector(width - 1 downto 0) := (others => '0');
    -- Optionally sample the LUTRAM output in registers before passing it on.
    enable_output_register : boolean := false
  );
  port (
    clk_in : in std_ulogic;
    data_in : in std_ulogic_vector(default_value'range);
    --# {{}}
    clk_out : in std_ulogic;
    data_out : out std_ulogic_vector(default_value'range) := default_value
  );
end entity;

architecture a of resync_twophase_lutram is

  signal input_level_m1, input_level, input_level_not_p1, input_level_not : std_ulogic := '0';
  signal output_level_m1, output_level, output_level_p1 : std_ulogic := '0';

  -- These two feed async_reg chains, and it is absolutely crucial that they are driven by FFs.
  -- So place attribute on them so that build tool does not optimize/modify anything.
  attribute dont_touch of input_level_not_p1 : signal is "true";
  attribute dont_touch of output_level_p1 : signal is "true";

  -- Ensure FFs are not optimized/modified, and placed in the same slice to minimize MTBF.
  attribute async_reg of input_level_m1 : signal is "true";
  attribute async_reg of input_level : signal is "true";
  attribute async_reg of output_level_m1 : signal is "true";
  attribute async_reg of output_level : signal is "true";

  constant memory_depth : positive := 2;
  type memory_t is array (0 to memory_depth - 1) of std_ulogic_vector(data_in'range);

  signal memory : memory_t := (others => default_value);
  signal write_address, read_address : natural range memory'range := 0;
  signal read_data : std_ulogic_vector(data_in'range) := (others => '0');

  -- Apply attribute so the memory gets implemented in LUTRAM.
  attribute ram_style of memory : signal is to_attribute(ram_style_distributed);
  attribute dont_touch of memory : signal is "true";
  -- We apply constraints to this signal, so place attribute on it so that build tool does
  -- not optimize/modify anything.
  attribute dont_touch of read_data : signal is "true";

begin

  ------------------------------------------------------------------------------
  handle_input : process
  begin
    wait until rising_edge(clk_in);

    if input_level = input_level_not_p1 then
      memory(write_address) <= data_in;
    end if;

    input_level_not_p1 <= input_level_not;

    -- CDC path into async_reg chain.
    input_level <= input_level_m1;
    input_level_m1 <= output_level_p1;
  end process;

  input_level_not <= not input_level;

  write_address <= to_int(input_level_not);


  ------------------------------------------------------------------------------
  handle_output : process
  begin
    wait until rising_edge(clk_out);

    output_level_p1 <= output_level;

    -- CDC path into async_reg chain.
    output_level <= output_level_m1;
    output_level_m1 <= input_level_not_p1;
  end process;

  read_address <= to_int(output_level);

  read_data <= memory(read_address);


  ------------------------------------------------------------------------------
  assign_output : if enable_output_register generate

    ------------------------------------------------------------------------------
    sample_output : process
    begin
      wait until rising_edge(clk_out);

      data_out <= read_data;
    end process;


  ------------------------------------------------------------------------------
  else generate

    data_out <= read_data;

  end generate;

end architecture;
