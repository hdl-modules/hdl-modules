-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the hdl-modules project, a collection of reusable, high-quality,
-- peer-reviewed VHDL building blocks.
-- https://hdl-modules.com
-- https://github.com/hdl-modules/hdl-modules
-- -------------------------------------------------------------------------------------------------
-- Wrapper with no complex generics, to be used for netlist builds to keep track of
-- synthesized size.
-- -------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

library common;
use common.addr_pkg.all;

use work.axi_lite_pkg.all;


entity axi_lite_mux_netlist_build_wrapper is
  port (
    clk : in std_ulogic;
    --# {{}}
    axi_lite_m2s : in axi_lite_m2s_t;
    axi_lite_s2m : out axi_lite_s2m_t := axi_lite_s2m_init;
    --# {{}}
    axi_lite_m2s_vec : out axi_lite_m2s_vec_t(0 to 18) := (others => axi_lite_m2s_init);
    axi_lite_s2m_vec : in axi_lite_s2m_vec_t(0 to 18)
  );
end entity;

architecture a of axi_lite_mux_netlist_build_wrapper is

  constant base_addresses : addr_vec_t(axi_lite_m2s_vec'range) := (
    x"0000_0000",
    x"0000_1000",
    x"0000_2000",
    x"0000_3000",
    x"0000_4000",
    x"0000_5000",
    x"0000_6000",
    x"0000_7000",
    x"0000_8000",
    x"0000_9000",
    x"0000_A000",
    x"0000_B000",
    x"0000_C000",
    x"0000_D000",
    x"0000_E000",
    x"0000_F000",
    x"0001_0000",
    x"0002_0000",
    x"0002_0100"
  );

begin

  ------------------------------------------------------------------------------
  axi_lite_mux_inst : entity work.axi_lite_mux
    generic map (
      base_addresses => base_addresses
    )
    port map (
      clk => clk,
      --
      axi_lite_m2s => axi_lite_m2s,
      axi_lite_s2m => axi_lite_s2m,
      --
      axi_lite_m2s_vec => axi_lite_m2s_vec,
      axi_lite_s2m_vec => axi_lite_s2m_vec
    );

end architecture;
