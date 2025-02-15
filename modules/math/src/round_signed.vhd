-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the hdl-modules project, a collection of reusable, high-quality,
-- peer-reviewed VHDL building blocks.
-- https://hdl-modules.com
-- https://github.com/hdl-modules/hdl-modules
-- -------------------------------------------------------------------------------------------------
-- TODO
-- -------------------------------------------------------------------------------------------------

library ieee;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;

library common;
use common.types_pkg.all;

use work.math_pkg.all;


entity round_signed is
  generic (
    input_width : positive;
    result_width : positive;
    enable_output_register : boolean := false
  );
  port(
    clk : in std_ulogic;
    --# {{}}
    input_value : in u_signed(input_width - 1 downto 0);
    --# {{}}
    result_value : out u_signed(result_width - 1 downto 0) := (others => '0');
    result_is_saturated : out std_ulogic := '0'
  );
end entity;

architecture a of round_signed is

  -- signal result : u_signed(result_value'range) := (others => '0');
  -- signal is_saturated : std_ulogic := '0';

begin

  assert result_width <= input_width
    report "We can not make the number wider"
    severity failure;


  ------------------------------------------------------------------------------
  passthrough_or_not_gen : if input_width = result_width generate

    -- result <= input_value;


  ------------------------------------------------------------------------------
  else generate
    -- constant max_result : signed(result_width - 1 downto 0) := get_max_signed(
    --   num_bits=>result_width
    -- );

    constant num_lsb_to_remove : positive := input_width - result_width;
    constant point_five_index : natural := num_lsb_to_remove - 1;

    signal input_value_truncated : signed(result_width - 1 downto 0) := (others => '0');
    signal input_value_extended, result_extended : signed(
      input_value_truncated'length downto 0
    ) := (others => '0');

    signal point_five : natural range 0 to 1 := 0;
  begin

    input_value_truncated <= input_value(input_value'high downto num_lsb_to_remove);
    point_five <= to_int(input_value(point_five_index));

    input_value_extended <= resize(input_value_truncated, result_value'length + 1);
    result_extended <= input_value_extended + point_five;


    ------------------------------------------------------------------------------
    saturate_signed_inst : entity work.saturate_signed
      generic map(
        input_width => result_extended'length,
        result_width => result_value'length,
        enable_output_register => enable_output_register
      )
      port map(
        clk => clk,
        --
        input_value => result_extended,
        --
        result_value => result_value,
        result_is_saturated => result_is_saturated
      );

  end generate;


end architecture;
