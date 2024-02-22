-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the hdl-modules project, a collection of reusable, high-quality,
-- peer-reviewed VHDL building blocks.
-- https://hdl-modules.com
-- https://github.com/hdl-modules/hdl-modules
-- -------------------------------------------------------------------------------------------------
-- Convenience methods for working with VUnit ``integer_array_t``.
-- Used by some BFMs.
-- -------------------------------------------------------------------------------------------------

library vunit_lib;
use vunit_lib.integer_array_pkg.all;


package integer_array_bfm_pkg is

  impure function concatenate_integer_arrays(
    base_array : integer_array_t;
    end_array : integer_array_t
  ) return integer_array_t;

end package;

package body integer_array_bfm_pkg is

  -- Concatenate two arrays with data.
  -- Will copy contents to new array, will not deallocate either of the input arrays.
  impure function concatenate_integer_arrays(
    base_array : integer_array_t;
    end_array : integer_array_t
  ) return integer_array_t is
    constant total_length : natural := length(base_array) + length(end_array);
    variable result : integer_array_t := new_1d(
      length=>total_length,
      bit_width=>bit_width(base_array),
      is_signed=>is_signed(base_array)
    );
  begin
    assert bit_width(base_array) = bit_width(end_array)
      report "Can only concatenate similar arrays";
    assert is_signed(base_array) = is_signed(end_array)
      report "Can only concatenate similar arrays";

    assert height(base_array) = 1 report "Can only concatenate one dimensional arrays";
    assert height(end_array) = 1 report "Can only concatenate one dimensional arrays";

    assert depth(base_array) = 1 report "Can only concatenate one dimensional arrays";
    assert depth(end_array) = 1 report "Can only concatenate one dimensional arrays";

    for byte_idx in 0 to length(base_array) - 1 loop
      set(
        arr=>result,
        idx=>byte_idx,
        value=>get(arr=>base_array, idx=>byte_idx)
      );
    end loop;

    for byte_idx in 0 to length(end_array) - 1 loop
      set(
        arr=>result,
        idx=>length(base_array) + byte_idx,
        value=>get(arr=>end_array, idx=>byte_idx)
      );
    end loop;

    return result;
  end function;

end package body;
