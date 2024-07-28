-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the hdl-modules project, a collection of reusable, high-quality,
-- peer-reviewed VHDL building blocks.
-- https://hdl-modules.com
-- https://github.com/hdl-modules/hdl-modules
-- -------------------------------------------------------------------------------------------------
-- Simple debounce mechanism to be used with asynchronous FPGA input pins.
-- E.g. the signal from a button or dip switch.
-- It eliminates noise, glitches and metastability by requiring the input to have a stable
-- value for a specified number of clock cycles before propagating the value.
-- -------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

library common;
use common.attribute_pkg.all;
use common.common_pkg.if_then_else;

library resync;


entity debounce is
  generic (
    -- Number of cycles the input must be stable for the value to propagate to the result side.
    stable_count : positive;
    -- Initial value for the stable result that will be set until the first real input
    -- value has propagated.
    default_value : std_ulogic := '0';
    -- Enable the "IOB" attribute on the first register, which instructs the synthesis tool
    -- to place the register in the I/O buffer, minimizing latency.
    enable_iob : boolean := true
  );
  port (
    -- Input value that may be metastable and/or noisy.
    noisy_input : in std_ulogic := '0';
    --# {{}}
    clk : in std_ulogic;
    -- The stable value of the input, with noise, glitches and metastability removed.
    stable_result : out std_ulogic := default_value;
    -- Asserted for one clock cycle when stabilized value goes from '0' to '1'.
    stable_rising_edge : out std_ulogic := '0';
    -- Asserted for one clock cycle when stabilized value goes from '1' to '0'.
    stable_falling_edge : out std_ulogic := '0'
  );
end entity;

architecture a of debounce is

  signal non_metastable_input, non_metastable_input_m1, non_metastable_input_m2 : std_ulogic := '0';

  -- Set either the IOB constraint, to place the register in I/O buffer, or async_reg
  -- constraint to place the register in the same chain as the other two.
  attribute iob of non_metastable_input_m2 : signal is if_then_else(enable_iob, "true", "false");
  attribute async_reg of non_metastable_input_m2 : signal is if_then_else(
    enable_iob, "false", "true"
  );

  -- Ensure FFs are not optimized/modified, and placed in the same slice to minimize MTBF.
  attribute async_reg of non_metastable_input_m1 : signal is "true";
  attribute async_reg of non_metastable_input : signal is "true";

begin

  ------------------------------------------------------------------------------
  eliminate_metastability : process
  begin
    wait until rising_edge(clk);

    non_metastable_input <= non_metastable_input_m1;
    non_metastable_input_m1 <= non_metastable_input_m2;
    non_metastable_input_m2 <= noisy_input;
  end process;


  ------------------------------------------------------------------------------
  main_block : block
    signal num_cycles_with_new_value : natural range 0 to stable_count - 1 := 0;
    signal stable_result_p1 : std_ulogic := '0';
  begin

    ------------------------------------------------------------------------------
    main : process
    begin
      wait until rising_edge(clk);

      stable_rising_edge <= stable_result and not stable_result_p1;
      stable_falling_edge <= (not stable_result) and stable_result_p1;

      if non_metastable_input = stable_result then
        num_cycles_with_new_value <= 0;

      else
        if num_cycles_with_new_value = stable_count - 1 then
          stable_result <= non_metastable_input;
          num_cycles_with_new_value <= 0;
        else
          num_cycles_with_new_value <= num_cycles_with_new_value + 1;
        end if;
      end if;

      stable_result_p1 <= stable_result;
    end process;

  end block;

end architecture;
