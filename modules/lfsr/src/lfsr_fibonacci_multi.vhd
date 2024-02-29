-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the hdl-modules project, a collection of reusable, high-quality,
-- peer-reviewed VHDL building blocks.
-- https://hdl-modules.com
-- https://github.com/hdl-modules/hdl-modules
-- -------------------------------------------------------------------------------------------------
-- This entity implements a maximum-length linear feedback shift register (LFSR) with the
-- Fibonacci structure and multiple output bits.
-- See :ref:`lfsr.lfsr_fibonacci_single` for a single-bit single-step variant.
--
-- This implementation will shift the LFSR state ``output_width`` times for each clock cycle,
-- so that consecutive output words will not have a strong inter-sample correlation.
-- The entity will automatically find a suitable LFSR length for the given output width.
-- Since multiple bits of the LFSR state are used as output, this LFSR can in general not be
-- implemented with SRLs, unlike :ref:`lfsr.lfsr_fibonacci_single`.
--
-- The ``seed`` generic can be used to alter the initial state of the LFSR.
--
--
-- Example
-- _______
--
-- Consider a 15-bit maximum-length LFSR, which is defined by the
-- polynomial :math:`x^{15} + x^{14} + 1`.
-- With a Fibonacci XOR structure, it is implemented like this:
--
-- .. figure:: lfsr_fibonacci_15.png
--
--   Maximum-length Fibonacci LFSR.
--
-- When this LFSR is stepped once, its next state will be
--
-- .. code:: none
--
--   state[15] = state[14]
--   state[14] = state[13]
--   state[13] = state[12]
--   state[12] = state[11]
--   state[11] = state[10]
--   state[10] = state[9]
--   state[9] = state[8]
--   state[8] = state[7]
--   state[7] = state[6]
--   state[6] = state[5]
--   state[5] = state[4]
--   state[4] = state[3]
--   state[3] = state[2]
--   state[2] = state[1]
--   state[1] = state[15] XOR state[14]
--
-- and the ``state[15]`` signal can be used as output.
-- When stepped twice, the next LFSR state will be
--
-- .. code:: none
--
--   state[15] = state[13]
--   state[14] = state[12]
--   state[13] = state[11]
--   state[12] = state[10]
--   state[11] = state[9]
--   state[10] = state[8]
--   state[9] = state[7]
--   state[8] = state[6]
--   state[7] = state[5]
--   state[6] = state[4]
--   state[5] = state[3]
--   state[4] = state[2]
--   state[3] = state[1]
--   state[2] = state[15] XOR state[14]
--   state[1] = state[14] XOR state[13]
--
-- and the ``state[15:14]`` signal can be used as output.
-- When stepped thrice, the next LFSR state will be
--
-- .. code:: none
--
--   state[15] = state[12]
--   state[14] = state[11]
--   state[13] = state[10]
--   state[12] = state[9]
--   state[11] = state[8]
--   state[10] = state[7]
--   state[9] = state[6]
--   state[8] = state[5]
--   state[7] = state[4]
--   state[6] = state[3]
--   state[5] = state[2]
--   state[4] = state[1]
--   state[3] = state[15] XOR state[14]
--   state[2] = state[14] XOR state[13]
--   state[1] = state[13] XOR state[12]
--
-- and the ``state[15:13]`` signal can be used as output.
-- This is want this entity implements, in a generic fashion, by generalizing the shift operations
-- outlined above.
-- For any LFSR length and any step count.
--
-- Note that it is possible to use a shift count that is greater than the lowest tap index.
-- This complicates the code, however, and yields more complicated XOR equations.
-- Hence, this entity will always use an LFSR length where the lowest tap index is at least
-- the ``output_width``.
-- In the example above, with a 15-bit LFSR, an output width of up to 14 can be supported.
-- -------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library common;
use common.types_pkg.all;
use common.attribute_pkg.all;

use work.lfsr_pkg.all;


entity lfsr_fibonacci_multi is
  generic (
    -- The number of output bits.
    -- For each clock cycle, the LFSR will be stepped this many times.
    output_width : positive;
    -- Optionally, specify a minimum LFSR state length.
    minimum_lfsr_length : positive := output_width;
    -- Optionally alter the initial state of the LFSR.
    seed : std_ulogic_vector(
      get_required_lfsr_length(shift_count=>output_width, minimum_length=>minimum_lfsr_length)
      downto
      1
    ) := (others => '1')
  );
  port(
    clk : in std_ulogic;
    --# {{}}
    enable : in std_ulogic := '1';
    output : out std_ulogic_vector(output_width - 1 downto 0) := (others => '0')
  );
end entity;

architecture a of lfsr_fibonacci_multi is

  -- Rename constants for readability.
  constant shift_count : positive := output_width;
  constant lfsr_length : positive := seed'length;

  -- This is reverse order compared to how it's drawn on wikipedia, but it's more convenient
  -- like this.
  signal state : std_ulogic_vector(lfsr_length downto 1) := seed;

  -- Encourage Vivado to infer SRLs as much as possible.
  attribute shreg_extract of state : signal is "yes";

  -- The non-zero tap table excludes the implied output bit of a single-bit LFSR.
  -- Insert this value into the table to make the state code below simpler.
  constant taps : natural_vec_t(0 to 5) := (
    0=>lfsr_length, 1 to 5 => non_zero_tap_table(lfsr_length)
  );

begin

  assert unsigned(seed) /= 0 report "Seed all zeros is an invalid state" severity failure;

  -- Slice the output bits (the high indexes when using a Fibonacci structure).
  output <= state(state'high downto state'high - output'length + 1);


  ------------------------------------------------------------------------------
  print : process
  begin
    report "Output width: " & integer'image(output_width);
    report "LFSR length: " & integer'image(lfsr_length);
    for tap_idx in taps'range loop
      report "Taps[" & integer'image(tap_idx) & "]: " & integer'image(taps(tap_idx));
    end loop;

    wait;
  end process;


  ------------------------------------------------------------------------------
  main : process
    variable next_state : std_ulogic := '0';
    variable tap_offset : natural := 0;
  begin
    wait until rising_edge(clk);

    for state_idx in state'range loop
      if state_idx > shift_count then
        next_state := state(state_idx - shift_count);
      else

        tap_offset := shift_count - state_idx;
        next_state := '0';

        for tap_idx in taps'range loop
          if taps(tap_idx) /= 0 then
            -- Note that both XOR and XNOR seem to work here.
            -- Wikipedia uses XOR, Xilinx application note uses XNOR.
            -- Both have been simulated with very similar result.
            next_state := next_state xnor state(taps(tap_idx) - tap_offset);
          end if;
        end loop;
      end if;

      if enable then
        state(state_idx) <= next_state;
      end if;
    end loop;
  end process;

end architecture;
