-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the hdl-modules project, a collection of reusable, high-quality,
-- peer-reviewed VHDL building blocks.
-- https://hdl-modules.com
-- https://github.com/hdl-modules/hdl-modules
-- -------------------------------------------------------------------------------------------------
-- Saturate a signed number by removing MSBs.
-- Typically used in fixed-point applications after performing arithmetic operations, such as
-- addition or multiplication.
-- Or to clamp a value from a third source to a certain range.
--
-- In digital arithmetic scenarios, the concept of guard bits is commonly used, and the input value
-- will be of
-- the form:
--
--   input_value = S G G G N N N N N N N N
--
-- Where S is the sign bit, and G are a guard bits.
-- Note that the number of guard bits, three in the example above, is the difference between
-- ``input_width`` and ``result_width``.
--
--
-- Pseudo code
-- ___________
--
-- This entity performs the following operation, which is equivalent to a range clamping with
-- power-of-two limits:
--
-- .. code-block:: python
--
--   min_value = - 2 ** (result_width - 1)
--   max_value = 2 ** (result_width - 1) - 1
--   if input_value < min_value:
--     return min_value
--   if input_value > max_value:
--     return max_value
--   return input_value
--
--
-- Fixed-point implementation
-- __________________________
--
-- The pseudo code above is efficiently implemented in digital logic by looking at the guard bits
-- and the sign bit.
-- If any of them have different value, the input value is outside the result range.
-- If the sign bit is '1', the input is negative, and the result should be greatest negative
-- value possible.
-- If the sign bit is '0', the input is positive, and the result should be the greatest positive
-- value possible.
--
-- Note that you have to choose your number of guard bits carefully in any upstream arithmetic
-- operation.
-- If you have too few guard bits, the value might already have wrapped around, and the saturation
-- will not work as expected.
-- This is all dependent on the details of your application.
-- -------------------------------------------------------------------------------------------------

library ieee;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;


entity saturate_signed is
  generic (
    input_width : positive;
    result_width : positive;
    enable_output_register : boolean := false
  );
  port(
    clk : in std_ulogic;
    --# {{}}
    input_value : in u_signed(input_width - 1 downto 0);
    result_value : out u_signed(result_width - 1 downto 0) := (others => '0')
  );
end entity;

architecture a of saturate_signed is

  constant num_guard_bits : natural := input_width - result_width;

  signal result : u_signed(result_value'range) := (others => '0');

begin

  ------------------------------------------------------------------------------
  main : process(all)
    variable guard_and_sign : u_signed(num_guard_bits + 1 - 1 downto 0) := (others => '0');
  begin
    guard_and_sign := input_value(
      input_value'high downto input_value'length - guard_and_sign'length
    );

    if (or guard_and_sign) = (and guard_and_sign) then
      result <= input_value(input_value'high - num_guard_bits downto 0);
    else
      result <= (others => not guard_and_sign(guard_and_sign'high));
      result(result_value'high) <= guard_and_sign(guard_and_sign'high);
    end if;
  end process;


  ------------------------------------------------------------------------------
  output_register_gen : if enable_output_register generate

    result_value <= result when rising_edge(clk);


  ------------------------------------------------------------------------------
  else generate

    result_value <= result;

  end generate;

end architecture;
