-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the hdl-modules project, a collection of reusable, high-quality,
-- peer-reviewed VHDL building blocks.
-- https://hdl-modules.com
-- https://github.com/hdl-modules/hdl-modules
-- -------------------------------------------------------------------------------------------------
-- Calculates
--
--   dividend / divisor = quotient + remainder / divisor
--
-- This is a bit serial divider.
-- Algorithm is the same as long division from elementary school, but with number base two.
-- Latency scales linearly with ``dividend_width``.
-- -------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library common;
use common.types_pkg.all;

use work.math_pkg.all;


entity unsigned_divider is
  generic (
    dividend_width : positive;
    divisor_width : positive
  );
  port (
    clk : in std_ulogic;
    --# {{}}
    input_ready : out std_ulogic := '1';
    input_valid : in std_ulogic;
    dividend : in u_unsigned(dividend_width - 1 downto 0);
    divisor : in u_unsigned(divisor_width - 1 downto 0);
    --# {{}}
    result_ready : in std_ulogic;
    result_valid : out std_ulogic := '0';
    quotient : out u_unsigned(dividend_width - 1 downto 0);
    remainder : out u_unsigned(minimum(divisor_width, dividend_width) - 1 downto 0)
  );
end entity;

architecture a of unsigned_divider is

  type state_t is (ready, busy, done);
  signal state : state_t := ready;

  signal current_bit : natural range 0 to dividend_width - 1;
  signal remainder_int : u_unsigned(dividend'range);
  signal divisor_int : u_unsigned((dividend_width - 1) + divisor_width - 1 downto 0);

  function shift_down(bit : std_ulogic; vector : u_unsigned) return u_unsigned is
  begin
    return bit & vector(vector'high downto vector'low + 1);
  end function;

  function shift_down(vector : u_unsigned) return u_unsigned is
  begin
    return shift_down('0', vector);
  end function;

  function shift_up(bit : std_ulogic; vector : u_unsigned) return u_unsigned is
  begin
    return vector(vector'high - 1 downto vector'low) & bit;
  end function;

begin

  remainder <= resize(remainder_int, remainder'length);

  main : process
    constant sub_result_width : positive := maximum(remainder_int'length, divisor_int'length) + 1;
    variable sub_result : u_signed(sub_result_width - 1 downto 0) := (others => '0');
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
