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
-- The result value will be the closest integer value to the fractional input value.
-- If the value is exactly in the middle between two integers, the result will be
--
-- 1. The integer value of the two that is even, if ``convergent_rounding`` is true.
-- 2. The integer value of the two that is closest to positive infinity,
--    if ``convergent_rounding`` is false.
--
-- Convergent rounding is the default rounding mode used in IEEE 754 and comes with some advantages,
-- most notably that it yields no bias.
-- Convergent mode does consume one more LUT and results in a longer critical path.
--
--
-- Overflow and saturation
-- _______________________
--
-- If the input value is already at the maximum value, and the fractional value is such that a
-- rounding upwards should happen, the addition will overflow and the  ``result_overflow`` signal
-- will read as 1.
-- If the ``enable_saturation`` generic is set to true, the result will instead be saturated to the
-- maximum value.
--
--
-- Alternative approach
-- ____________________
--
-- One could sign-extend the input value with one guard bit, add then
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
    convergent_rounding : boolean := true;
    enable_addition_register : boolean := false;
    enable_saturation : boolean := false;
    enable_saturation_register : boolean := false
  );
  port(
    clk : in std_ulogic;
    --# {{}}
    input_valid : in std_ulogic := '0';
    input_value : in u_signed(input_width - 1 downto 0);
    --# {{}}
    result_valid : out std_ulogic := '0';
    result_value : out u_signed(result_width - 1 downto 0) := (others => '0');
    result_overflow : out std_ulogic := '0'
  );
end entity;

architecture a of truncate_round_signed is

begin

  ------------------------------------------------------------------------------
  passthrough_or_not_gen : if input_width = result_width generate

    result_valid <= input_valid;
    result_value <= input_value;
    result_overflow <= '0';


  ------------------------------------------------------------------------------
  else generate
    constant result_value_max : signed(result_value'range) := get_max_signed(
      num_bits=>result_value'length
    );

    signal addition_valid, addition_overflow : std_ulogic := '0';
    signal addition_result : signed(result_width - 1 downto 0) := (others => '0');
  begin

    ------------------------------------------------------------------------------
    addition_block : block
      constant num_lsb_to_remove : positive := input_width - result_width;

      constant one_index : natural := num_lsb_to_remove;
      constant point_five_index : natural := one_index - 1;
      signal one_index_value, point_five_index_value : binary_integer_t := 0;

      signal input_value_integer : signed(result_width - 1 downto 0) := (others => '0');
      signal input_value_integer_is_max : boolean := false;

      signal input_value_fractional : signed(num_lsb_to_remove - 1 downto 0) := (others => '0');

      signal result_int : signed(addition_result'range) := (others => '0');
      signal overflow_int : std_ulogic := '0';
    begin

      input_value_integer <= input_value(input_value'high downto num_lsb_to_remove);
      input_value_integer_is_max <= input_value_integer = result_value_max;

      input_value_fractional <= input_value(input_value_fractional'range);

      one_index_value <= to_int(input_value(one_index));
      point_five_index_value <= to_int(input_value(point_five_index));


      ------------------------------------------------------------------------------
      calculate : process(all)
        function get_fractional_point_five_value return signed is
          variable result : signed(input_value_fractional'range) := (others => '0');
        begin
          result(input_value_fractional'high) := '1';
          return result;
        end function;
        constant input_value_fractional_point_five : signed := get_fractional_point_five_value;

        variable value_to_add : binary_integer_t := 0;
      begin
        if convergent_rounding then
          -- There are other ways of formulating this, but this is method seems to yield
          -- the lowest resource utilization.
          if input_value_fractional = input_value_fractional_point_five then
            value_to_add := one_index_value;
          else
            value_to_add := point_five_index_value;
          end if;
        else
          value_to_add := point_five_index_value;
        end if;

        result_int <= input_value_integer + value_to_add;
        overflow_int <= to_sl(input_value_integer_is_max and value_to_add = 1);
      end process;


      ------------------------------------------------------------------------------
      assign_addition_result : if enable_addition_register generate

        addition_valid <= input_valid when rising_edge(clk);
        addition_result <= result_int when rising_edge(clk);
        addition_overflow <= overflow_int when rising_edge(clk);


      ------------------------------------------------------------------------------
      else generate

        addition_valid <= input_valid;
        addition_result <= result_int;
        addition_overflow <= overflow_int;

      end generate;

    end block;


    assert enable_saturation or not enable_saturation_register
      report "Invalid generic configuration"
      severity failure;


    ------------------------------------------------------------------------------
    saturate_gen : if enable_saturation generate
      signal result_int : signed(addition_result'range) := (others => '0');
    begin

      result_int <= result_value_max when addition_overflow else addition_result;


      ------------------------------------------------------------------------------
      assign_saturation_result : if enable_saturation_register generate

        result_valid <= addition_valid when rising_edge(clk);
        result_value <= result_int when rising_edge(clk);
        result_overflow <= addition_overflow when rising_edge(clk);


      ------------------------------------------------------------------------------
      else generate

        result_valid <= addition_valid;
        result_value <= result_int;
        result_overflow <= addition_overflow;

      end generate;


    ------------------------------------------------------------------------------
    else generate

      result_valid <= addition_valid;
      result_value <= addition_result;
      result_overflow <= addition_overflow;

    end generate;

  end generate;

end architecture;
