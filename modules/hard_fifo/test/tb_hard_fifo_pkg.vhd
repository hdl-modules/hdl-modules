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

use work.hard_fifo_pkg.all;


entity tb_hard_fifo_pkg is
  generic (
    runner_cfg : string
  );
end entity;

architecture tb of tb_hard_fifo_pkg is


begin

  ------------------------------------------------------------------------------
  main : process
  begin
    test_runner_setup(runner, runner_cfg);

    if run("test_get_fifo_depth") then
      -- width 3->4, depth 1024*36/4.5
      check_equal(get_fifo_depth(3), 8192);
      check_equal(get_fifo_depth(4), 8192);

      check_equal(get_fifo_depth(8), 4096);
      check_equal(get_fifo_depth(9), 4096);

      check_equal(get_fifo_depth(10), 2048);
      check_equal(get_fifo_depth(18), 2048);

    end if;

    test_runner_cleanup(runner);
  end process;

end architecture;
