-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the tsfpga project.
-- https://tsfpga.com
-- https://gitlab.com/tsfpga/tsfpga
-- -------------------------------------------------------------------------------------------------
-- Outputs a one cycle pulse after a generic number of assertions of count_enable.
--
-- In the worst case, this module simply creates a counter, but before that it tries to
-- use shift registers as far as possible. This makes the implementation resource efficient
-- on devices with cheap shift registers.
--
-- The period is broken down into factors that are represented using shift
-- registers, with the shift register length being the factor value. By rotating the shift register
-- on each count enable, a fixed period is created.
-- The remaining period is sent to a new instance of period_pulser.
--
-- Step 1:
-- As far as possible and-gate multiple shift registers together. The output of this stage
-- is then sent to the next instance of period_pulser
-- This method only works if the lengths are mutual primes.
-- One or more shift registers may be created.
--
-- Step 2:
-- If the factor cannot be further broken down, add a simple counter.
--
-- -------------------------------------------------------------------------------------------------
-- Example:
-- Let's say that the maximum shift register length is 16.
-- A period of 12*37 can then be achieved using two shift registers of length 4 and 3,
-- and then instantiating a new period_pulser:
-- [0][0][0][1]
--             \
--               [and] -> pulse -> [period_pulser of period 37]
--             /
--    [0][0][1]
-- The next stage will create a counter, because 37 is a prime larger than the maximum shift
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
    period : integer range 2 to integer'high;
    -- The shift register length is device specific.
    -- For Xilinx ultrascale and 7 series devices, it should be set to 32
    shift_register_length : integer
  );
  port (
    clk : in std_logic := '0';
    --
    count_enable : in std_logic := '1';
    pulse : out std_logic := '0'
  );
end entity;

architecture a of periodic_pulser is

  -- Make a type where we can store all the factors used for Step 1.
  -- It doesn't actually need to be this long.
  subtype factors_vec_t is integer_vector(0 to shift_register_length - 1);
  type stage_factors_t is record
    this_stage : factors_vec_t;
    next_stage : integer;
    num_factors_this_stage : integer;
  end record;
  constant stage_factors_init : stage_factors_t := (this_stage => (others => 0), others => 0);

  -- Factorize into mutual primes as far as possible
  function get_mutual_prime_factors(value : positive) return stage_factors_t is
    variable remaining_value : integer := value;
    variable result : stage_factors_t := stage_factors_init;
    variable idx : integer range 0 to shift_register_length := 0;
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

  signal shift_reg_outputs : std_logic_vector(factors_vec_t'range) := (others => '1');
  signal pulse_this_stage : std_logic := '0';

begin

  ------------------------------------------------------------------------------
  -- No further shift register factorization possible, use counter
  ------------------------------------------------------------------------------
  gen_counter : if factors.num_factors_this_stage = 0 generate
    signal tick_count : integer range 0 to period - 1 := 0;
  begin
    count : process
    begin
      wait until rising_edge(clk);

      if count_enable then
        if tick_count = period - 1 then
          tick_count <= 0;
        else
          tick_count <= tick_count + 1;
        end if;
      end if;
    end process;

    pulse <= count_enable when tick_count = period - 1 else '0';
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
        signal shift_reg : std_logic_vector(0 to factors.this_stage(idx) - 1) := (0 => '1', others => '0');
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
    -- Because they are mutual primes, the total period will be the product of their lengthes
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
    do_not_gen_next_stage : if factors.next_stage <= 1 generate
      -- Another stage is not needed
      pulse <= pulse_this_stage;
    end generate;
  end generate;

end architecture;
