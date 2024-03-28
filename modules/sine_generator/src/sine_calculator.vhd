-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the hdl-modules project, a collection of reusable, high-quality,
-- peer-reviewed VHDL building blocks.
-- https://hdl-modules.com
-- https://github.com/hdl-modules/hdl-modules
-- -------------------------------------------------------------------------------------------------
-- Calculates the sinus value corresponding to the provided phase value.
-- Instantiates a sine lookup table (:ref:`sine_generator.sine_lookup`) where the integer part
-- of the phase will be used as address.
--
-- If fractional phase is enabled, the fractional part of the phase will be truncated when
-- forming the lookup address.
-- First-order Taylor expansion can be enabled to improve the accuracy using the truncated phase.
--
--
-- .. _sine_taylor_expansion:
--
-- Taylor expansion
-- ________________
--
-- The Taylor expansion of a function is given by
--
-- .. math::
--
--   f(x) = f(a) + f'(a) \times (x - a) + \frac{f''(a)}{2!} \times (x - a)^2
--     + \frac{f'''(a)}{3!} \times (x - a)^3 + ...
--
-- See https://en.wikipedia.org/wiki/Taylor_series.
-- The accuracy is better if :math:`a` is close to :math:`x`, or if many terms are used.
-- Substituting
--
-- .. math::
--
--   e \equiv x - a,
--
-- and realizing the following properties of the derivative of the sine function
--
-- .. math::
--
--   f(x) & \equiv A \sin(B x + C) \\
--   \Rightarrow f'(x) & = A B \cos(B x + C) \\
--   \Rightarrow f''(x) & = -A B^2 \sin(B x + C) = - B^2 f(x) \\
--   \Rightarrow f'''(x) & = -A B^3 \cos(B x + C) = - B^2 f'(x) \\
--   \Rightarrow f''''(x) & = A B^4 \sin(B x + C) = B^4 f(x)
--
-- we get
--
-- .. math::
--
--   A \sin(B x + C) = & \ A \sin(B a + C) \times
--   \left( 1 - \frac{(Be)^2}{2!} + \frac{(Be)^4}{4!}  - \frac{(Be)^6}{6!} + \ldots \right) \\
--   & + A \cos(B a + C) \times
--   \left( Be - \frac{(Be)^3}{3!} + \frac{(Be)^5}{5!} - \frac{(Be)^7}{7!} + \ldots \right).
--
--
-- Taylor expansion implementation
-- _______________________________
--
-- This entity corrects the sine lookup value using first-order Taylor expansion, meaning
--
-- .. math::
--
--  A \sin(B x + C) \approx A \sin(B a + C) + A \cos(B a + C) \times B e.
--
-- In this representation, :math:`x` is the full phase value, including fractional bits.
-- The :math:`a` is the integer part of the phase value that forms the
-- memory address, and :math:`e` is the fractional part of the phase that gets truncated.
-- The :math:`A \sin(B x + C)` and :math:`A \cos(B x + C)` values are given by
-- :ref:`sine_generator.sine_lookup`.
-- The :math:`B` value is the phase increment of the lookup table:
--
-- .. math::
--
--   B \equiv \frac{\pi / 2}{2^\text{memory_address_width}}.
--
-- The calculation is partitioned like this, using DSP48 blocks:
--
-- .. digraph:: my_graph
--
--   graph [dpi=300];
--   rankdir="LR";
--
--   phase_error [shape="none" label="phase error"];
--   pi [shape="none" label="&pi;/2"];
--
--   {
--     rank=same;
--     phase_error;
--     pi;
--   }
--
--   first_multiplication [shape="box" label="x"];
--
--   phase_error -> first_multiplication [label="<=25"];
--   pi -> first_multiplication [label="<=18"];
--
--   lookup_cosine [shape="none" label="lookup cosine"];
--
--   {
--     first_multiplication=same;
--     lookup_cosine;
--     pi;
--   }
--
--   second_multiplication [shape="box" label="x"];
--
--   first_multiplication -> second_multiplication [label="<=25"];
--   lookup_cosine -> second_multiplication [label="<=18"];
--
--   lookup_sine [shape="none" label="lookup sine & 0"];
--
--   {
--     first_multiplication=same;
--     second_multiplication;
--     lookup_sine;
--   }
--
--   addition [shape="box" label="+"];
--
--   second_multiplication -> addition [label="<=47"];
--   lookup_sine -> addition [label="<=47"];
--
--   saturation [shape="box" label="saturation"];
--
--   addition -> saturation [label="<=48"];
--
--   result [shape="none" label="result"];
--
--   saturation -> result;
--
-- The :math:`\pi / 2` is handled as a fixed-pointed value with a number of fractional bits
-- determined to give sufficient performance.
-- Multiplying with the phase error, which is a fractional value, and then the cosine value
-- gives a value that has a very high number of fractional bits.
-- In order for the summation with the sine value to be correct, the sine value must be
-- shifted up until the binal points align.
--
-- When the operands are small, the last multiplication and the addition can fit in the same DSP48.
-- This is not the case in general though.
--
-- .. note::
--
--   An alternative approach would be to store the error term in a ROM and use the phase error
--   as lookup address.
--   This would save DSP blocks but cost BRAM.
--   We can support that in the future with a generic switch if there is ever a need.
-- -------------------------------------------------------------------------------------------------

library ieee;
use ieee.math_real.all;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;

library common;
use common.attribute_pkg.all;
use common.types_pkg.all;

library math;
use math.math_pkg.all;

use work.sine_generator_pkg.all;


entity sine_calculator is
  generic (
    -- The data width of sinusoid samples in ROM.
    -- Affects the SNDR/SFDR of the result.
    memory_data_width : positive;
    -- The number of bits in the address of sine samples in ROM.
    -- ROM will hold '2 ** memory_address_width' samples.
    -- Affects the frequency resolution of the module, as well as the SNDR/SFDR when
    -- in fractional phase mode, see module documentation.
    memory_address_width : positive;
    -- Enable the sine output ('result_sine' port).
    enable_sine : boolean := true;
    -- Enable the cosine output ('result_cosine' port).
    enable_cosine : boolean := false;
    -- Set a non-zero value to enable fractional phase mode.
    -- Gives a better frequency resolution at the cost of worse performance due to phase truncation.
    phase_fractional_width : natural;
    -- When in fractional phase mode, improve SFDR (but worsen SNDR) by spreading out the phase
    -- error noise.
    enable_first_order_taylor : boolean
  );
  port(
    clk : in std_ulogic;
    --# {{}}
    input_valid : in std_ulogic;
    input_phase : in u_unsigned(
      get_phase_width(
        memory_address_width=>memory_address_width, phase_fractional_width=>phase_fractional_width
      ) - 1
      downto
      0
    );
    --# {{}}
    result_valid : out std_ulogic := '0';
    result_sine : out u_signed(memory_data_width + 1 - 1 downto 0) := (others => '0');
    result_cosine : out u_signed(memory_data_width + 1 - 1 downto 0) := (others => '0')
  );
end entity;

architecture a of sine_calculator is

  signal input_phase_integer : u_unsigned(memory_address_width + 2 - 1 downto 0) := (
    others => '0'
  );
  signal input_phase_fractional : u_unsigned(
    input_phase'high - input_phase_integer'length downto 0
  ) := (others => '0');

  signal lookup_valid : std_ulogic := '0';
  signal lookup_sine, lookup_cosine : u_signed(memory_data_width + 1 - 1 downto 0) := (
    others => '0'
  );

begin

  ------------------------------------------------------------------------------
  sine_lookup_inst : entity work.sine_lookup
    generic map (
      memory_data_width => memory_data_width,
      memory_address_width => memory_address_width,
      enable_sine => enable_sine or enable_first_order_taylor,
      enable_cosine => enable_cosine or enable_first_order_taylor
    )
    port map (
      clk => clk,
      --
      input_valid => input_valid,
      input_phase => input_phase_integer,
      --
      result_valid => lookup_valid,
      result_sine => lookup_sine,
      result_cosine => lookup_cosine
    );

  input_phase_integer <= input_phase(
    input_phase'high downto input_phase'length - input_phase_integer'length
  );

  input_phase_fractional <= input_phase(input_phase_fractional'range);


  ------------------------------------------------------------------------------
  taylor_expansion_gen : if enable_first_order_taylor generate
    constant core_latency : positive := work.taylor_expansion_core'latency;
    signal valid_pipe : std_ulogic_vector(1 to core_latency) := (others => '0');

    -- Referring to the documentation, we want to scale the fractional fixed-point
    -- 'phase_error' with the factor 'B'.
    -- Which is pi/2 / 2**memory_address_width.
    -- The '2**address_width' part we will realize as a shift of the multiplication result.
    -- But the 'pi/2' we have to make as a multiplication.
    -- The number of fractional bits below has been found by trial-and-error to not be limiting
    -- the performance of the system in any of the performance modes.
    -- This width also makes it map nicely to a DSP48E1 (25x18 + 48 = 48)
    -- or DSP48E2 (27x18 + 48 = 48)
    constant scale_factor_fractional_width : positive := 16;
    constant scale_factor_real : real := MATH_PI_OVER_2 * 2.0 ** scale_factor_fractional_width;
    constant scale_factor_int : positive := integer(round(scale_factor_real));
    constant scale_factor_width : positive := num_bits_needed(scale_factor_int);
    constant scale_factor : unsigned(scale_factor_width - 1 downto 0) := to_unsigned(
      scale_factor_int, scale_factor_width
    );

    -- In order to map 'error_factor = phase_error * scale_factor' to a DSP48 we might, in a very
    -- unlikely scenario, have to trim the 'phase_error'.
    -- In case of a huge phase accumulator, the error might be wider than 24 (meaning a signed 25).
    -- We have assertions below that this trimming does not limit the performance of the output.
    constant phase_error24_width : positive := minimum(input_phase_fractional'length, 24);
    -- The number of bits we trimmed to get to the desired width.
    constant phase_error24_trim : natural := input_phase_fractional'length - phase_error24_width;

    -- +1 for unsigned -> signed.
    constant error_factor_width : positive := phase_error24_width + scale_factor'length + 1;
    -- We might have to trim to make the 'derivative_term = error_factor * derivative'
    -- multiplication fit in a DSP48.
    constant error_factor25_width : positive := minimum(error_factor_width, 25);
    -- Number of bits we trimmed to get to the desired width.
    constant error_factor25_trim : natural := error_factor_width - error_factor25_width;

    -- The 'value' term needs to be shifted up this many steps for the binal point to align with
    -- the 'derivative' term.
    -- In this nomenclature we do not take into account any fraction width or fixed-point
    -- representation of the lookup sinusoid values, since that is the same for both terms.
    -- This number is only the difference between the two terms.
    constant error_factor25_fractional_width : positive := (
      phase_error24_width
      + scale_factor_fractional_width
      + memory_address_width
      - error_factor25_trim
    );

    signal first_stage_error_factor25 : u_signed(error_factor25_width - 1 downto 0) := (
      others => '0'
    );

    attribute use_dsp of first_stage_error_factor25 : signal is "yes";
  begin

    assert enable_sine or enable_cosine
      report "Enable at least one output signal"
      severity failure;

    assert memory_address_width <= 15
      report "Performance has not been verified with this accuracy"
      severity failure;

    assert input_phase_fractional'length > 0
      report "Taylor expansion requires at least 1 fractional phase bit"
      severity failure;


    ------------------------------------------------------------------------------
    print : process
    begin
      report "======================================================================";
      report "scale_factor'length = " & integer'image(scale_factor'length);
      report "input_phase_fractional'length = " & integer'image(input_phase_fractional'length);

      report "======================================================================";
      report "phase_error24_width = " & integer'image(phase_error24_width);
      report "phase_error24_trim = " & integer'image(phase_error24_trim);

      report "======================================================================";
      report "error_factor_width = " & integer'image(error_factor_width);
      report "error_factor25_width = " & integer'image(error_factor25_width);
      report "error_factor25_trim = " & integer'image(error_factor25_trim);
      report "error_factor25_fractional_width = " & integer'image(error_factor25_fractional_width);

      wait;
    end process;


    ------------------------------------------------------------------------------
    pipeline_valid : process
    begin
      wait until rising_edge(clk);

      valid_pipe <= lookup_valid & valid_pipe(valid_pipe'left to valid_pipe'right - 1);
    end process;

    result_valid <= valid_pipe(valid_pipe'right);


    ------------------------------------------------------------------------------
    first_stage : block
      signal phase_error24, input_phase_fractional24 : u_unsigned(
        phase_error24_width - 1 downto 0
      ) := (others => '0');

      -- We want to access the error value one cycle before we access the lookup result,
      -- hence the range of the pipe.
      constant lookup_latency : positive := work.sine_lookup'latency;
      signal phase_error24_pipe : unsigned_vec_t(1 to lookup_latency - 1)(phase_error24'range) := (
        others => (others => '0')
      );

      -- Full size.
      signal error_factor_unsigned : u_unsigned(error_factor_width - 1 - 1 downto 0) := (
        others => '0'
      );
      signal error_factor : u_signed(error_factor_width - 1 downto 0) := (others => '0');

      attribute use_dsp of error_factor_unsigned : signal is "yes";
    begin

      ------------------------------------------------------------------------------
      pipe : process
      begin
        wait until rising_edge(clk);

        phase_error24_pipe <= (
          input_phase_fractional24
          & phase_error24_pipe(phase_error24_pipe'left to phase_error24_pipe'right - 1)
        );
      end process;

      input_phase_fractional24 <= input_phase_fractional(
        input_phase_fractional'high downto phase_error24_trim
      );

      phase_error24 <= phase_error24_pipe(phase_error24_pipe'right);


      ------------------------------------------------------------------------------
      assert scale_factor'length = 17
        report "Will not map nicely to DSP48. Got " & integer'image(scale_factor'length)
        severity failure;

      assert phase_error24'length <= 24
        report "Will not map nicely to DSP48. Got " & integer'image(phase_error24'length)
        severity failure;


      ------------------------------------------------------------------------------
      calculate_first_stage : process
      begin
        wait until rising_edge(clk);

        -- Calculate the error factor one cycle before the corresponding lookup result is available.
        -- An alternative approach would be to save this error factor in a ROM, and look it up
        -- using the phase error as address.
        -- This would save DSP but cost BRAM.
        error_factor_unsigned <= phase_error24 * scale_factor;
      end process;

      error_factor <= '0' & signed(error_factor_unsigned);
      first_stage_error_factor25 <= error_factor(error_factor'high downto error_factor25_trim);

    end block;


    ------------------------------------------------------------------------------
    sine_taylor_gen : if enable_sine generate

      ------------------------------------------------------------------------------
      sine_taylor_expansion_core_inst : entity work.taylor_expansion_core
        generic map (
          sinusoid_width => lookup_sine'length,
          error_factor_width => first_stage_error_factor25'length,
          error_factor_fractional_width => error_factor25_fractional_width,
          result_width => result_sine'length,
          minus_derivative => false
        )
        port map (
          clk => clk,
          --
          input_value => lookup_sine,
          input_derivative => lookup_cosine,
          input_error_factor => first_stage_error_factor25,
          --
          result_value => result_sine
        );

    end generate;


    ------------------------------------------------------------------------------
    cosine_taylor_gen : if enable_cosine generate

      ------------------------------------------------------------------------------
      sine_taylor_expansion_core_inst : entity work.taylor_expansion_core
        generic map (
          sinusoid_width => lookup_sine'length,
          error_factor_width => first_stage_error_factor25'length,
          error_factor_fractional_width => error_factor25_fractional_width,
          result_width => result_cosine'length,
          minus_derivative => true
        )
        port map (
          clk => clk,
          --
          input_value => lookup_cosine,
          input_derivative => lookup_sine,
          input_error_factor => first_stage_error_factor25,
          --
          result_value => result_cosine
        );

    end generate;

  else generate

    -- Simply assign output.
    result_valid <= lookup_valid;


    ------------------------------------------------------------------------------
    assign_sine : if enable_sine generate
      result_sine <= lookup_sine;
    end generate;


    ------------------------------------------------------------------------------
    assign_cosine : if enable_cosine generate
      result_cosine <= lookup_cosine;
    end generate;

  end generate;

end architecture;
