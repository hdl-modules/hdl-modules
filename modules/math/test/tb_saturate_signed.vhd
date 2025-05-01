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
use vunit_lib.queue_pkg.all;
use vunit_lib.run_pkg.all;

library osvvm;
use osvvm.RandomPkg.RandomPType;

library common;
use common.types_pkg.all;

use work.math_pkg.all;


entity tb_saturate_signed is
  generic (
    runner_cfg : string
  );
end entity;

architecture tb of tb_saturate_signed is

  -- ---------------------------------------------------------------------------
  -- Generic constants
  shared variable rnd : RandomPType;

  impure function initialize_and_get_input_width return positive is
  begin
    -- This is the first function that is called, so we initialize the random number generator here.
    rnd.InitSeed(get_string_seed(runner_cfg));

    return rnd.Uniform(2, 24);
  end function;
  constant input_width : positive := initialize_and_get_input_width;

  constant result_width : positive := maximum(1, rnd.Uniform(input_width - 4, input_width));
  constant enable_output_register : boolean := rnd.RandBool;

  -- ---------------------------------------------------------------------------
  -- DUT connections
  signal clk : std_ulogic := '0';

  signal input_valid : std_ulogic := '0';
  signal input_value : u_signed(input_width - 1 downto 0) := (others => '0');

  signal result_valid, result_is_saturated : std_ulogic := '0';
  signal result_value : u_signed(result_width - 1 downto 0) := (others => '0');

  -- ---------------------------------------------------------------------------
  -- Testbench stuff
  constant data_queue : queue_t := new_queue;

  signal num_result_checked : natural := 0;

begin

  test_runner_watchdog(runner, 1 ms);
  clk <= not clk after 2 ns;


  ------------------------------------------------------------------------------
  main : process

    variable num_result_expected : natural := 0;

    procedure run_test is
      variable value : u_signed(input_width - 1 downto 0) := (others => '0');
    begin
      for test_idx in 0 to 200 loop
        value := rnd.RandSigned(input_width);
        push(data_queue, value);

        input_valid <= '1';
        input_value <= value;

        num_result_expected := num_result_expected + 1;

        wait until rising_edge(clk);
        input_valid <= '0';
        input_value <= (others => '0');

        for wait_cycle in 1 to rnd.FavorSmall(0, 2) loop
          wait until rising_edge(clk);
        end loop;
      end loop;
    end procedure;

  begin
    test_runner_setup(runner, runner_cfg);

    report "input_width = " & to_string(input_width);
    report "result_width = " & to_string(result_width);
    report "enable_output_register = " & to_string(enable_output_register);

    if run("test_random_data") then
      run_test;
    end if;

    wait until num_result_checked = num_result_expected and rising_edge(clk);

    test_runner_cleanup(runner);
  end process;


  ------------------------------------------------------------------------------
  check_data : process
    constant min_result_value : u_signed(result_value'range) := get_min_signed(result_value'length);
    constant max_result_value : u_signed(result_value'range) := get_max_signed(result_value'length);

    variable value_in : u_signed(input_width - 1 downto 0) := (others => '0');
  begin
    wait until result_valid and rising_edge(clk);

    value_in := pop(data_queue);

    check_equal(result_value, clamp(value_in, min_result_value, max_result_value));
    check_equal(result_is_saturated, value_in < min_result_value or value_in > max_result_value);

    num_result_checked <= num_result_checked + 1;
  end process;


  ------------------------------------------------------------------------------
  dut : entity work.saturate_signed
    generic map (
      input_width => input_width,
      result_width => result_width,
      enable_output_register => enable_output_register
    )
    port map (
      clk => clk,
      --
      input_valid => input_valid,
      input_value => input_value,
      --
      result_valid => result_valid,
      result_value => result_value,
      result_is_saturated => result_is_saturated
    );

end architecture;
