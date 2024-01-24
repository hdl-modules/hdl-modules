-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the hdl-modules project, a collection of reusable, high-quality,
-- peer-reviewed VHDL building blocks.
-- https://hdl-modules.com
-- https://github.com/hdl-modules/hdl-modules
-- -------------------------------------------------------------------------------------------------
-- Check that an AXI address channel does not produce transactions that are out of range.
--
-- .. warning::
--
--   This core checker is not suitable for instantiation in your design.
--   Use :ref:`axi.axi_read_range_checker` or :ref:`axi.axi_write_range_checker` instead.
-- -------------------------------------------------------------------------------------------------

library ieee;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;

library axi;
use axi.axi_pkg.all;


entity axi_address_range_checker is
  generic (
    address_width : positive range 1 to axi_a_addr_sz;
    id_width : natural range 0 to axi_id_sz;
    data_width : positive range 8 to axi_data_sz;
    enable_axi3 : boolean;
    supports_narrow_burst : boolean
  );
  port (
    clk : in std_ulogic;
    --# {{}}
    address_m2s : in axi_m2s_a_t;
    address_s2m : in axi_s2m_a_t
  );
end entity;

architecture a of axi_address_range_checker is

begin

  ------------------------------------------------------------------------------
  check_address : process
    constant error_message : string := (
      "Using address bit outside of "
      & integer'image(address_width)
      & "-bit range."
    );
  begin
    wait until (address_s2m.ready and address_m2s.valid) = '1' and rising_edge(clk);

    for bit_idx in address_width to address_m2s.addr'high loop
      assert address_m2s.addr(bit_idx) /= '1' report error_message;
    end loop;
  end process;


  ------------------------------------------------------------------------------
  check_id : process
    constant error_message : string := (
      "Using ID bit outside of "
      & integer'image(id_width)
      & "-bit range."
    );
  begin
    wait until (address_s2m.ready and address_m2s.valid) = '1' and rising_edge(clk);

    for bit_idx in id_width to address_m2s.id'high loop
      assert address_m2s.id(bit_idx) /= '1' report error_message;
    end loop;
  end process;


  ------------------------------------------------------------------------------
  check_size : process
    constant natural_size : axi_a_size_t := to_size(data_width_bits=>data_width);
    constant error_message : string := (
      "Illegal transfer size. Natural size: "
      & integer'image(to_integer(natural_size))
      & "."
    );
  begin
    wait until (address_s2m.ready and address_m2s.valid) = '1' and rising_edge(clk);

    if supports_narrow_burst then
      assert address_m2s.size <= natural_size report error_message;
    else
      assert address_m2s.size = natural_size report error_message;
    end if;
  end process;


  ------------------------------------------------------------------------------
  axi3_gen : if enable_axi3 generate

    ------------------------------------------------------------------------------
    check_len : process
      constant arlen_width : positive := get_a_len_width(
        max_burst_length_beats=>get_max_burst_length_beats(enable_axi3=>enable_axi3)
      );
      constant unused_arlen_zero : unsigned(axi_a_len_sz - 1 downto arlen_width) := (others => '0');
    begin
      wait until (address_s2m.ready and address_m2s.valid) = '1' and rising_edge(clk);

      assert address_m2s.len(unused_arlen_zero'range) = unused_arlen_zero
        report "Unused bits in AxLEN are not zero.";
    end process;

  end generate;

end architecture;
