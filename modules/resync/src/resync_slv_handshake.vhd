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
    data_width : positive
  );
  port (
    input_clk : in std_ulogic;
    input_ready : out std_ulogic := '0';
    input_valid : in std_ulogic;
    input_data : in std_ulogic_vector(data_width - 1 downto 0);
    --# {{}}
    result_clk : in std_ulogic;
    result_ready : in std_ulogic;
    result_valid : out std_ulogic := '0';
    result_data : out std_ulogic_vector(data_width - 1 downto 0) := (others => '0')
  );
end entity;

architecture a of resync_slv_handshake is

  signal input_data_sampled, result_data_int : std_ulogic_vector(input_data'range) := (
    others => '0'
  );

  -- We apply constraints to these two signals, and they are crucial for the function of the CDC.
  -- Do not allow the tool to optimize these or move any logic.
  attribute dont_touch of input_data_sampled : signal is "true";
  attribute dont_touch of result_data_int : signal is "true";

  signal input_level, input_level_resync, input_level_resync_p1 : std_ulogic := '0';
  signal result_level, result_level_resync : std_ulogic := '0';
  -- Different value than the others, to trigger the first 'input_ready' event.
  signal result_level_resync_p1 : std_ulogic := '1';

begin

  ------------------------------------------------------------------------------
  resync_input_level_inst : entity work.resync_level
    generic map (
      -- Value is driven by a FF so this is not needed
      enable_input_register => false
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
      enable_input_register => false
    )
    port map (
      clk_in => result_clk,
      data_in => input_level_resync_p1,
      --
      clk_out => input_clk,
      data_out => result_level_resync
    );


  ------------------------------------------------------------------------------
  handle_input : process
  begin
    wait until rising_edge(input_clk);

    if input_ready then
      input_data_sampled <= input_data;
    end if;

    if input_valid then
      -- If we have 'input_ready', this assignment will lower it.
      -- If we do not, this assignment does nothing.
      result_level_resync_p1 <= result_level_resync;

      if input_ready then
        -- Let through the toggled level to indicate that we have a new sample of data.
        input_level <= result_level_resync_p1; -- not result_level_resync;
      end if;
    end if;
  end process;

  input_ready <= result_level_resync xor result_level_resync_p1;


  ------------------------------------------------------------------------------
  handle_result : process
  begin
    wait until rising_edge(result_clk);

    if input_level_resync xor input_level_resync_p1 then -- and not result_valid then
      result_valid <= '1';
      result_data_int <= input_data_sampled;
    end if;

    if result_ready and result_valid then
      input_level_resync_p1 <= input_level_resync;
      result_valid <= '0';
    end if;
  end process;

  result_data <= result_data_int;

end architecture;
