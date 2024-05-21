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


entity resync_slv_handshake_wrapper is
  generic (
    data_width : positive
  );
  port (
    input_clk : in std_ulogic;
    input_data : in std_ulogic_vector(data_width - 1 downto 0);
    --# {{}}
    result_clk : in std_ulogic;
    result_data : out std_ulogic_vector(data_width - 1 downto 0) := (others => '0')
  );
end entity;

architecture a of resync_slv_handshake_wrapper is

begin

  ------------------------------------------------------------------------------
  dut : entity work.resync_slv_handshake
    generic map (
      data_width => data_width
    )
    port map (
      input_clk => input_clk,
      input_ready => open,
      input_valid => '1',
      input_data => input_data,
      --
      result_clk => result_clk,
      result_ready => '1',
      result_valid => open,
      result_data => result_data
    );

end architecture;
