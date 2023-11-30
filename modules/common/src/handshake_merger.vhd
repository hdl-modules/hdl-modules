-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the hdl-modules project, a collection of reusable, high-quality,
-- peer-reviewed VHDL building blocks.
-- https://hdl-modules.com
-- https://github.com/hdl-modules/hdl-modules
-- -------------------------------------------------------------------------------------------------
-- Combinatorially merge multiple AXI-Stream-like handshake interfaces into one.
--
-- The handling of data and other auxiliary signals must be performed outside of this entity.
-- This entity guarantees that when ``result_valid`` is asserted, the data associated with
-- all inputs is valid and can be used combinatorially on the result side.
--
-- If no interface is stalling, then full throughput is sustained through this entity.
-- -------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;


entity handshake_merger is
  generic (
    num_interfaces : positive;
    assert_false_on_last_mismatch : boolean := true
  );
  port (
    clk : in std_ulogic;
    --# {{}}
    input_ready : out std_ulogic_vector(0 to num_interfaces - 1) := (others => '0');
    input_valid : in std_ulogic_vector(0 to num_interfaces - 1);
    input_last : in std_ulogic_vector(0 to num_interfaces - 1);
    --# {{}}
    result_ready : in std_ulogic;
    result_valid : out std_ulogic := '0';
    result_last : out std_ulogic := '0'
  );
end entity;

architecture a of handshake_merger is

begin

  input_ready <= (others => result_ready and result_valid);

  result_valid <= and input_valid;

  result_last <= or input_last;


  ------------------------------------------------------------------------------
  assertions : process
  begin
    wait until assert_false_on_last_mismatch and rising_edge(clk);

    if result_valid then
      assert not (xor input_last) report "Input packet lengths are different";
    end if;
  end process;

end architecture;
