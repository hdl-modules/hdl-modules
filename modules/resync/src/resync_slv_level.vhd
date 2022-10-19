-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the hdl_modules project, a collection of reusable, high-quality,
-- peer-reviewed VHDL building blocks.
-- https://hdl-modules.com
-- https://gitlab.com/hdl_modules/hdl_modules
-- -------------------------------------------------------------------------------------------------
-- Resync a vector from one clock domain to another.
--
-- .. note::
--   This entity instantiates :ref:`resync.resync_level` which has a scoped constraint
--   file that must be used.
--
-- This simple vector resync mechanism does not guarantee any coherency between the bits.
-- There might be a large skew between different bits.
-- It does however have meta-stability protection.
-- See :ref:`resync.resync_level` for details about constraining and usage of
-- the ``enable_input_register`` generic.
-- -------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;


entity resync_slv_level is
  generic (
    width : positive;
    -- Enable or disable a register on the input side before the async_reg flip-flip chain.
    -- Must be used if the input can contain glitches. See resync_slv header for more details.
    -- The 'clk_in' port must be assigned if this generic is set to 'true'.
    enable_input_register : boolean;
    -- Initial value for the output that will be set for a few cycles before the first input
    -- value has propagated.
    default_value : std_logic_vector(width - 1 downto 0) := (others => '0')
  );
  port (
    clk_in : in std_logic := '-';
    data_in : in std_logic_vector(default_value'range);
    --# {{}}
    clk_out : in std_logic;
    data_out : out std_logic_vector(default_value'range) := default_value
  );
end entity;

architecture a of resync_slv_level is
begin

  ------------------------------------------------------------------------------
  resync_gen : for i in data_in'range generate
  begin

    ------------------------------------------------------------------------------
    resync_level_inst : entity work.resync_level
      generic map (
        enable_input_register => enable_input_register,
        default_value => default_value(i)
      )
      port map (
        clk_in => clk_in,
        data_in => data_in(i),

        clk_out => clk_out,
        data_out => data_out(i)
      );

  end generate;

end architecture;
