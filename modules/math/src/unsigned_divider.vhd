-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the tsfpga project.
-- https://tsfpga.com
-- https://gitlab.com/tsfpga/tsfpga
-- -------------------------------------------------------------------------------------------------
-- Calculates dividend / divisor = quotient + remainder / divisor
--
-- This is a bit serial divider. Algorithm is the same as long division from elementary
-- school, but with number base 2. Latency scales linearly with dividend_width.
-- -------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library common;
use common.types_pkg.all;

use work.math_pkg.all;


entity unsigned_divider is
  generic (
    dividend_width : integer;
    divisor_width : integer
  );
  port (
    clk : in std_logic;

    input_ready : out std_logic := '1';
    input_valid : in std_logic;
    dividend : in unsigned(dividend_width - 1 downto 0);
    divisor : in unsigned(divisor_width - 1 downto 0);

    result_ready : in std_logic;
    result_valid : out std_logic := '0';
    quotient : out unsigned(dividend_width - 1 downto 0);
    remainder : out unsigned(minimum(divisor_width, dividend_width) - 1 downto 0)
  );
end entity;

architecture a of unsigned_divider is

  type state_t is (ready, busy, done);
  signal state : state_t := ready;

  signal current_bit : integer range 0 to dividend_width - 1;
  signal remainder_int : unsigned(dividend'range);
  signal divisor_int : unsigned((dividend_width - 1) + divisor_width - 1 downto 0);

  function shift_down(bit : std_logic; vector : unsigned) return unsigned is
  begin
    return bit & vector(vector'high downto vector'low + 1);
  end function;

  function shift_down(vector : unsigned) return unsigned is
  begin
    return shift_down('0', vector);
  end function;

  function shift_up(bit : std_logic; vector : unsigned) return unsigned is
  begin
    return vector(vector'high - 1 downto vector'low) & bit;
  end function;

begin

  remainder <= resize(remainder_int, remainder'length);

  main : process
    variable sub_result : signed(maximum(remainder_int'length, divisor_int'length) + 1 - 1 downto 0);
  begin
    wait until rising_edge(clk);

    divisor_int <= shift_down(divisor_int);
    sub_result := signed('0' & remainder_int) - signed('0' & divisor_int);

    case state is
      when ready =>
        if input_ready and input_valid then
          input_ready <= '0';
          remainder_int <= dividend;
          divisor_int <= divisor & to_unsigned(0, dividend_width - 1);
          current_bit <= dividend_width - 1;
          state <= busy;
        end if;

      when busy =>
        if lt_0(sub_result) then
          quotient <= shift_up('0', quotient);
        else
          quotient <= shift_up('1', quotient);
          remainder_int <= remainder_int - divisor_int(remainder_int'range);
        end if;

        if current_bit = 0 then
          state <= done;
          result_valid <= '1';
        else
          current_bit <= current_bit - 1;
        end if;

      when done =>
        if result_ready and result_valid then
          result_valid <= '0';
          input_ready <= '1';
          state <= ready;
        end if;
    end case;
  end process;

end architecture;
