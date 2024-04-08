-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the hdl-modules project, a collection of reusable, high-quality,
-- peer-reviewed VHDL building blocks.
-- https://hdl-modules.com
-- https://github.com/hdl-modules/hdl-modules
-- -------------------------------------------------------------------------------------------------
-- Resynchronize a data vector from one clock domain to another.
-- Unlike e.g. :ref:`resync.resync_slv_level`, this entity contains a mechanism that guarantees
-- bit coherency.
--
-- .. note::
--   This entity has a scoped constraint file that must be used.
--   See the ``scoped_constraints`` folder for the file with the same name.
--
-- This entity is great for resynchronizing e.g. a control/status register or a counter value,
-- which are scenarios where bit coherency is crucial.
-- It will not be able to handle pulses in the input data, it is very likely that pulses will
-- be missed. Hence the "level" in the name.
--
-- Note that unlike e.g. :ref:`resync.resync_level`, it is safe to drive the input of this entity
-- with LUTs as well as FFs.
--
-- A level signal is rotated around between input and output side, with three registers in each
-- direction. The level toggles for each roundtrip, and data is sampled on each side upon a level
-- transition.
-- This ensures that data is sampled on the output side only when we know that the sampled
-- input data is stable. Conversely, input data is only sampled when we know that data has been
-- sampled on the output in a stable fashion.
--
--
-- Latency and resource utilization
-- ________________________________
--
-- The latency is less than or equal to
--
--   3 * period(clk_in) + 3 * period(clk_out)
--
-- This is also the sampling period of the signal. As such this resync is not suitable for signals
-- that change quickly. It is instead typically used for e.g. monotonic counters, slow moving status
-- words, and other data where the different bits are correlated.
--
-- The LUT utilization is always 3. The FF utilization increases linearly at a rate
-- of ``2 * width``.
--
-- Compared to :ref:`resync.resync_counter` this entity has lower LUT and FF usage in all scenarios.
-- It does however have higher latency.
--
-- Another way of achieving the same functionality is to use a shallow :ref:`fifo.asynchronous_fifo`
-- with ``write_valid`` and ``read_ready`` statically set to ``1``.
-- This entity will however have lower LUT usage.
-- FF usage is lower up to around width 32 where this entity will consume more FF.
-- Latency is about the same for both.
-- -------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;


entity resync_slv_level_coherent is
  generic (
    width : positive;
    -- Initial value for the output that will be set for a few cycles before the first input
    -- value has propagated.
    default_value : std_ulogic_vector(width - 1 downto 0) := (others => '0')
  );
  port (
    clk_in : in std_ulogic;
    data_in : in std_ulogic_vector(default_value'range);
    --# {{}}
    clk_out : in std_ulogic;
    data_out : out std_ulogic_vector(default_value'range) := default_value
  );
end entity;

architecture a of resync_slv_level_coherent is

  signal data_in_sampled, data_out_int : std_ulogic_vector(data_in'range) := default_value;

  constant level_default_value : std_ulogic := '0';
  signal input_level, input_level_m1, input_level_m1_not_inverted, output_level, output_level_m1
    : std_ulogic := level_default_value;

begin

  ------------------------------------------------------------------------------
  resync_level_to_output_inst : entity work.resync_level
    generic map (
      -- Value is driven by a FF so this is not needed
      enable_input_register => false,
      default_value => level_default_value
    )
    port map (
      clk_in => clk_in,
      data_in => input_level,
      --
      clk_out => clk_out,
      data_out => output_level_m1
    );


  ------------------------------------------------------------------------------
  resync_level_to_input_inst : entity work.resync_level
    generic map (
      -- Value is driven by a FF so this is not needed
      enable_input_register => false,
      default_value => level_default_value
    )
    port map (
      clk_in => clk_out,
      data_in => output_level,
      --
      clk_out => clk_in,
      data_out => input_level_m1_not_inverted
    );

  -- Invert here, before the last input level register, so that the output level async_reg is
  -- driven by an FF and not a LUT.
  input_level_m1 <= not input_level_m1_not_inverted;


  ------------------------------------------------------------------------------
  handle_input : process
  begin
    wait until rising_edge(clk_in);

    if input_level /= input_level_m1 then
      data_in_sampled <= data_in;
    end if;

    input_level <= input_level_m1;
  end process;


  ------------------------------------------------------------------------------
  handle_output : process
  begin
    wait until rising_edge(clk_out);

    if output_level /= output_level_m1 then
      data_out_int <= data_in_sampled;
    end if;

    output_level <= output_level_m1;
  end process;

  data_out <= data_out_int;

end architecture;
