-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the tsfpga project.
-- https://tsfpga.com
-- https://gitlab.com/tsfpga/tsfpga
-- -------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
context vunit_lib.vunit_context;

library common;
use common.addr_pkg.all;

use work.reg_file_pkg.all;


entity tb_reg_file_pkg is
  generic (
    runner_cfg : string
  );
end entity;

architecture tb of tb_reg_file_pkg is
begin

  main : process
    constant regs_3 : reg_definition_vec_t(0 to 3 - 1) := (
      (idx => 0, reg_type => r_w),
      (idx => 1, reg_type => r_w),
      (idx => 2, reg_type => r_w)
    );
    constant regs_4 : reg_definition_vec_t(0 to 4 - 1) := (
      (idx => 0, reg_type => r_w),
      (idx => 1, reg_type => r_w),
      (idx => 2, reg_type => r_w),
      (idx => 3, reg_type => r_w)
    );
    constant regs_5 : reg_definition_vec_t(0 to 5 - 1) := (
      (idx => 0, reg_type => r_w),
      (idx => 1, reg_type => r_w),
      (idx => 2, reg_type => r_w),
      (idx => 3, reg_type => r_w),
      (idx => 4, reg_type => r_w)
    );
    variable expected : addr_t;
  begin
    test_runner_setup(runner, runner_cfg);

    if run("get_addr_mask") then
      expected := b"0000_0000_0000_0000_0000_0000_0000_1100";
      check_equal(get_addr_mask(regs_3), expected);
      check_equal(get_addr_mask(regs_4), expected);

      expected := b"0000_0000_0000_0000_0000_0000_0001_1100";
      check_equal(get_addr_mask(regs_5), expected);
    end if;

    test_runner_cleanup(runner);
  end process;

end architecture;
