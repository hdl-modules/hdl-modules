-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the hdl-modules project, a collection of reusable, high-quality,
-- peer-reviewed VHDL building blocks.
-- https://hdl-modules.com
-- https://github.com/hdl-modules/hdl-modules
-- -------------------------------------------------------------------------------------------------
-- This sinus generator top level accumulates the incoming ``phase_increment`` to form a
-- phase value.
-- The :ref:`sine_generator.sine_calculator` is instantiated to calculate sinusoid values
-- based on this phase.
--
-- Set the ``enable_sine`` and ``enable_cosine`` generic parameters to enable sine and/or
-- cosine output.
--
-- If fractional phase is enabled, the fractional part of the phase will be truncated in
-- :ref:`sine_generator.sine_calculator` when forming the lookup address.
-- Phase dithering can be enabled in this case to improve the SFDR.
--
--
-- .. _sine_calculate_increment:
--
-- About phase increment
-- _____________________
--
-- The frequency of the output signal is determined by the ``phase_increment`` input port value.
-- The width of this port is equal to
--
-- .. math::
--
--   \text{phase_width} = \text{memory_address_width} + 2 + \text{phase_fractional_width}
--
-- In VHDL you are recommended to utilize the ``get_phase_width`` function in
-- :ref:`sine_generator.sine_generator_pkg`.
--
-- The phase increment value can be calculated as
--
-- .. math::
--
--   \text{phase_increment} = \text{int} \left(
--     \frac{\text{sine_frequency_hz}}{\text{clk_frequency_hz}} \times 2^\text{phase_width}
--    \right).
--
-- Where ``sine_frequency_hz`` is the target sinus output frequency, and ``clk_frequency_hz`` is
-- the frequency of the system clock that is clocking this module.
-- In VHDL you are recommended to utilize the ``get_phase_increment`` function in
-- :ref:`sine_generator.sine_generator_pkg`.
--
-- Note that the Nyquist condition must be honored, meaning that the sine frequency must be less
-- than half the clock frequency.
--
--
-- .. _sine_generator_dithering:
--
-- Phase dithering
-- _______________
--
-- Phase dithering adds a pseudo-random offset to the phase that is sent
-- to :ref:`sine_generator.sine_calculator`.
-- The phase offset is uniformly distributed over the entire fractional phase width, meaning
-- between 0 and almost 1 LSB of the memory address.
-- The phase offset is added on top of the phase accumulator, and sometimes the addition will result
-- in +1 LSB in the address, sometimes it will not.
--
-- .. figure:: dithering_zoom.png
--
--   Zoom in of a low-frequency sine wave, without and with dithering.
--
-- This phase offset spreads out the spectrum distortion caused by phase truncation when
-- reading from memory.
-- The result is a lower peak distortion, i.e. a higher SFDR.
-- This comes, of course, at the cost of an increased overall level of noise, i.e. a lower SNDR.
-- Whether this tradeoff is worth it depends on the use case, and the choice is left to the user.
--
-- See :ref:`sine_phase_dithering` for a system-level perspective and some performance graphs.
--
--
-- Pseudo-random algorithm
-- ~~~~~~~~~~~~~~~~~~~~~~~
--
-- Dithering is implemented using a maximum-length linear feedback shift register (LFSR)
-- from the :ref:`module_lfsr`.
-- This gives a sequence of repeating state outputs that is not correlated with the phase and
-- appears pseudo-random.
--
-- The LFSR length is at least equal to the fractional width of the phase increment.
-- -------------------------------------------------------------------------------------------------


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library lfsr;

library math;
use math.math_pkg.all;

use work.sine_generator_pkg.all;


entity sine_generator is
  generic (
    -- The data width of sinusoid samples in ROM.
    -- Affects the SNDR/SFDR of the result.
    memory_data_width : positive;
    -- The number of bits in the address of sine samples in ROM.
    -- ROM will hold '2 ** memory_address_width' samples.
    -- Affects the frequency resolution of the module, as well as the SNDR/SFDR when
    -- in fractional phase mode, see module documentation.
    memory_address_width : positive;
    -- Set a non-zero value to enable fractional phase mode.
    -- Gives a better frequency resolution at the cost of worse performance due to phase truncation.
    phase_fractional_width : natural := 0;
    -- Enable the sine output ('result_sine' port).
    enable_sine : boolean := true;
    -- Enable the cosine output ('result_cosine' port).
    enable_cosine : boolean := false;
    -- When in fractional phase mode, improve SFDR (but worsen SNDR) by spreading out the phase
    -- error noise.
    enable_phase_dithering : boolean := false;
    -- When in fractional phase mode, improve SNDR and SFDR by using a first-order
    -- Taylor expansion of sinus samples.
    enable_first_order_taylor : boolean := false;
    -- Can optionally set the initial value of the phase counter.
    -- Useful when you want multiple sine generators to be in different phase.
    -- Note that the actual phase is slightly offset from the value specified here, see
    -- module documentation.
    initial_phase : u_unsigned(
      get_phase_width(
        memory_address_width=>memory_address_width, phase_fractional_width=>phase_fractional_width
      ) - 1
      downto
      0
    ) := (others => '0')
  );
  port(
    clk : in std_ulogic;
    --# {{}}
    input_valid : in std_ulogic;
    input_phase_increment : in u_unsigned(initial_phase'range);
    --# {{}}
    result_valid : out std_ulogic := '0';
    result_sine : out u_signed(memory_data_width + 1 - 1 downto 0) := (others => '0');
    result_cosine : out u_signed(memory_data_width + 1 - 1 downto 0) := (others => '0')
  );
end entity;

architecture a of sine_generator is

  signal phase_accumulator_valid, phase_valid : std_ulogic := '0';
  signal phase_accumulator, phase : u_unsigned(input_phase_increment'range) := initial_phase;

begin

  assert not (enable_phase_dithering and enable_first_order_taylor)
    report "Dithering will ruin the performance of Taylor expansion. Do not enable both."
    severity failure;


  ------------------------------------------------------------------------------
  assert_widths_block : block
    function get_result_enob return positive is
    begin
      -- Integer phase mode.
      if phase_fractional_width = 0 then
        return memory_data_width + 1;
      end if;

      -- Fractional phase mode, with dithering.
      if enable_phase_dithering then
        return memory_address_width + 4;
      end if;

      -- Fractional phase mode, with Taylor.
      if enable_first_order_taylor then
        return 2 * (memory_address_width + 1);
      end if;

      -- Base fractional phase mode.
      return memory_address_width + 1;
    end function;
    constant result_enob : positive := get_result_enob;
  begin

    -- Assert that we are not unnecessarily limiting the performance of the module.
    -- See module documentation for a background on the limits.
    assert memory_data_width >= result_enob - 1
      report (
        "Memory data width is limiting performance. Need at least " &
        integer'image(result_enob - 1) & " bits"
      )
      severity failure;

  end block;


  ------------------------------------------------------------------------------
  phase_counter : process
    variable phase_increment_to_add : u_unsigned(phase_accumulator'length - 1 - 1 downto 0) := (
      others => '0'
    );
  begin
    wait until rising_edge(clk);

    phase_accumulator_valid <= input_valid;

    if input_valid then
      -- When the phase increment is as wide as the phase accumulator, the top bit
      -- may not be used since that would break the Nyquist criterion.
      -- Hence we can remove the top bit from the addition, saving one LUT.
      phase_increment_to_add := input_phase_increment(phase_increment_to_add'range);
      assert input_phase_increment(input_phase_increment'high) /= '1'
        report "Too high frequency";

      -- Overflow is expected and desired.
      -- Fixed-point numbers are periodic just like the sine function.
      phase_accumulator <= phase_accumulator + phase_increment_to_add;
    end if;
  end process;


  ------------------------------------------------------------------------------
  phase_dithering_gen : if enable_phase_dithering generate
    signal phase_dithering : u_unsigned(phase_fractional_width - 1 downto 0) := (others => '0');
    signal phase_dithering_slv : std_ulogic_vector(phase_dithering'range) := (others => '0');
  begin

    assert phase_fractional_width > 0
      report "Phase dithering requires at least 1 fractional phase bit"
      severity failure;

    -- Some test cases with 4 bits would sometimes be 0.5 dB too low SFDR.
    assert memory_address_width >= 6
      report "Phase dithering does not work well if the memory is too small"
      severity failure;


    ------------------------------------------------------------------------------
    lfsr_fibonacci_multi_inst : entity lfsr.lfsr_fibonacci_multi
      generic map (
        -- Set a lower limit so we get at least some guaranteed level of randomization.
        -- Quite arbitrarily chosen.
        -- Works well in all test cases though, and is not too big in terms of resources.
        minimum_lfsr_length => 10,
        output_width => phase_dithering_slv'length
      )
      port map (
        clk => clk,
        --
        output => phase_dithering_slv
      );

    phase_dithering <= unsigned(phase_dithering_slv);


    ------------------------------------------------------------------------------
    assign_phase : process
    begin
      wait until rising_edge(clk);

      phase_valid <= phase_accumulator_valid;

      -- Note that this might overflow, but this is desired behavior.
      -- If integer phase accumulator is on the very last address, we will jump back and forth
      -- between the last and the first address, depending on the random dither.
      phase <= phase_accumulator + phase_dithering;
    end process;


  ------------------------------------------------------------------------------
  else generate

    phase_valid <= phase_accumulator_valid;
    phase <= phase_accumulator;

  end generate;


  ------------------------------------------------------------------------------
  sine_calculator_inst : entity work.sine_calculator
    generic map (
      memory_data_width => memory_data_width,
      memory_address_width => memory_address_width,
      phase_fractional_width => phase_fractional_width,
      enable_sine => enable_sine,
      enable_cosine => enable_cosine,
      enable_first_order_taylor => enable_first_order_taylor
    )
    port map (
      clk => clk,
      --
      input_valid => phase_valid,
      input_phase => phase,
      --
      result_valid => result_valid,
      result_sine => result_sine,
      result_cosine => result_cosine
    );

end architecture;
