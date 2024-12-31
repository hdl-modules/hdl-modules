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
  -- The BFMs work on a byte-by-byte basis, so this value will never be used for real data.
  -- When a testbench uses this "dont't care" mechanism, it is recommended to use
  -- 'bit_width' of 0 and 'is_signed' of false in the 'integer_array_t' so this value fits.
  constant axi_stream_bfm_dont_care : integer := 256;

end package;
