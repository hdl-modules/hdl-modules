-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the hdl-modules project, a collection of reusable, high-quality,
-- peer-reviewed VHDL building blocks.
-- https://hdl-modules.com
-- https://github.com/hdl-modules/hdl-modules
-- -------------------------------------------------------------------------------------------------
-- This entity implements a maximum-length linear feedback shift register (LFSR) with the
-- Fibonacci structure.
-- The LFSR will be shifted one step per cycle, and the output is the last bit of the LFSR.
-- The implementation maps very efficiently to SRLs, which can be seen in the
-- :ref:`lfsr.lfsr_fibonacci_single.resource_utilization` table below.
--
-- The ``seed`` generic can be used to alter the initial state of the LFSR.
-- -------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

use work.lfsr_pkg.all;


entity lfsr_fibonacci_single is
  generic (
    -- The number of state bits in the LFSR.
    lfsr_length : positive range non_zero_tap_table'range;
    -- Optionally set the initial state of the LFSR.
    seed : std_ulogic_vector(lfsr_length downto 1) := (others => '1')
  );
  port(
    clk : in std_ulogic;
    --# {{}}
    enable : in std_ulogic := '1';
    output : out std_ulogic := '0'
  );
end entity;

architecture a of lfsr_fibonacci_single is

begin

  ------------------------------------------------------------------------------
  lfsr_fibonacci_multi_inst : entity work.lfsr_fibonacci_multi
    generic map (
      output_width => 1,
      minimum_lfsr_length => lfsr_length,
      seed => seed
    )
    port map (
      clk => clk,
      --
      enable => enable,
      output(0) => output
    );

end architecture;
