-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the hdl-modules project, a collection of reusable, high-quality,
-- peer-reviewed VHDL building blocks.
-- https://hdl-modules.com
-- https://github.com/hdl-modules/hdl-modules
-- -------------------------------------------------------------------------------------------------
-- TODO
-- -------------------------------------------------------------------------------------------------


package axi_stream_bfm_pkg is

  -- If this value is pushed as a byte to the data queue, the BFM will not check the data
  -- of that byte.
  constant axi_stream_bfm_dont_care : integer := -1;

end package;
