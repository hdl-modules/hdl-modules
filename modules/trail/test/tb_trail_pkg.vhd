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

library osvvm;
use osvvm.RandomPkg.RandomPType;

library vunit_lib;
use vunit_lib.check_pkg.all;
use vunit_lib.run_pkg.all;

use work.trail_pkg.all;


entity tb_trail_pkg is
  generic (
    address_width : trail_address_width_t := 16;
    data_width : trail_data_width_t := 16;
    runner_cfg : string
  );
end entity;

architecture tb of tb_trail_pkg is

begin

  ------------------------------------------------------------------------------
  main : process
    variable rnd : RandomPType;

    procedure test_slv_conversion is
      constant enable : std_ulogic := rnd.RandSl;

      variable operation : trail_operation_t := trail_operation_init;
      variable operation_slv, operation_converted : std_ulogic_vector(
        trail_operation_width(address_width=>address_width, data_width=>data_width) - 1 downto 0
      ) := (others => '0');

      variable response : trail_response_t := trail_response_init;
      variable response_converted, response_slv : std_ulogic_vector(
        trail_response_width(data_width=>data_width) - 1 downto 0
      ) := (others => '0');
    begin
      operation_slv := rnd.RandSLV(operation_slv'length);
      operation := to_trail_operation(
        data=>operation_slv, address_width=>address_width, data_width=>data_width, enable=>enable
      );

      check_equal(operation.enable, enable);

      operation_converted := to_slv(
        data=>operation, address_width=>address_width, data_width=>data_width
      );
      check_equal(operation_converted, operation_slv);

      response_slv := rnd.RandSLV(response_slv'length);
      response := to_trail_response(
        data=>response_slv, data_width=>data_width, enable=>enable
      );

      check_equal(response.enable, enable);

      response_converted := to_slv(data=>response, data_width=>data_width);
      check_equal(response_converted, response_slv);
    end procedure;

  begin
    test_runner_setup(runner, runner_cfg);
    rnd.InitSeed(get_string_seed(runner_cfg));

    if run("test_num_unaligned_address_bits") then
      check_equal(trail_num_unaligned_address_bits(data_width=>8), 0);
      check_equal(trail_num_unaligned_address_bits(data_width=>16), 1);
      check_equal(trail_num_unaligned_address_bits(data_width=>32), 2);
      check_equal(trail_num_unaligned_address_bits(data_width=>64), 3);

    elsif run("test_check_trail_data_width") then
      assert not sanity_check_trail_data_width(data_width=>-8);
      assert not sanity_check_trail_data_width(data_width=>0);
      assert not sanity_check_trail_data_width(data_width=>4);

      assert not sanity_check_trail_data_width(data_width=>7);
      assert sanity_check_trail_data_width(data_width=>8);
      assert not sanity_check_trail_data_width(data_width=>9);

      assert not sanity_check_trail_data_width(data_width=>24);

      assert not sanity_check_trail_data_width(data_width=>31);
      assert sanity_check_trail_data_width(data_width=>32);
      assert not sanity_check_trail_data_width(data_width=>33);

      assert not sanity_check_trail_data_width(data_width=>256);

    elsif run("test_check_trail_address_width") then
      assert sanity_check_trail_address_width(address_width=>8);
      assert not sanity_check_trail_address_width(address_width=>0);
      assert not sanity_check_trail_address_width(address_width=>-8);
      assert not sanity_check_trail_address_width(address_width=>800);

    elsif run("test_check_trail_widths") then
      assert sanity_check_trail_widths(address_width=>8, data_width=>16);
      assert not sanity_check_trail_widths(address_width=>2, data_width=>64);

    elsif run("test_slv_conversion") then
      for i in 0 to 100 loop
        test_slv_conversion;
      end loop;

    end if;

    test_runner_cleanup(runner);
  end process;

end architecture;
