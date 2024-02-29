-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the hdl-modules project, a collection of reusable, high-quality,
-- peer-reviewed VHDL building blocks.
-- https://hdl-modules.com
-- https://github.com/hdl-modules/hdl-modules
-- -------------------------------------------------------------------------------------------------
-- Package with constants/types/functions for the LFSR ecosystem.
-- -------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

library common;
use common.types_pkg.all;


package lfsr_pkg is

  -- The maximum-length LFSR have at most five non-zero taps.
  subtype non_zero_taps_t is natural_vec_t(0 to 4);

  -- The table of non-zero taps for each LFSR length.
  -- Index is the LFSR length.
  type non_zero_tap_table_t is array(2 to 64) of non_zero_taps_t;

  -- We do not include the input and output bits in the table, to save space.
  -- They are implied.
  -- The value of 0 means unused.
  -- The values differ between Xilinx' and Wikipedia's table for 12, 13, 14 and 19.
  -- Both sets of values have been verified to work.
  -- The table uses Xilinx values consistently, except for 2 which comes from wikipedia.
  constant non_zero_tap_table : non_zero_tap_table_t := (
    2 => (1, 0, 0, 0, 0),
    3 => (2, 0, 0, 0, 0),
    4 => (3, 0, 0, 0, 0),
    5 => (3, 0, 0, 0, 0),
    6 => (5, 0, 0, 0, 0),
    7 => (6, 0, 0, 0, 0),
    8 => (6, 5, 4, 0, 0),
    --
    9 => (5, 0, 0, 0, 0),
    10 => (7, 0, 0, 0, 0),
    11 => (9, 0, 0, 0, 0),
    12 => (6, 4, 1, 0, 0),
    13 => (4, 3, 1, 0, 0),
    14 => (5, 3, 1, 0, 0),
    15 => (14, 0, 0, 0, 0),
    16 => (15, 13, 4, 0, 0),
    --
    17 => (14, 0, 0, 0, 0),
    18 => (11, 0, 0, 0, 0),
    19 => (6, 2, 1, 0, 0),
    20 => (17, 0, 0, 0, 0),
    21 => (19, 0, 0, 0, 0),
    22 => (21, 0, 0, 0, 0),
    23 => (18, 0, 0, 0, 0),
    24 => (23, 22, 17, 0, 0),
    --
    25 => (22, 0, 0, 0, 0),
    26 => (6, 2, 1, 0, 0),
    27 => (5, 2, 1, 0, 0),
    28 => (25, 0, 0, 0, 0),
    29 => (27, 0, 0, 0, 0),
    30 => (6, 4, 1, 0, 0),
    31 => (28, 0, 0, 0, 0),
    32 => (22, 2, 1, 0, 0),
    --
    33 => (20, 0, 0, 0, 0),
    34 => (27, 2, 1, 0, 0),
    35 => (33, 0, 0, 0, 0),
    36 => (25, 0, 0, 0, 0),
    37 => (5, 4, 3, 2, 1),
    38 => (6, 5, 1, 0, 0),
    39 => (35, 0, 0, 0, 0),
    40 => (38, 21, 19, 0, 0),
    --
    41 => (38, 0, 0, 0, 0),
    42 => (41, 20, 19, 0, 0),
    43 => (42, 38, 37, 0, 0),
    44 => (43, 18, 17, 0, 0),
    45 => (44, 42, 41, 0, 0),
    46 => (45, 26, 25, 0, 0),
    47 => (42, 0, 0, 0, 0),
    48 => (47, 21, 20, 0, 0),
    --
    49 => (40, 0, 0, 0, 0),
    50 => (49, 24, 23, 0, 0),
    51 => (50, 36, 35, 0, 0),
    52 => (49, 0, 0, 0, 0),
    53 => (52, 38, 37, 0, 0),
    54 => (53, 18, 17, 0, 0),
    55 => (31, 0, 0, 0, 0),
    56 => (55, 35, 34, 0, 0),
    --
    57 => (50, 0, 0, 0, 0),
    58 => (39, 0, 0, 0, 0),
    59 => (58, 38, 37, 0, 0),
    60 => (59, 0, 0, 0, 0),
    61 => (60, 46, 45, 0, 0),
    62 => (61, 6, 5, 0, 0),
    63 => (62, 0, 0, 0, 0),
    64 => (63, 61, 60, 0, 0)
  );

  -- Get a bitmask, '1' or '0', wether the bit in the shift register shall be XOR'd.
  function get_lfsr_taps(
    lfsr_length : positive range non_zero_tap_table'range
  ) return std_ulogic_vector;

  -- Get the minimum LFSR length that can realize shifting the state the desired number of steps
  -- each clock cycle.
  function get_required_lfsr_length(
    shift_count : positive; minimum_length : positive
  ) return positive;

end package;

package body lfsr_pkg is

  function get_lfsr_taps(
    lfsr_length : positive range non_zero_tap_table'range
  ) return std_ulogic_vector is
    constant non_zero_taps : non_zero_taps_t := non_zero_tap_table(lfsr_length);
    variable result : std_ulogic_vector(lfsr_length downto 1) := (others => '0');
  begin
    -- In case of a Fibonacci implementation, the high bit is the output bit.
    -- And it is always included in the XOR, no matter what the length is.
    -- In the case of Galois implementation, the high bit is the input bit.
    -- It is handled separately, and not included in the XOR logic, since it is the input bit.
    -- So, Fibonacci needs the high bit to be 1, and it does not matter for Galois.
    -- Hence we cat set it always to one, which means we can save one number in the table above.
    result(result'high) := '1';

    for tap_idx in result'range loop
      for non_zero_tap_idx in non_zero_taps'range loop
        if tap_idx = non_zero_taps(non_zero_tap_idx) then
          result(tap_idx) := '1';
        end if;
      end loop;
    end loop;

    return result;
  end function;

  function get_required_lfsr_length(
    shift_count : positive; minimum_length : positive
  ) return positive is
    variable length_ok : boolean := false;
  begin
    for lfsr_length in non_zero_tap_table'range loop
      length_ok := true;
      for tap_idx in non_zero_tap_table(lfsr_length)'range loop
        if non_zero_tap_table(lfsr_length)(tap_idx) /= 0 then
          if non_zero_tap_table(lfsr_length)(tap_idx) < shift_count then
            length_ok := false;
          end if;
        end if;
      end loop;

      if lfsr_length < minimum_length then
        length_ok := false;
      end if;

      if length_ok then
        return lfsr_length;
      end if;
    end loop;

    assert false
      report "No suitable LFSR length found for " & integer'image(shift_count)
      severity failure;
  end function;

end package body;
