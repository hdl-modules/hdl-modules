-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the hdl-modules project, a collection of reusable, high-quality,
-- peer-reviewed VHDL building blocks.
-- https://hdl-modules.com
-- https://github.com/hdl-modules/hdl-modules
-- -------------------------------------------------------------------------------------------------
-- Sample a vector from one clock domain to another.
--
-- .. note::
--   This entity instantiates :ref:`resync.resync_level_on_signal` which has a scoped constraint
--   file that must be used.
--
-- This modules does not utilize any meta stability protection.
-- It is up to the user to ensure that ``data_in`` is stable when ``sample_value`` is asserted.
-- It will not be able to handle pulses in the data and does not feature any bit coherency.
-- Hence it can only be used with semi-static "level"-type signals.
--
-- Note that unlike e.g. :ref:`resync.resync_level`, it is safe to drive the input of this entity
-- with LUTs as well as FFs.
-- -------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;


entity resync_slv_level_on_signal is
  generic (
    width : positive;
    -- Initial value for the output that will be set until the first input
    -- value has propagated and been sampled.
    default_value : std_ulogic_vector(width - 1 downto 0) := (others => '0')
  );
  port (
   data_in : in std_ulogic_vector(default_value'range);
   --# {{}}
   clk_out : in std_ulogic;
   sample_value : in std_ulogic;
   data_out : out std_ulogic_vector(default_value'range) := default_value
  );
end entity;

architecture a of resync_slv_level_on_signal is
begin

  ------------------------------------------------------------------------------
  resync_gen : for data_idx in data_in'range generate
  begin

    ------------------------------------------------------------------------------
    resync_on_signal_inst : entity work.resync_level_on_signal
      generic map (
        default_value => default_value(data_idx)
      )
      port map (
        data_in => data_in(data_idx),
        --
        clk_out => clk_out,
        sample_value => sample_value,
        data_out => data_out(data_idx)
      );

  end generate;

end architecture;
