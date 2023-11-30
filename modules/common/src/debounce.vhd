-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the hdl-modules project, a collection of reusable, high-quality,
-- peer-reviewed VHDL building blocks.
-- https://hdl-modules.com
-- https://github.com/hdl-modules/hdl-modules
-- -------------------------------------------------------------------------------------------------
-- Simple debounce mechanism to be used with e.g. the signal from a button or
-- dip switch. It eliminates noise and metastability by requiring the input to have a stable
-- value for a specified number of clock cycles before propagating the value.
--
-- .. note::
--   This entity instantiates a :ref:`resync.resync_level` block (``async_reg`` chain) to make sure
--   the input is not metastable. The :ref:`resync.resync_level` has a scoped constraint file that
--   must be used.
-- -------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

library resync;


entity debounce is
  generic (
    -- Number of cycles the input must be stable for the value to propagate to the result side.
    stable_count : positive;
    -- Initial value for the stable result that will be set until the first real input
    -- value has propagated.
    default_value : std_ulogic := '0'
  );
  port (
    -- Input value that may be metastable and/or noisy
    noisy_input : in std_ulogic := '0';
    --# {{}}
    clk : in std_ulogic;
    stable_result : out std_ulogic := default_value;
    -- Asserted for one clock cycle when stabilized value goes from '0' to '1'.
    stable_rising_edge : out std_ulogic := '0';
    -- Asserted for one clock cycle when stabilized value goes from '1' to '0'.
    stable_falling_edge : out std_ulogic := '0'
  );
end entity;

architecture a of debounce is

  signal noisy_input_resync : std_ulogic := '0';

  signal num_cycles_with_new_value : natural range 0 to stable_count - 1 := 0;
  signal stable_result_p1 : std_ulogic := '0';

begin

  ------------------------------------------------------------------------------
  resync_level_inst : entity resync.resync_level
    generic map (
      -- We do not know the input clock, so set this to false.
      enable_input_register => false,
      default_value => default_value
    )
    port map (
      data_in => noisy_input,
      --
      clk_out => clk,
      data_out => noisy_input_resync
    );


  ------------------------------------------------------------------------------
  main : process
  begin
    wait until rising_edge(clk);

    stable_rising_edge <= stable_result and not stable_result_p1;
    stable_falling_edge <= (not stable_result) and stable_result_p1;

    if noisy_input_resync = stable_result then
      num_cycles_with_new_value <= 0;

    else
      if num_cycles_with_new_value = stable_count - 1 then
        stable_result <= noisy_input_resync;
        num_cycles_with_new_value <= 0;
      else
        num_cycles_with_new_value <= num_cycles_with_new_value + 1;
      end if;
    end if;

    stable_result_p1 <= stable_result;
  end process;

end architecture;
