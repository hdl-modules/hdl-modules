-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the hdl-modules project, a collection of reusable, high-quality,
-- peer-reviewed VHDL building blocks.
-- https://hdl-modules.com
-- https://github.com/hdl-modules/hdl-modules
-- -------------------------------------------------------------------------------------------------
-- A lookup table for fixed-point sine and cosine values.
-- The ``input_phase`` is in range :math:`[0, 2 \pi[`, but the memory in this entity stores only
-- samples for :math:`[0, \pi / 2[`.
-- The phase is furthermore offset by plus half an LSB (see :ref:`sine_lookup_quadrant` below).
--
-- Each sample value in memory is ``memory_data_width`` bits wide.
--
-- Use the ``enable_*`` generics to specify which signals to calculate.
-- Enabling many is convenient when you want sinusoids that are perfectly :math:`\pi / 2`-offset
-- from each other.
-- Enabling further signals will not require any extra memory, but it will add logic.
-- Also, sine calculation (positive or negative) requires one memory read port, while cosine
-- calculation (positive or negative) requires another.
-- So enabling any sine along with any cosine will require two memory read ports.
--
--
-- .. _sine_lookup_quadrant:
--
-- Quadrant handling
-- _________________
--
-- Consider the unit circle, and the sine and cosine plots in the picture below.
--
-- .. figure:: quadrants.png
--
--   Overview of the four quadrants.
--
-- When implementing an angle-discrete sine lookup table, the first approach might be to use
-- the blue points in the plot above, starting at phase zero.
-- However, for the implementation to be efficient, we want to be able to calculate e.g. sine in
-- quadrant one as the sine in quadrant zero, but read out in reverse order.
-- This is desirable since "reverse order" when working with fixed-point numbers simply means
-- a bit-wise inverse of a "normal order" counter.
--
-- With this goal of efficient implementation in mind, we offset the phase so that the points are
-- mirrored around :math:`0`, :math:`\pi/2`, :math:`\pi` and :math:`3 \pi/2`.
-- The resulting symmetry can be clearly seen in the sine and cosine plots above.
-- For example, the sine points in quadrant one are clearly the same points as in quadrant zero,
-- but in reverse order.
-- Apart from this ocular hint, we can also show it using basic trigonometric identities:
--
-- .. math::
--
--   \text{Sine quadrant 0: } & \sin(\theta) = \sin(\theta)
--   \\
--   \text{Sine quadrant 1: } & \sin(\theta + \frac{\pi}{2}) = \sin(\frac{\pi}{2} - \theta)
--     = \sin( \bar{\theta} )
--   \\
--   \text{Sine quadrant 2: } & \sin(\theta + \pi) = - \sin(\theta)
--   \\
--   \text{Sine quadrant 3: } & \sin(\theta + \frac{3 \pi}{2}) = - \sin(\frac{\pi}{2} - \theta)
--     = - \sin( \bar{\theta} )
--   \\
--   \\
--   \text{Cosine quadrant 0: } & \cos(\theta) = \sin(\frac{\pi}{2} - \theta)
--     = \sin( \bar{\theta} )
--   \\
--   \text{Cosine quadrant 1: } & \cos(\theta + \frac{\pi}{2}) = - \sin(\theta)
--   \\
--   \text{Cosine quadrant 2: } & \cos(\theta + \pi) = - \sin(\frac{\pi}{2} - \theta)
--     = - \sin( \bar{\theta} )
--   \\
--   \text{Cosine quadrant 3: } & \cos(\theta + \frac{3 \pi}{2}) = \sin(\theta)
--
-- This shows how both sine and cosine for all four quadrant can be calculated using only sine
-- values from the first quadrant (:math:`[0, \pi/2]`).
-- In the calculations above we have utilized the fact that a phase of :math:`\pi/2 - \theta`,
-- meaning phase in reverse order, is the same as bit-inversion of the phase.
--
--
-- Fixed-point representation
-- __________________________
--
-- When we want to distribute :math:`2^\text{memory_address_width}` number of points over the phase
-- range :math:`[0, \pi / 2[`, we use
--
-- .. math::
--
--   \text{phase_increment} \equiv \frac{\pi / 2}{2^\text{memory_address_width}}.
--
-- To achieve the symmetry we aim for in the discussion above, we offset the phase by half an LSB:
--
-- .. math::
--
--   \phi \equiv \frac{\text{phase_increment}}{2}.
--
-- This gives a total phase of
--
-- .. math::
--
--   \theta(i) \equiv i \times \text{phase_increment} + \phi.
--
-- We also have an amplitude-quantization given by the ``memory_data_width`` generic.
-- This gives a maximum amplitude of
--
-- .. math::
--
--   A \equiv 2^\text{memory_data_width} - 1.
--
-- With this established, we can calculate the memory values as
--
-- .. math::
--
--   \text{mem} (i) = \text{int} \left(  A \times \sin(\theta(i)) \right),
--     \forall i \in [0, 2^\text{memory_address_width} - 1].
--
-- As can be seen in the trigonometric identities above, the resulting output sine value from this
-- entity is negated in some some quadrants.
-- This gives an output range of :math:`[-A, A]`.
-- Where fixed-point :math:`A` is equivalent to floating-point :math:`1.0`.
--
--
-- Performance
-- ___________
--
-- Samples in memory are stored with ``memory_data_width`` bits, and the quadrant handling discussed
-- above adds one more sign bit.
-- The only source of noise and distortion is the digital quantization noise when storing sine
-- values with a fixed-point representation in memory.
--
-- Hence the result from this entity has SNDR and SFDR equal to ``memory_data_width + 1`` ENOB.
-- -------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

library common;
use common.types_pkg.all;


entity sine_lookup is
  generic (
    -- The data width of sinusoid samples in ROM.
    -- Affects the SNDR/SFDR of the result.
    memory_data_width : positive;
    -- The number of bits in the address of sine samples in ROM.
    -- ROM will hold '2 ** memory_address_width' samples.
    -- Affects the frequency resolution.
    memory_address_width : positive;
    -- Enable the output signals you want to calculate.
    enable_sine : boolean := false;
    enable_cosine : boolean := false;
    enable_minus_sine : boolean := false;
    enable_minus_cosine : boolean := false
  );
  port(
    clk : in std_ulogic;
    --# {{}}
    input_valid : in std_ulogic;
    input_phase : in u_unsigned(memory_address_width + 2 - 1 downto 0);
    --# {{}}
    result_valid : out std_ulogic := '0';
    result_sine : out u_signed(memory_data_width + 1 - 1 downto 0) := (others => '0');
    result_cosine : out u_signed(memory_data_width + 1 - 1 downto 0) := (others => '0');
    result_minus_sine : out u_signed(memory_data_width + 1 - 1 downto 0) := (others => '0');
    result_minus_cosine : out u_signed(memory_data_width + 1 - 1 downto 0) := (others => '0')
  );

  attribute latency : positive;
  attribute latency of sine_lookup : entity is 3;
end entity;


architecture a of sine_lookup is

  constant our_latency : positive := sine_lookup'latency;

  constant any_sine_enabled : boolean := enable_sine or enable_minus_sine;
  constant any_cosine_enabled : boolean := enable_cosine or enable_minus_cosine;

  constant memory_depth : positive := 2 ** memory_address_width;

  subtype memory_address_t is natural range 0 to memory_depth - 1;
  signal sine_address, cosine_address : memory_address_t := 0;

  signal memory_sine, memory_cosine : u_unsigned(memory_data_width - 1 downto 0) := (others => '0');

begin

  assert any_sine_enabled or any_cosine_enabled
    report "Enable at least one signal or this entity is quite useless"
    severity failure;


  ------------------------------------------------------------------------------
  memory_block : block
    type sine_table_t is array (memory_address_t) of unsigned(memory_data_width - 1 downto 0);

    function calculate_sine_quadrant_table return sine_table_t is
      -- We aim to fill the memory with sine samples for a phase range of [0, pi/2[.
      constant index_phase_increment : real := MATH_PI_OVER_2 / real(memory_depth);
      -- Offset so that quadrant extrapolation works (see module documentation).
      constant phase_offset : real := index_phase_increment / 2.0;

      -- Amplitude is e.g. [0, 511] (including)
      -- Note that since we are calculating only the first quadrant, the values are
      -- always non-negative.
      constant fix_point_scale : real := real(2 ** memory_data_width - 1);

      variable phase, value, value_scaled, value_rounded : real := 0.0;
      variable result : sine_table_t := (others => (others => '0'));
    begin
      for idx in result'range loop
        phase := real(idx) * index_phase_increment + phase_offset;

        value := sin(phase);
        value_scaled := value * fix_point_scale;
        value_rounded := round(value_scaled);

        result(idx) := to_unsigned(integer(value_rounded), result(0)'length);
      end loop;

      return result;
    end function;

    constant sine_quadrant_table : sine_table_t := calculate_sine_quadrant_table;

    signal memory_sine_m1, memory_cosine_m1 : u_unsigned(memory_data_width - 1 downto 0) := (
      others => '0'
    );
  begin

    ------------------------------------------------------------------------------
    memory : process
    begin
      wait until rising_edge(clk);

      -- Read with the BRAM output register enabled, for better timing on the output side.

      if any_sine_enabled then
        memory_sine_m1 <= sine_quadrant_table(sine_address);
        memory_sine <= memory_sine_m1;
      end if;

      if any_cosine_enabled then
        memory_cosine_m1 <= sine_quadrant_table(cosine_address);
        memory_cosine <= memory_cosine_m1;
      end if;
    end process;

  end block;


  ------------------------------------------------------------------------------
  quadrant_block : block
    signal input_quadrant, result_quadrant : u_unsigned(1 downto 0) := (others => '0');
    signal input_quadrant_phase : u_unsigned(memory_address_width - 1 downto 0) := (others => '0');

    signal memory_sine_signed, memory_cosine_signed : u_signed(
      memory_data_width + 1 - 1 downto 0
    ) := (others => '0');

    -- 'valid' is simple piped along all the way.
    signal valid_pipe : std_ulogic_vector(1 to our_latency) := (others => '0');
    -- 'quadrant' is used in the pipeline step before the result.
    signal quadrant_pipe : unsigned_vec_t(1 to our_latency - 1)(input_quadrant'range) := (
      others => (others => '0')
    );
  begin

    input_quadrant <= input_phase(input_phase'high downto input_phase'high - 1);
    input_quadrant_phase <= input_phase(input_phase'high - 2 downto 0);


    ------------------------------------------------------------------------------
    assign_address : process(all)
      variable sine_address_slv, cosine_address_slv : u_unsigned(input_quadrant_phase'range) := (
        others => '0'
      );
    begin
      -- Could change this to a clocked process to have the BRAM address be driven by FF instead
      -- of LUT.
      -- For wide addresses with both sine and cosine the fanout of 'input_quadrant' might
      -- be a problem.
      -- Making that change increases the FF utilization, but slightly lowers the LUT utilization.

      -- Read out in reverse in the appropriate quadrants (see documentation).
      if input_quadrant = 1 or input_quadrant = 3 then
        sine_address_slv := not input_quadrant_phase;
        cosine_address_slv := input_quadrant_phase;
      else
        sine_address_slv := input_quadrant_phase;
        cosine_address_slv := not input_quadrant_phase;
      end if;

      if any_sine_enabled then
        sine_address <= to_integer(sine_address_slv);
      end if;

      if any_cosine_enabled then
        cosine_address <= to_integer(cosine_address_slv);
      end if;
    end process;


    ------------------------------------------------------------------------------
    pipe : process
    begin
      wait until rising_edge(clk);

      -- Pipe the status signals from the input of the memory to the output.
      valid_pipe <= input_valid & valid_pipe(valid_pipe'left to valid_pipe'right - 1);
      quadrant_pipe <= (
        input_quadrant & quadrant_pipe(quadrant_pipe'left to quadrant_pipe'right - 1)
      );
    end process;

    result_valid <= valid_pipe(valid_pipe'right);
    result_quadrant <= quadrant_pipe(quadrant_pipe'right);

    memory_sine_signed <= '0' & u_signed(memory_sine);
    memory_cosine_signed <= '0' & u_signed(memory_cosine);


    ------------------------------------------------------------------------------
    assign_result : process
      variable sine_in_negative_quadrant, cosine_in_negative_quadrant : boolean := false;
    begin
      wait until rising_edge(clk);

      -- Negate result in the appropriate quadrants (see documentation).
      sine_in_negative_quadrant := result_quadrant = 2 or result_quadrant = 3;

      if enable_sine then
        result_sine <= (- memory_sine_signed) when sine_in_negative_quadrant
          else memory_sine_signed;
      end if;

      if enable_minus_sine then
        result_minus_sine <= memory_sine_signed when sine_in_negative_quadrant
          else (- memory_sine_signed);
      end if;

      cosine_in_negative_quadrant := result_quadrant = 1 or result_quadrant = 2;

      if enable_cosine then
        result_cosine <= (- memory_cosine_signed) when cosine_in_negative_quadrant
          else memory_cosine_signed;
      end if;

      if enable_minus_cosine then
        result_minus_cosine <= memory_cosine_signed when cosine_in_negative_quadrant
          else (- memory_cosine_signed);
      end if;
    end process;

  end block;

end architecture;
