-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the hdl-modules project, a collection of reusable, high-quality,
-- peer-reviewed VHDL building blocks.
-- https://hdl-modules.com
-- https://github.com/hdl-modules/hdl-modules
-- -------------------------------------------------------------------------------------------------
-- Simple CDC where a ``data`` word, qualified with a ``valid`` signal, is resynchronized from
-- one clock domain to another.
-- The ``input_valid`` must be pulsed for one clock cycle when the ``input_data`` is valid,
-- which will result in one ``result_valid`` pulse once data has propagated.
--
-- .. figure:: resync_rarely_valid_lutram.png
--
-- Very similar to :ref:`resync.resync_rarely_valid` but uses LUTRAM instead of registers,
-- making it extremely
-- :ref:`resource efficient <resync.resync_rarely_valid_lutram.resource_utilization>`.
--
-- See :ref:`resync.resync_rarely_valid` for further information and some usage instructions.
--
-- .. warning::
--   This entity is in active development.
--   Using it is NOT recommended at this point.
--
-- .. note::
--   This entity has a scoped constraint file
--   `resync_rarely_valid_lutram.tcl <https://github.com/hdl-modules/hdl-modules/blob/main/modules/resync/scoped_constraints/resync_rarely_valid_lutram.tcl>`__
--   that must be used for proper operation.
--   See :ref:`here <scoped_constraints>` for instructions.
--
-- .. note::
--   TODO:
--
--   * Add constraints.
--   * Investigate synthesis bug. Outputs are driven to ground through LUTs.
--   * Run post synthesis simulation.
--   * Test on hardware.
-- -------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

library common;
use common.attribute_pkg.all;
use common.types_pkg.all;


entity resync_rarely_valid_lutram is
  generic (
    data_width : positive;
    -- Optionally sample the LUTRAM output in registers before passing it on.
    enable_output_register : boolean := false
  );
  port (
    input_clk : in std_ulogic;
    input_valid : in std_ulogic;
    input_data : in std_ulogic_vector(data_width - 1 downto 0);
    --# {{}}
    result_clk : in std_ulogic;
    result_valid : out std_ulogic := '0';
    result_data : out std_ulogic_vector(data_width - 1 downto 0) := (others => '0')
  );
end entity;

architecture a of resync_rarely_valid_lutram is

  signal input_level_next, input_level : std_ulogic := '0';
  signal output_level_m1, output_level, output_level_p1 : std_ulogic := '0';

  -- This feeds an async_reg, and it is absolutely crucial that it is driven by a FF.
  -- So place attribute so that build tool does not optimize/modify anything.
  attribute dont_touch of input_level : signal is "true";

  -- Ensure FFs are not optimized/modified, and placed in the same slice to minimize MTBF.
  attribute async_reg of output_level_m1 : signal is "true";
  attribute async_reg of output_level : signal is "true";

  constant memory_depth : positive := 2;
  type memory_t is array (0 to memory_depth - 1) of std_ulogic_vector(input_data'range);

  signal memory : memory_t := (others => (others => '0'));
  signal write_address, read_address : natural range memory'range := 0;

  signal read_valid : std_ulogic := '0';
  signal read_data : std_ulogic_vector(result_data'range) := (others => '0');

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
    wait until rising_edge(input_clk);

    if input_valid then
      memory(write_address) <= input_data;
      input_level <= input_level_next;
    end if;
  end process;

  input_level_next <= not input_level;

  write_address <= to_int(input_level_next);


  ------------------------------------------------------------------------------
  handle_output : process
  begin
    wait until rising_edge(result_clk);

    output_level_p1 <= output_level;

    -- CDC path into async_reg chain.
    output_level <= output_level_m1;
    output_level_m1 <= input_level;
  end process;

  read_valid <= to_sl(output_level /= output_level_p1);

  read_address <= to_int(output_level);
  read_data <= memory(read_address);


  ------------------------------------------------------------------------------
  assign_output : if enable_output_register generate

    ------------------------------------------------------------------------------
    sample_output : process
    begin
      wait until rising_edge(result_clk);

      result_valid <= read_valid;
      result_data <= read_data;
    end process;

  ------------------------------------------------------------------------------
  else generate

    result_valid <= read_valid;
    result_data <= read_data;

  end generate;

end architecture;
