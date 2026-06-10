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

use work.register_file_pkg.all;


entity tb_register_file_pkg is
  generic (
    runner_cfg : string
  );
end entity;

architecture tb of tb_register_file_pkg is

begin


  ------------------------------------------------------------------------------
  main : process
  begin
    test_runner_setup(runner, runner_cfg);

    if run("test_masked_mask_index") then
      check_equal(masked_mask_index(payload_index=>0), 16);
      check_equal(masked_mask_index(payload_index=>1), 17);
      check_equal(masked_mask_index(payload_index=>15), 31);

    end if;

    test_runner_cleanup(runner);
  end process;

end architecture;
