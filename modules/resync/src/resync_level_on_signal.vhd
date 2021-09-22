-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the tsfpga project.
-- https://tsfpga.com
-- https://gitlab.com/tsfpga/tsfpga
-- -------------------------------------------------------------------------------------------------
-- Sample a bit from one clock domain to another.
--
-- This modules does not utilize any meta stability protection.
-- It is up to the user to ensure that data_in is stable when sample_value is asserted.
--
-- Note that unlike e.g. resync_level, it is safe to drive the input of this entity with LUTs
-- as well as FFs.
-- -------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

library common;
use common.attribute_pkg.all;


entity resync_level_on_signal is
  generic (
    -- Initial value for the ouput that will be set until the first input value has propagated
    -- and been sampled.
    default_value : std_logic := '0'
  );
  port (
   data_in : in std_logic;

   clk_out : in std_logic;
   sample_value : in std_logic;
   data_out : out std_logic := default_value
  );
end entity;

architecture a of resync_level_on_signal is
  signal data_in_int : std_logic;
  attribute dont_touch of data_in_int : signal is "true"; -- Keep net so that we can apply constraint
begin

  data_in_int <= data_in;


  ------------------------------------------------------------------------------
  main : process
  begin
    wait until rising_edge(clk_out);
    if sample_value then
      data_out <= data_in_int;
    end if;
  end process;

end architecture;
