-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the hdl-modules project, a collection of reusable, high-quality,
-- peer-reviewed VHDL building blocks.
-- https://hdl-modules.com
-- https://github.com/hdl-modules/hdl-modules
-- -------------------------------------------------------------------------------------------------
-- Core that calculates the first-order Taylor expansion of sinusoid function
--
-- .. math::
--
--   f(x) \approx f(a) + e \times f'(a)
--
-- with fixed-point numbers that fit in a DSP48.
-- This core is to be used in :ref:`sine_generator.sine_calculator`, and is not really suitable
-- for other purposes.
--
-- .. warning::
--
--   This is an internal core.
--   The interface might change without notice.
-- -------------------------------------------------------------------------------------------------

library ieee;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;

library common;
use common.attribute_pkg.all;


entity taylor_expansion_core is
  generic (
    sinusoid_width : positive;
    error_factor_width : positive;
    error_factor_fractional_width : positive;
    result_width : positive;
    minus_derivative : boolean
  );
  port(
    clk : in std_ulogic;
    --# {{}}
    input_value : in u_signed(sinusoid_width - 1 downto 0);
    input_derivative : in u_signed(sinusoid_width - 1 downto 0);
    input_error_factor : in u_signed(error_factor_width - 1 downto 0);
    --# {{}}
    result_value : out u_signed(result_width - 1 downto 0) := (others => '0')
  );

  -- 'result' is valid this many clock cycles after 'input' is valid.
  attribute latency : positive;
  attribute latency of taylor_expansion_core : entity is 2;
end entity;

architecture a of taylor_expansion_core is

  -- The 'memory_data_width' is very typically 18, yielding a 'derivative' value of 19 bits.
  -- In order to map to a DSP48 it would be lovely if it was just 18 bits.
  -- We have asserted through simulation that this is not limiting the performance.
  constant derivative18_width : positive := minimum(input_derivative'length, 18);
  -- Number of bits we trimmed to get to the desired width.
  constant derivative18_trim : natural := input_derivative'length - derivative18_width;

  -- After all trimming there are this many fractional bits left in the 'derivative' term.
  constant derivative_term_fractional_width : natural := (
    error_factor_fractional_width - derivative18_trim
  );

  -- We add two terms, so we need this many guard bits.
  constant sum_num_guard_bits : positive := 1;
  -- Terms may not be wider than this in order to avoid overflow.
  constant max_sum_term_width : positive := 48 - sum_num_guard_bits;
  -- Maximum number of steps we can shift up the 'value' term.
  constant max_sum_term_fractional_width : positive := max_sum_term_width - input_value'length;

  -- Number of fractional bits in the 'derivative' term when we have trimmed it to make the
  -- addition fit in a DSP48.
  constant derivative_term48_fractional_width : natural := minimum(
    derivative_term_fractional_width, max_sum_term_fractional_width
  );
  -- Number of bits we trimmed to get to the desired width.
  -- When operands are small enough, this will be zero.
  -- In that case, the 'derivative' term multiplication and the addition with 'value' term
  -- can fit in the same DSP48.
  constant derivative_term48_trim : natural := (
    derivative_term_fractional_width - derivative_term48_fractional_width
  );

  -- When adding the 'value' and 'derivative' terms to form the result of Taylor expansion,
  -- we must pad the 'value' so that the binal points align.
  -- Our words are aligned something like this, we don't really know:
  --
  -- Derivative term            |----------------------|
  -- Value term       |------------------10000000000000|
  -- Sum             |---------------------------------|
  -- Result           |------------------|
  --
  -- Derivative term                    |--------------|
  -- Value term       |------------------10000000000000|
  -- Sum             |---------------------------------|
  -- Result           |------------------|
  --
  -- The 'value' term padding has a '1' in the MSB in order to get +0.5 rounding of the result,
  -- which yields greater performance.
  function get_value_term_padding return u_signed is
    variable result : u_signed(derivative_term48_fractional_width - 1 downto 0) := (others => '0');
  begin
    result(result'high) := '1';
    return result;
  end function;
  constant value_term_padding : u_signed(derivative_term48_fractional_width - 1 downto 0) := (
    get_value_term_padding
  );

  signal second_stage_value_term48 : u_signed(
    input_value'length + value_term_padding'length - 1 downto 0
  ) := (others => '0');
  signal second_stage_derivative_term48 : u_signed(
    derivative18_width + input_error_factor'length - derivative_term48_trim - 1 downto 0
  ) := (others => '0');

  attribute use_dsp of second_stage_value_term48 : signal is "yes";
  attribute use_dsp of second_stage_derivative_term48 : signal is "yes";

begin

  ------------------------------------------------------------------------------
  print : process
  begin
    report "======================================================================";
    report "derivative18_width = " & integer'image(derivative18_width);
    report "derivative18_trim = " & integer'image(derivative18_trim);

    report "======================================================================";
    report "derivative_term_fractional_width = " & integer'image(derivative_term_fractional_width);
    report "max_sum_term_fractional_width = " & integer'image(max_sum_term_fractional_width);
    report (
      "derivative_term48_fractional_width = " & integer'image(derivative_term48_fractional_width)
    );
    report "derivative_term48_trim = " & integer'image(derivative_term48_trim);

    wait;
  end process;


  ------------------------------------------------------------------------------
  second_stage : block
    signal derivative18 : u_signed(derivative18_width - 1 downto 0) := (others => '0');

    signal derivative_term : u_signed(derivative18_width + error_factor_width - 1 downto 0) := (
      others => '0'
    );

    attribute use_dsp of derivative_term : signal is "yes";
  begin

    ------------------------------------------------------------------------------
    assert derivative18'length <= 18
      report "Will not map nicely to DSP48. Got " & integer'image(derivative18'length)
      severity failure;

    assert input_error_factor'length <= 25
      report (
        "Will not map nicely to DSP48. Got "
        & integer'image(input_error_factor'length)
      )
      severity failure;


    ------------------------------------------------------------------------------
    calculate_second_stage : process
    begin
      wait until rising_edge(clk);

      derivative_term <= derivative18 * input_error_factor;

      -- Hopefully this can use the input register of the DSP48.
      second_stage_value_term48 <= input_value & value_term_padding;
    end process;

    derivative18 <= input_derivative(input_derivative'high downto derivative18_trim);

    second_stage_derivative_term48 <= derivative_term(
      derivative_term'high downto derivative_term48_trim
    );

  end block;


  ------------------------------------------------------------------------------
  third_stage : block
    -- Assumes that the 'value' term is wider than the 'derivative' term, which is checked below.
    -- If 'derivative' term is wider, we must take into account that it contains a redundant sign
    -- bit due to unsigned -> signed conversion.
    constant sum_width : positive := second_stage_value_term48'length + sum_num_guard_bits;
    signal sum : u_signed(sum_width - 1 downto 0) := (others => '0');

    attribute use_dsp of sum : signal is "yes";
  begin

    ------------------------------------------------------------------------------
    assert second_stage_derivative_term48'length >= value_term_padding'length
      report "Taylor addition is a null operation"
      severity failure;

    assert result_value'length = input_value'length
      report "Some assumptions do not hold unless this is true"
      severity failure;

    assert second_stage_value_term48'length > second_stage_derivative_term48'length
      report "Some assumptions do not hold unless this is true"
      severity failure;

    assert second_stage_value_term48'length < 48
      report "Will not map nicely to DSP48. Got " & integer'image(second_stage_value_term48'length)
      severity failure;

    assert second_stage_derivative_term48'length < 48
      report (
        "Will not map nicely to DSP48. Got " & integer'image(second_stage_derivative_term48'length)
      )
      severity failure;

    assert sum'length <= 48
      report "Will not map nicely to DSP48. Got " & integer'image(sum'length)
      severity failure;

    assert result_value'length < sum'length
      report (
        "Result is too wide. Got "
        & integer'image(result_value'length)
        & " "
        & integer'image(sum'length)
      )
      severity failure;


    ------------------------------------------------------------------------------
    calculate_third_stage : process
    begin
      wait until rising_edge(clk);

      -- Note that the 'derivative' term contains a redundant sign bit due to
      -- unsigned -> signed conversion.
      -- If the addition were done in LUTs we would strip that bit, which would save some LUTs.
      -- However, if we ever want the multiplication and addition to map to the same DSP48,
      -- we can't do that.
      -- Due to the way the internals of the DSP is constructed.
      -- And we would also not save anything by doing that.
      if minus_derivative then
        sum <= resize(second_stage_value_term48, sum'length) - second_stage_derivative_term48;
      else
        sum <= resize(second_stage_value_term48, sum'length) + second_stage_derivative_term48;
      end if;
    end process;


    ------------------------------------------------------------------------------
    -- The sum overflows at almost every peak in every configuration.
    -- We have to saturate the result so that the full range, or at least some well-defined range,
    -- of the output word is used.
    -- The overflow is so small that the SFDR of the result is still good enough in all
    -- simulations even with saturation.
    set_saturated_result : process(all)
      variable guard_and_sign : u_signed(sum_num_guard_bits + 1 - 1 downto 0) := (
        others => '0'
      );
    begin
      guard_and_sign := sum(sum'high downto sum'length - guard_and_sign'length);

      if (or guard_and_sign) = (and guard_and_sign) then
        result_value <= sum(
          sum'high - sum_num_guard_bits
          downto
          sum'length - result_value'length - sum_num_guard_bits
        );
      else
        result_value <= (others => not guard_and_sign(guard_and_sign'high));
        result_value(result_value'high) <= guard_and_sign(guard_and_sign'high);
      end if;
    end process;

  end block;

end architecture;
