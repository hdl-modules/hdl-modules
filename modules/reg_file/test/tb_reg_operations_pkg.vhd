-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the tsfpga project.
-- https://tsfpga.com
-- https://gitlab.com/tsfpga/tsfpga
-- -------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

library vunit_lib;
context vunit_lib.vunit_context;

library common;
use common.types_pkg.all;

use work.reg_operations_pkg.all;
use work.reg_file_pkg.all;


entity tb_reg_operations_pkg is
  generic (
    runner_cfg : string
  );
end entity;

architecture tb of tb_reg_operations_pkg is
begin

  main : process
    variable bit_indexes_1 : natural_vec_t(0 to 2) := (others => 0);
    variable values_1 : std_logic_vector(0 to 2) := (others => '0');

    variable bit_indexes_2 : natural_vec_t(-2147483648 to -2147483647) := (others => 0);
    variable values_2 : std_logic_vector(0 to 1) := (others => '0');

    variable reg_value, reg_value_2 : reg_t := (others => '0');
  begin
    test_runner_setup(runner, runner_cfg);

    if run("test_to_reg_value") then
      reg_value := x"80_00_00_01";

      bit_indexes_1 := (0, 8, 31);
      values_1 := ('1', '0', '1');
      check_equal(to_reg_value(bit_indexes_1, values_1), reg_value);

      bit_indexes_2 := (0, 31);
      values_2 := ('1', '1');
      check_equal(to_reg_value(bit_indexes_2, values_2), reg_value);

      bit_indexes_2 := (1, 30);
      values_2 := ('1', '1');
      reg_value_2 := x"c0_00_00_03";
      check_equal(to_reg_value(bit_indexes_2, values_2, previous_value=>reg_value), reg_value_2);

      bit_indexes_2 := (1, 30);
      values_2 := ('1', '1');
      reg_value_2 := "-1----------------------------1-";
      check_equal(
        to_reg_value(bit_indexes_2, values_2, previous_value=>(others => '-')),
        reg_value_2
      );
    end if;

    test_runner_cleanup(runner);
  end process;

end architecture;
