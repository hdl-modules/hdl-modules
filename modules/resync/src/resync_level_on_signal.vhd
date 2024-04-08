-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the hdl-modules project, a collection of reusable, high-quality,
-- peer-reviewed VHDL building blocks.
-- https://hdl-modules.com
-- https://github.com/hdl-modules/hdl-modules
-- -------------------------------------------------------------------------------------------------
-- Sample a bit from one clock domain to another.
--
-- .. note::
--   This entity has a scoped constraint file that must be used.
--   See the ``scoped_constraints`` folder for the file with the same name.
--
-- This entity does not utilize any meta stability protection.
-- It is up to the user to ensure that ``data_in`` is stable when ``sample_value`` is asserted.
--
-- Note that unlike e.g. :ref:`resync.resync_level`, it is safe to drive the input of this entity
-- with LUTs as well as FFs.
-- -------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

library common;
use common.attribute_pkg.all;


entity resync_level_on_signal is
  generic (
    -- Initial value for the output that will be set until the first input value has propagated
    -- and been sampled.
    default_value : std_ulogic := '0'
  );
  port (
   data_in : in std_ulogic;
   --# {{}}
   clk_out : in std_ulogic;
   sample_value : in std_ulogic;
   data_out : out std_ulogic := default_value
  );
end entity;

architecture a of resync_level_on_signal is

  signal data_in_int : std_ulogic := '0';

  -- Keep net so we can apply constraints.
  attribute dont_touch of data_in_int : signal is "true";

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
