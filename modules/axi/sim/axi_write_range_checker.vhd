-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the hdl-modules project, a collection of reusable, high-quality,
-- peer-reviewed VHDL building blocks.
-- https://hdl-modules.com
-- https://github.com/hdl-modules/hdl-modules
-- -------------------------------------------------------------------------------------------------
-- Rudimentary simulation runtime checker that an AXI master does not produce transactions
-- that are out of the range of a downstream memory slave.
-- Suitable to instantiate at the end of your AXI chain, right before the AXI memory slave.
--
-- This entity is meant for simulation, but since it contains only quite simple assertions
-- it should be no problem for a synthesis tool to strip it.
-- However, it is probably a good idea to instantiate it within a simulation guard:
--
-- .. code-block:: vhdl
--
--   axi_range_checker_gen : if in_simulation generate
--
--     axi_write_range_checker_inst : entity work.axi_write_range_checker
--       generic map (
--         ...
--       );
--
--   end generate;
-- -------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

library axi;
use axi.axi_pkg.all;


entity axi_write_range_checker is
  generic (
    address_width : positive range 1 to axi_a_addr_sz := axi_a_addr_sz;
    id_width : natural range 0 to axi_id_sz := axi_id_sz;
    data_width : positive range 8 to axi_data_sz := axi_data_sz;
    enable_axi3 : boolean;
    supports_narrow_burst : boolean
  );
  port (
    clk : in std_ulogic;
    --# {{}}
    write_m2s : in axi_write_m2s_t;
    write_s2m : in axi_write_s2m_t
  );
end entity;

architecture a of axi_write_range_checker is

begin

  ------------------------------------------------------------------------------
  axi_address_sanity_checker_inst : entity work.axi_address_range_checker
    generic map (
      address_width => address_width,
      id_width => id_width,
      data_width => data_width,
      enable_axi3 => enable_axi3,
      supports_narrow_burst => supports_narrow_burst
    )
    port map (
      clk => clk,
      --
      address_m2s => write_m2s.aw,
      address_s2m => write_s2m.aw
    );


  ------------------------------------------------------------------------------
  check_strobe : process
    constant strobe_width : positive := data_width / 8;
    constant unused_strobe_zero : std_logic_vector(write_m2s.w.strb'high downto strobe_width) := (
      others => '0'
    );
  begin
    wait until (write_s2m.w.ready and write_m2s.w.valid) = '1' and rising_edge(clk);

    assert write_m2s.w.strb(unused_strobe_zero'range) = unused_strobe_zero
      report "Unused strobe bits must be zero";
  end process;

end architecture;
