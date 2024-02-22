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
use ieee.numeric_std.all;

library vunit_lib;
use vunit_lib.check_pkg.all;
use vunit_lib.run_pkg.all;

use work.width_conversion_pkg.all;


entity tb_width_conversion_pkg is
  generic (
    runner_cfg : string
  );
end entity;

architecture tb of tb_width_conversion_pkg is
begin

  ------------------------------------------------------------------------------
  main : process
  begin
    test_runner_setup(runner, runner_cfg);

    if run("test_width_conversion_output_user_width") then
      check_equal(
        width_conversion_output_user_width(
          input_user_width=>8, input_data_width=>32, output_data_width=>16
        ),
        8
      );
      check_equal(
        width_conversion_output_user_width(
          input_user_width=>13, input_data_width=>22, output_data_width=>11
        ),
        13
      );

      check_equal(
        width_conversion_output_user_width(
          input_user_width=>13, input_data_width=>11, output_data_width=>44
        ),
        4 * 13
      );

    end if;

    test_runner_cleanup(runner);
  end process;

end architecture;
