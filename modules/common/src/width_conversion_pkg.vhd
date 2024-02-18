-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the hdl-modules project, a collection of reusable, high-quality,
-- peer-reviewed VHDL building blocks.
-- https://hdl-modules.com
-- https://github.com/hdl-modules/hdl-modules
-- -------------------------------------------------------------------------------------------------
-- Package with functions for :ref:`common.width_conversion`.
-- -------------------------------------------------------------------------------------------------


package width_conversion_pkg is

  function width_conversion_output_user_width(
    input_user_width : natural; input_data_width : positive; output_data_width : positive
  ) return natural;

end package;

package body width_conversion_pkg is

  function width_conversion_output_user_width(
    input_user_width : natural; input_data_width : positive; output_data_width : positive
  ) return natural is
  begin
    -- Downsizing, i.e. one 'input' beat will result in multiple 'output' beats.
    -- The same input 'user' value will be sent on multiple 'output' beats.
    if input_data_width > output_data_width then
      return input_user_width;
    end if;

    -- Upsizing, i.e. multiple 'input' beats will result in one 'output' beat.
    -- The output 'user' value will be the concatenated input 'user' values of all the input beats
    -- that produced the output value.
    return input_user_width * (output_data_width / input_data_width);
  end function;

end package body;
