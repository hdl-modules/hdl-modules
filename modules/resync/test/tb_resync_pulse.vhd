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


entity tb_resync_pulse is
  generic (
    output_clock_is_faster : boolean := false;
    output_clock_is_slower : boolean := false;
    input_pulse_overload : boolean := false;
    runner_cfg : string
  );
end entity;

architecture tb of tb_resync_pulse is
  constant clock_period_fast : time := 2 ns;
  constant clock_period_medium : time := 5 ns;
  constant clock_period_slow : time := 10 ns;

  constant sleep_between_pulses : time := 10 * clock_period_slow;

  signal clk_in, clk_out : std_logic := '0';
  signal pulse_in, pulse_out : std_logic;

  signal num_pulses_out : integer := 0;
begin

  test_runner_watchdog(runner, 10 ms);
  clk_in <= not clk_in after clock_period_medium / 2;

  clock_out_gen : if output_clock_is_faster generate
    clk_out <= not clk_out after clock_period_fast / 2;
  elsif output_clock_is_slower generate
    clk_out <= not clk_out after clock_period_slow / 2;
  else generate
    clk_out <= transport clk_in after clock_period_medium / 5;
  end generate;


  ------------------------------------------------------------------------------
  main : process
    procedure test_pulse(expected_num_pulses : integer) is
    begin
      wait until rising_edge(clk_in);
      pulse_in <= '1';

      wait until rising_edge(clk_in);
      pulse_in <= '0';

      if input_pulse_overload then
        -- Send another pulse
        wait until rising_edge(clk_in);
        pulse_in <= '1';

        wait until rising_edge(clk_in);
        pulse_in <= '0';
      end if;

      wait for sleep_between_pulses;
      check_equal(num_pulses_out, expected_num_pulses);
    end procedure;
  begin
    test_runner_setup(runner, runner_cfg);

    for i in 1 to 100 loop
      -- In the case of input_pulse_overload we will send more than one input pulse per call to test_pulse().
      -- But the input gating will make sure that only one pulse arrives on the output, so expected_num_pulses is still i.
      test_pulse(i);
    end loop;

    test_runner_cleanup(runner);
  end process;


  ------------------------------------------------------------------------------
  output : process
  begin
    wait until pulse_out = '1' and rising_edge(clk_out);
    num_pulses_out <= num_pulses_out + 1;
  end process;


  ------------------------------------------------------------------------------
  dut : entity work.resync_pulse
    generic map (
      assert_false_on_pulse_overload => not input_pulse_overload
    )
    port map (
      clk_in => clk_in,
      pulse_in => pulse_in,

      clk_out => clk_out,
      pulse_out => pulse_out);

end architecture;
