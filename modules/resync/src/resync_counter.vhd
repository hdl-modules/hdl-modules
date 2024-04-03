-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the hdl-modules project, a collection of reusable, high-quality,
-- peer-reviewed VHDL building blocks.
-- https://hdl-modules.com
-- https://github.com/hdl-modules/hdl-modules
-- -------------------------------------------------------------------------------------------------
-- Synchronize a counter value between two domains, using Gray coded values.
--
-- .. note::
--   This entity has a scoped constraint file that must be used.
--
-- Note that unlike e.g. :ref:`resync.resync_level`, it is safe to drive the input of this entity
-- with LUTs as well as FFs.
--
-- .. warning::
--   This entity assumes that the input counter value only increments and decrements in steps
--   of one.
--   Erroneous values can appear on the output if this is not followed.
--
-- This entity converts the binary input counter word to Gray code, resynchronizes it to the
-- output clock domain with an ``async_reg`` chain, and converts it back to a binary number.
--
-- A ``set_bus_skew`` constraint is a applied to the Gray coded bits that are sampled in the
-- output clock domain. That constraint imposes an upper limit for the difference in the
-- intra-word routing delay. This in turn means that the bits are always sampled coherently with
-- regards to changes on the input side. It is possible to sample while one bit is transitioning,
-- but the meta-stability protection of an ``async_reg`` chain will resolve that to a "clean"
-- ``'0'`` or ``'1'``.
-- Since the value is Gray coded, there will never be more than one bit transitioning for each value
-- change, which means that it does not matter if the transitioning value is resolved
-- to ``'0'`` or ``'1'``.
-- -------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library common;
use common.attribute_pkg.all;

library math;
use math.math_pkg.all;


entity resync_counter is
  generic (
    width : positive;
    -- Initial value for the output that will be set for a few cycles before the first input
    -- value has propagated.
    default_value   : u_unsigned(width - 1 downto 0) := (others => '0');
    -- Optional pipeline step on the output after Gray conversion
    pipeline_output : boolean := false;
    -- This CDC topology fails if the input counter jumps by more than one each clock cycle.
    -- Optionally disable the assertion that this never happens.
    assert_false_on_counter_jumps : boolean := true
  );
  port (
    clk_in : in std_ulogic;
    counter_in : in u_unsigned(default_value'range);
    --# {{}}
    clk_out : in std_ulogic;
    counter_out : out u_unsigned(default_value'range) := default_value
  );
end entity;

architecture a of resync_counter is

  signal counter_in_gray, counter_in_gray_p1, counter_out_gray : std_ulogic_vector(
    counter_in'range
  ) := to_gray(default_value);

  -- Make sure the input register is not optimized away and that logic is not moved around.
  attribute dont_touch of counter_in_gray : signal is "true";

  -- Maximize metastability recovery time for the FF chain.
  -- Same concept as in 'resync_level'.
  attribute async_reg of counter_in_gray_p1 : signal is "true";
  attribute async_reg of counter_out_gray : signal is "true";

begin

  ------------------------------------------------------------------------------
  clk_in_process : process
  begin
    wait until rising_edge(clk_in);

    if assert_false_on_counter_jumps then
      assert hamming_distance(to_gray(counter_in), counter_in_gray) <= 1
        report "Counter jumped by more than one";
    end if;

    counter_in_gray <= to_gray(counter_in);
  end process;


  ------------------------------------------------------------------------------
  clk_out_process : process
  begin
    wait until rising_edge(clk_out);

    counter_out_gray <= counter_in_gray_p1;
    counter_in_gray_p1 <= counter_in_gray;
  end process;


  ------------------------------------------------------------------------------
  pipeline_output_gen : if pipeline_output generate

    ------------------------------------------------------------------------------
    pipe : process
    begin
      wait until rising_edge(clk_out);

      counter_out <= from_gray(counter_out_gray);
    end process;

  else generate

    counter_out <= from_gray(counter_out_gray);

  end generate;

end architecture;
