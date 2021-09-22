-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the tsfpga project.
-- https://tsfpga.com
-- https://gitlab.com/tsfpga/tsfpga
-- -------------------------------------------------------------------------------------------------
-- Sample a vector from one clock domain to another.
--
-- This modules does not utilize any meta stability protection.
-- It is up to the user to ensure that data_in is stable when sample_value is asserted.
--
-- Note that unlike e.g. resync_level, it is safe to drive the input of this entity with LUTs
-- as well as FFs.
-- -------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;


entity resync_slv_level_on_signal is
  generic (
    width : positive;
    -- Initial value for the ouput that will be set until the first input
    -- value has propagated and been sampled.
    default_value : std_logic_vector(width - 1 downto 0) := (others => '0')
  );
  port (
   data_in : in std_logic_vector(default_value'range);

   clk_out : in std_logic;
   sample_value : in std_logic;
   data_out : out std_logic_vector(default_value'range) := default_value
  );
end entity;

architecture a of resync_slv_level_on_signal is
begin

  ------------------------------------------------------------------------------
  resync_gen : for i in data_in'range generate
  begin

    ------------------------------------------------------------------------------
    resync_on_signal_inst : entity work.resync_level_on_signal
      generic map (
        default_value => default_value(i)
      )
      port map (
        data_in => data_in(i),

        clk_out => clk_out,
        sample_value => sample_value,
        data_out => data_out(i)
      );

  end generate;

end architecture;
