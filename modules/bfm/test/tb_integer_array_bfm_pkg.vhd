-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the hdl-modules project, a collection of reusable, high-quality,
-- peer-reviewed VHDL building blocks.
-- https://hdl-modules.com
-- https://github.com/hdl-modules/hdl-modules
-- -------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

library osvvm;
use osvvm.RandomPkg.RandomPType;

library vunit_lib;
use vunit_lib.check_pkg.all;
use vunit_lib.integer_array_pkg.all;
use vunit_lib.random_pkg.all;
use vunit_lib.run_pkg.all;

use work.integer_array_bfm_pkg.concatenate_integer_arrays;


entity tb_integer_array_bfm_pkg is
  generic (
    seed : natural;
    runner_cfg : string
  );
end entity;

architecture tb of tb_integer_array_bfm_pkg is

begin

  ------------------------------------------------------------------------------
  main : process
    variable rnd : RandomPType;

    variable base_array, base_array_copy, end_array, end_array_copy, result : integer_array_t :=
      null_integer_array;
  begin
    test_runner_setup(runner, runner_cfg);
    rnd.InitSeed(seed);

    if run("test_concatenate_integer_array") then
      random_integer_array(
        rnd=>rnd,
        integer_array=>base_array,
        width=>rnd.Uniform(0, 5),
        bits_per_word=>8,
        is_signed=>False
      );
      base_array_copy := copy(base_array);

      random_integer_array(
        rnd=>rnd,
        integer_array=>end_array,
        width=>rnd.Uniform(0, 5),
        bits_per_word=>8,
        is_signed=>False
      );
      end_array_copy := copy(end_array);

      result := concatenate_integer_arrays(base_array, end_array);

      -- Show that the result array does not depend on memory from the inputs.
      -- Everything should be correct even after we deallocate the original data.
      deallocate(base_array);
      deallocate(end_array);

      check_equal(length(result), length(base_array_copy) + length(end_array_copy));

      for base_index in 0 to length(base_array_copy) - 1 loop
        check_equal(get(result, base_index), get(base_array_copy, base_index));
      end loop;

      for end_index in 0 to length(end_array_copy) - 1 loop
        check_equal(
          get(result, end_index + length(base_array_copy)), get(end_array_copy, end_index)
        );
      end loop;

    end if;

    test_runner_cleanup(runner);
  end process;

end architecture;
