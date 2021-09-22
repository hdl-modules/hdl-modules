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
use vunit_lib.random_pkg.all;
context vunit_lib.vunit_context;
context vunit_lib.data_types_context;

library osvvm;
use osvvm.RandomPkg.all;


entity tb_unsigned_divider is
  generic (
    dividend_width : integer;
    divisor_width : integer;
    runner_cfg : string
  );
end entity;

architecture tb of tb_unsigned_divider is

  signal clk : std_logic := '0';

  signal input_ready : std_logic := '0';
  signal input_valid : std_logic := '0';
  signal dividend : unsigned(dividend_width - 1 downto 0);
  signal divisor : unsigned(divisor_width - 1 downto 0);

  signal result_ready : std_logic := '0';
  signal result_valid : std_logic := '0';
  signal quotient : unsigned(dividend'range);
  signal remainder : unsigned(minimum(divisor_width, dividend_width) - 1 downto 0);

begin

  test_runner_watchdog(runner, 20 ms);
  clk <= not clk after 2 ns;


  ------------------------------------------------------------------------------
  main : process

    procedure run_test(dividend_tb, divisor_tb : integer) is
    begin
      dividend <= to_unsigned(dividend_tb, dividend'length);
      divisor <= to_unsigned(divisor_tb, divisor'length);
      input_valid <= '1';
      wait until (input_ready and input_valid) = '1' and rising_edge(clk);
      input_valid <= '0';

      result_ready <= '1';
      wait until (result_ready and result_valid) = '1' and rising_edge(clk);
      result_ready <= '0';
    end procedure;

  begin
    test_runner_setup(runner, runner_cfg);

    if run("division") then
      for dividend_tb in 0 to 2**dividend_width - 1 loop
        for divisor_tb in 1 to 2**divisor_width - 1 loop
          run_test(dividend_tb, divisor_tb);
          check_equal(quotient, dividend_tb / divisor_tb, to_string(dividend_tb) & "/" & to_string(divisor_tb));
          check_equal(remainder, dividend_tb rem divisor_tb, to_string(dividend_tb) & "/" & to_string(divisor_tb));
        end loop;
      end loop;

    elsif run("divide_by_zero") then
      for dividend_tb in 0 to 2**dividend_width - 1 loop
        run_test(dividend_tb, 0);
        check_equal(quotient, 2 ** quotient'length - 1, to_string(dividend_tb) & "/0"); -- Max value (all 1's)
        -- Remainder is undefined
      end loop;
    end if;

    test_runner_cleanup(runner);
  end process;


  ------------------------------------------------------------------------------
  dut : entity work.unsigned_divider
    generic map (
      dividend_width => dividend_width,
      divisor_width => divisor_width
    )
    port map (
      clk => clk,

      input_ready => input_ready,
      input_valid => input_valid,
      dividend => dividend,
      divisor => divisor,

      result_ready => result_ready,
      result_valid => result_valid,
      quotient => quotient,
      remainder => remainder
    );

end architecture;
