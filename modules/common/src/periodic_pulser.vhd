-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the hdl-modules project, a collection of reusable, high-quality,
-- peer-reviewed VHDL building blocks.
-- https://hdl-modules.com
-- https://github.com/hdl-modules/hdl-modules
-- -------------------------------------------------------------------------------------------------
-- Outputs a one cycle ``pulse`` after a generic number of assertions of ``count_enable``.
--
-- Shift registers are used as far as possible to create the pulse. This makes the
-- implementation resource efficient on devices with cheap shift registers
-- (such as SRLs in Xilinx devices). In the worst case a single counter is created.
--
-- The ``period`` is broken down into factors that are represented using shift
-- registers, with the shift register length being the factor value. By rotating the shift register
-- on each ``count_enable``, a fixed period is created.
-- When possible, multiple shift registers are AND-gated to create a longer
-- period. For example a period of 30 can be achieved by gating two registers of length 10
-- and 3. This method only works if the lengths are mutual primes (i.e. the greatest common
-- divisor is 1).
--
-- If the remaining factor is not 1 after the shift registers have been added, a new instance of
-- this module is added through recursion.
--
-- If ``period`` cannot be factorized into one or more shift registers, recursion ends with
-- either a simple counter or a longer shift register (depending on the size of the factor).
--
-- Example
-- _______
--
-- Let's say that the maximum shift register length is 16.
-- A period of 510 = 10 * 3 * 17 can then be achieved using two shift registers of length
-- 10 and 3, and then instantiating a new :ref:`common.periodic_pulser`
--
-- .. code-block:: none
--
--    [0][0][0][0][0][0][0][0][0][1]
--                                  \
--                                   [AND] -> pulse -> [periodic_pulser with period 17]
--                                  /
--                         [0][0][1]
--
-- The next stage will create a counter, because 17 is a prime larger than the maximum shift
-- register length.
-- -------------------------------------------------------------------------------------------------

library ieee;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;

library math;
use math.math_pkg.all;


entity periodic_pulser is
  generic (
    -- The period between pulses
    period : positive range 2 to integer'high;
    -- The shift register length is device specific.
    -- For Xilinx UltraScale and 7 series devices, it should be set to 33.
    shift_register_length : positive
  );
  port (
    clk : in std_ulogic;
    --# {{}}
    count_enable : in std_ulogic := '1';
    pulse : out std_ulogic := '0'
  );
end entity;

architecture a of periodic_pulser is

  -- Make a type where we can store all the factors used for Step 1.
  -- It doesn't actually need to be this long.
  subtype factors_vec_t is integer_vector(0 to shift_register_length - 1);
  type stage_factors_t is record
    this_stage : factors_vec_t;
    next_stage : natural;
    num_factors_this_stage : natural;
  end record;
  constant stage_factors_init : stage_factors_t := (this_stage => (others => 0), others => 0);

  -- Factorize into mutual primes as far as possible
  function get_mutual_prime_factors(value : positive) return stage_factors_t is
    variable remaining_value : natural := value;
    variable result : stage_factors_t := stage_factors_init;
    variable idx : natural range 0 to shift_register_length := 0;
  begin
    -- Start with shift_register_length and work downward, as we want as large factors as
    -- possible in each shift register
    for factor_to_test in minimum(shift_register_length, value) downto 2 loop
      if remaining_value rem factor_to_test = 0 then
        if idx = 0 then
          -- First factor discovered
          remaining_value := remaining_value / factor_to_test;
          result.this_stage(idx) := factor_to_test;
          idx := idx + 1;
        else
          -- We have a candidate, but check that it is a mutual prime with other factors
          if is_mutual_prime(factor_to_test, result.this_stage(0 to idx - 1)) then
            remaining_value := remaining_value / factor_to_test;
            result.this_stage(idx) := factor_to_test;
            idx := idx + 1;
          end if;
        end if;
      end if;
    end loop;

    result.next_stage := remaining_value;
    result.num_factors_this_stage := idx;

    return result;
  end function;

  constant factors : stage_factors_t := get_mutual_prime_factors(period);

  signal shift_reg_outputs : std_ulogic_vector(factors_vec_t'range) := (others => '1');
  signal pulse_this_stage : std_ulogic := '0';

begin

  ------------------------------------------------------------------------------
  -- No further shift register factorization possible
  ------------------------------------------------------------------------------
  gen_last_stage : if factors.num_factors_this_stage = 0 generate
  begin

    -- If the period doesn't fit in a few luts, we create a counter
    gen_counter : if period > shift_register_length * 4 generate
      constant num_counter_bits : positive := num_bits_needed(period - 1);

      -- Use an unsigned instead of integer for this counter, so that we can let it wrap.
      -- Start at a value where we have 'period' number ticks until an overflow.
      constant start_value : positive := 2 ** num_counter_bits - period;
      constant start_value_unsigned : unsigned(num_counter_bits - 1 downto 0) :=
        to_unsigned(start_value, num_counter_bits);

      signal tick_count : u_unsigned(num_counter_bits - 1 downto 0) := start_value_unsigned;
      -- Add one extra bit here, this is used to see if there was an overflow, at which point we
      -- should issue the pulse and then start over
      signal tick_count_next : u_unsigned(num_counter_bits + 1 - 1 downto 0) := (others => '0');
    begin
      count : process
      begin
        wait until rising_edge(clk);

        -- By default, increment on clock enable
        if count_enable then
          tick_count <= tick_count_next(tick_count'range);
        end if;

        -- Reset counter when the pulse is output
        if pulse then
          tick_count <= start_value_unsigned;
        end if;
      end process;

      tick_count_next <= ("0" & tick_count) + 1;

      -- Send pulse upon counter overflow, which is cheaper than doing numerical comparison
      -- on all bits.
      pulse <= count_enable and tick_count_next(tick_count_next'high);

    -- The period fits in a few luts, so create a long shift register
    else generate
      signal shift_reg : std_ulogic_vector(0 to period - 1) := (0 => '1', others => '0');
    begin
      shift : process
      begin
        wait until rising_edge(clk);
        if count_enable then
          shift_reg <= shift_reg(shift_reg'high) & shift_reg(0 to shift_reg'high - 1);
        end if;
      end process;

      pulse <= count_enable and shift_reg(shift_reg'high);

    end generate;

  end generate;


  ------------------------------------------------------------------------------
  -- Create one or more shift registers
  -- This generate is "else generate" with gen_counter, but "else generate"
  -- statements seem to fail recursive instantiation in Vivado.
  ------------------------------------------------------------------------------
  gen_shift_registers : if factors.num_factors_this_stage > 0 generate
    gen_mutual_prime_srls : for idx in factors.this_stage'range generate
      gen_only_if_not_0 : if factors.this_stage(idx) /= 0 generate
        -- Create a shift register of the length of the current factor factor
        signal shift_reg : std_ulogic_vector(0 to factors.this_stage(idx) - 1) :=
          (0 => '1', others => '0');
      begin
        shift : process
        begin
          wait until rising_edge(clk);
          if count_enable then
            shift_reg <= shift_reg(shift_reg'high) & shift_reg(0 to shift_reg'high - 1);
          end if;
        end process;

        shift_reg_outputs(idx) <= shift_reg(shift_reg'high);
      end generate;
    end generate;

    -- Gate all shift register results.
    -- Because they are mutual primes, the total period will be the product of their lengths
    pulse_this_stage <= and(shift_reg_outputs) and count_enable;


    ------------------------------------------------------------------------------
    -- Instantiate next stage with the remaining period, or end recursion if done
    ------------------------------------------------------------------------------
    gen_next_stage : if factors.next_stage > 1 generate

      periodic_pulser_next_stage : entity work.periodic_pulser
        generic map (
          period => factors.next_stage,
          shift_register_length => shift_register_length)
        port map (
          clk => clk,
          count_enable => pulse_this_stage,
          pulse => pulse
        );
    end generate;

    -- Note: Cannot use else-generate here, as that breaks recursion in Vivado
    do_not_gen_next_stage : if factors.next_stage <= 1 generate

      -- Another stage is not needed
      pulse <= pulse_this_stage;
    end generate;

  end generate;

end architecture;
