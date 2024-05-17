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
use ieee.std_logic_1164.all;

library common;
use common.attribute_pkg.dont_touch;


entity resync_slv_handshake is
  generic (
    data_width : positive;
    -- Initial value for the result data that will be set for a few cycles before the first input
    -- value has propagated.
    default_value : std_ulogic_vector(data_width - 1 downto 0) := (others => '0')
  );
  port (
    input_clk : in std_ulogic;
    input_ready : out std_ulogic := '0';
    input_valid : in std_ulogic;
    input_data : in std_ulogic_vector(default_value'range);
    --# {{}}
    result_clk : in std_ulogic;
    result_ready : in std_ulogic;
    result_valid : out std_ulogic := '0';
    result_data : out std_ulogic_vector(default_value'range) := default_value
  );
end entity;

architecture a of resync_slv_handshake is

  signal input_data_sampled, result_data_int : std_ulogic_vector(input_data'range) := default_value;

  -- We apply constraints to these two signals, and they are crucial for the function of the CDC.
  -- Do not allow the tool to optimize these or move any logic.
  attribute dont_touch of input_data_sampled : signal is "true";
  attribute dont_touch of result_data_int : signal is "true";

  constant level_default_value : std_ulogic := '0';

  signal input_level, result_level : std_ulogic := level_default_value;
  signal input_level_resync, input_level_resync_p1 : std_ulogic := level_default_value;
  signal result_level_resync, result_level_resync_p1 : std_ulogic := level_default_value;

begin

  ------------------------------------------------------------------------------
  resync_input_level_inst : entity work.resync_level
    generic map (
      -- Value is driven by a FF so this is not needed
      enable_input_register => false,
      default_value => level_default_value
    )
    port map (
      clk_in => input_clk,
      data_in => input_level,
      --
      clk_out => result_clk,
      data_out => input_level_resync
    );


  ------------------------------------------------------------------------------
  resync_result_level_input_inst : entity work.resync_level
    generic map (
      -- Value is driven by a FF so this is not needed
      enable_input_register => false,
      default_value => level_default_value
    )
    port map (
      clk_in => result_clk,
      data_in => result_level,
      --
      clk_out => input_clk,
      data_out => result_level_resync
    );


  ------------------------------------------------------------------------------
  input_block : block
    signal may_sample_input, may_sample_input_sticky : std_ulogic := '1';
  begin

    -- Asserted for one clock cycle when the resynced result level toggles.
    may_sample_input <= result_level_resync xor result_level_resync_p1;

    -- Set combinatorially to minimize stall in the upstream handshake master.
    input_ready <= may_sample_input or may_sample_input_sticky;


    ------------------------------------------------------------------------------
    handle_input : process
    begin
      wait until rising_edge(input_clk);

      assert not (may_sample_input and may_sample_input_sticky) report "Control flow error";
      may_sample_input_sticky <= may_sample_input or may_sample_input_sticky;

      if input_ready and input_valid then
        input_data_sampled <= input_data;
        may_sample_input_sticky <= '0';

        input_level <= result_level_resync;
      end if;

      result_level_resync_p1 <= result_level_resync;
    end process;

  end block;


  ------------------------------------------------------------------------------
  result_block : block
    signal new_data : std_ulogic := '0';
  begin

    -- Asserted for one clock cycle when the resynced input level toggles.
    new_data <= input_level_resync xor input_level_resync_p1;

    ------------------------------------------------------------------------------
    handle_result : process
    begin
      wait until rising_edge(result_clk);

      if result_ready and result_valid then
        result_valid <= '0';

        -- Toggle the feedback level only when we are done with the data.
        result_level <= input_level_resync_p1;
      end if;

      if new_data then
        result_valid <= '1';
        assert not result_valid report "Control flow error";

        result_data_int <= input_data_sampled;
      end if;

      input_level_resync_p1 <= input_level_resync;
    end process;

    result_data <= result_data_int;

  end block;

end architecture;
