-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the hdl-modules project, a collection of reusable, high-quality,
-- peer-reviewed VHDL building blocks.
-- https://hdl-modules.com
-- https://github.com/hdl-modules/hdl-modules
-- -------------------------------------------------------------------------------------------------
-- Truncate a numeric value by removing LSBs and rounding the result.
--
--
-- Rounding details
-- ________________
--
-- The truncation can be seen as removing a number of fractional bits from a fixed-point number.
-- If the fractional value is greater than or equal to 0.5, 1 is added to the result.
-- I.e. rounding towards positive infinity.
--
-- If the input value is already at the maximum value, and the fractional value is such that the
-- rounding should happen, the result is saturated and the ``result_is_saturated`` signal
-- will read as 1.
--
--
-- Alternative approach
-- ____________________
--
-- One could sign-extend the input value with one guard bit, add the 0.5 unconditionally and
-- instantiate :ref:`math.saturate_signed` on the result.
-- The :ref:`netlist build <math.truncate_round_signed.resource_utilization>` showed,
-- however, that this alternative approach results in more LUTs and longer critical path,
-- for both wide and narrow words.
-- -------------------------------------------------------------------------------------------------

library ieee;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;

library common;
use common.types_pkg.all;

use work.math_pkg.all;


entity truncate_round_signed is
  generic (
    input_width : positive;
    result_width : positive range 1 to input_width;
    enable_output_register : boolean := false
  );
  port(
    clk : in std_ulogic;
    --# {{}}
    input_valid : in std_ulogic := '0';
    input_value : in u_signed(input_width - 1 downto 0);
    --# {{}}
    result_valid : out std_ulogic := '0';
    result_value : out u_signed(result_width - 1 downto 0) := (others => '0');
    result_is_saturated : out std_ulogic := '0'
  );
end entity;

architecture a of truncate_round_signed is

  signal is_saturated : std_ulogic := '0';
  signal result : u_signed(result_value'range) := (others => '0');

begin

  ------------------------------------------------------------------------------
  passthrough_or_not_gen : if input_width = result_width generate

    result <= input_value;


  ------------------------------------------------------------------------------
  else generate
    constant max_result : signed(result_value'range) := get_max_signed(num_bits=>result_width);

    constant num_lsb_to_remove : positive := input_width - result_width;
    constant point_five_index : natural := num_lsb_to_remove - 1;

    signal input_value_truncated : signed(result_width - 1 downto 0) := (others => '0');
    signal point_five : natural range 0 to 1 := 0;
  begin

    input_value_truncated <= input_value(input_value'high downto num_lsb_to_remove);
    point_five <= to_int(input_value(point_five_index));


    ------------------------------------------------------------------------------
    assign : process(all)
    begin
      if input_value_truncated = max_result and point_five = 1 then
        result <= max_result;
        is_saturated <= '1';
      else
        result <= input_value_truncated + point_five;
        is_saturated <= '0';
      end if;

      -- Alternative formulation of
      --   value_to_add := to_int(
      --     input_value(point_five_index) and to_sl(input_value_truncated /= max_result)
      --   );
      --   result <= input_value_truncated + value_to_add;
      -- gave one less LUT but 6->9 critical path.
      -- But that is if 'is_saturated' is not needed.
    end process;

  end generate;


  ------------------------------------------------------------------------------
  output_register_gen : if enable_output_register generate

    result_valid <= input_valid when rising_edge(clk);
    result_value <= result when rising_edge(clk);
    result_is_saturated <= is_saturated when rising_edge(clk);


  ------------------------------------------------------------------------------
  else generate

    result_valid <= input_valid;
    result_value <= result;
    result_is_saturated <= is_saturated;

  end generate;

end architecture;
