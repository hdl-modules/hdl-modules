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
use common.types_pkg.all;

entity tb_resync_counter is
  generic (
    runner_cfg      : string;
    pipeline_output : boolean
    );
end entity;

architecture tb of tb_resync_counter is
  constant clk_in_period   : time    := 3.3 ns;
  constant clk_out_period  : time    := 4 ns;
  constant max_resync_time : time :=
    clk_in_period +
    2*clk_out_period +
    to_int(pipeline_output) * clk_out_period;

  signal clk_in                  : std_logic                      := '1';
  signal clk_out                 : std_logic                      := '0';
  signal counter_in, counter_out : unsigned(8 - 1 downto 0) := (others => '0');
  constant counter_max : integer := 2 ** counter_in'length - 1;
begin

  test_runner_watchdog(runner, 10 ms);
  clk_in  <= not clk_in  after clk_in_period/2;
  clk_out <= not clk_out after clk_out_period/2;


  ------------------------------------------------------------------------------
  main : process
    procedure apply_and_check(value : integer) is
    begin
      wait until rising_edge(clk_in);
      counter_in <= to_unsigned(value, counter_in'length);
      wait until counter_out'event for max_resync_time;
      wait until rising_edge(clk_out);
      check_equal(counter_out, value);
      wait until counter_out'event for 40*clk_out_period;
      assert not counter_out'event;
    end procedure;

  begin
    test_runner_setup(runner, runner_cfg);

    loop_twice_to_wrap_counter : for i in 1 to 2 loop
      count_up : for value in 0 to counter_max loop
        apply_and_check(value);
      end loop;
    end loop;

    count_down : for value in counter_max downto 0 loop
      apply_and_check(value);
    end loop;

    test_runner_cleanup(runner);
  end process;


  ------------------------------------------------------------------------------
  dut : entity work.resync_counter
    generic map (
      width => counter_in'length,
      pipeline_output => pipeline_output)
    port map (
      clk_in     => clk_in,
      counter_in => counter_in,

      clk_out     => clk_out,
      counter_out => counter_out);

end architecture;
