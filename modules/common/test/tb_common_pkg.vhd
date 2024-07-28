-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the hdl-modules project, a collection of reusable, high-quality,
-- peer-reviewed VHDL building blocks.
-- https://hdl-modules.com
-- https://github.com/hdl-modules/hdl-modules
-- -------------------------------------------------------------------------------------------------

library vunit_lib;
use vunit_lib.check_pkg.all;
use vunit_lib.run_pkg.all;

use work.common_pkg.all;


entity tb_common_pkg is
  generic (
    runner_cfg : string
  );
end entity;

architecture tb of tb_common_pkg is
begin

  ------------------------------------------------------------------------------
  main : process
  begin
    test_runner_setup(runner, runner_cfg);

    if run("test_if_then_else_string") then
      check_equal(if_then_else(true, "a", "b"), "a");
      check_equal(if_then_else(false, "a", "b"), "b");

    end if;

    test_runner_cleanup(runner);
  end process;

end architecture;
