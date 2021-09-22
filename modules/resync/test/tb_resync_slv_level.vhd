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


entity tb_resync_slv_level is
  generic (
    test_coherent : boolean;
    output_clock_is_faster : boolean;
    enable_input_register : boolean;
    runner_cfg : string
  );
end entity;

architecture tb of tb_resync_slv_level is

  constant clock_period_fast : time := 2 ns;
  constant clock_period_medium : time := 10 ns;
  constant clock_period_slow : time := 10 ns;

  function clk_out_period return time is
  begin
    if output_clock_is_faster then
      return clock_period_fast;
    else
      return clock_period_slow;
    end if;
  end function;

  constant one : std_logic_vector(16 - 1 downto 0) := x"1111";
  constant two : std_logic_vector(one'range) := x"2222";

  signal clk_in, clk_out : std_logic := '0';
  signal data_in, data_out : std_logic_vector(one'range) := one;

begin

  test_runner_watchdog(runner, 10 ms);
  clk_out <= not clk_out after clk_out_period / 2;
  clk_in <= not clk_in after clock_period_medium / 2;


  ------------------------------------------------------------------------------
  main : process

    procedure wait_cycles(signal clk : std_logic; num_cycles : in integer) is
    begin
      for i in 0 to num_cycles-1 loop
        wait until rising_edge(clk);
      end loop;
    end procedure;

    procedure wait_for_input_value_to_propagate is
      variable clk_in_wait_count, clk_out_wait_count : natural := 0;
    begin
      -- Wait to assign input value in tb
      clk_in_wait_count := 1;
      -- Two registers
      clk_out_wait_count := 2;

      if test_coherent then
        clk_in_wait_count := clk_in_wait_count + 3;
      end if;

      if enable_input_register then
        clk_in_wait_count := clk_in_wait_count + 1;
      end if;

      wait_cycles(clk_in, clk_in_wait_count);
      wait_cycles(clk_out, clk_out_wait_count);
    end procedure;

  begin
    test_runner_setup(runner, runner_cfg);

    -- Default value
    check_equal(data_out, one);

    wait until rising_edge(clk_out);
    check_equal(data_out, one);

    wait_cycles(clk_out, 40);
    check_equal(data_out, one);
    data_in <= two;

    wait_for_input_value_to_propagate;
    check_equal(data_out, two);

    wait_cycles(clk_out, 40);
    check_equal(data_out, two);

    test_runner_cleanup(runner);
  end process;


  ------------------------------------------------------------------------------
  assert_output_always_valid_value : process
  begin
    wait until rising_edge(clk_out);
    assert data_out = one or data_out = two;
  end process;


  ------------------------------------------------------------------------------
  choose_dut : if test_coherent generate

    dut : entity work.resync_slv_level_coherent
      generic map (
        width => data_in'length,
        default_value => one
      )
      port map (
        clk_in => clk_in,
        data_in => data_in,

        clk_out => clk_out,
        data_out => data_out
      );

  else generate

    dut : entity work.resync_slv_level
      generic map (
        width => data_in'length,
        enable_input_register => enable_input_register,
        default_value => one
      )
      port map (
        clk_in => clk_in,
        data_in => data_in,

        clk_out => clk_out,
        data_out => data_out
      );

  end generate;


end architecture;
