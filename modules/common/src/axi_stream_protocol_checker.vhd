-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the hdl-modules project, a collection of reusable, high-quality,
-- peer-reviewed VHDL building blocks.
-- https://hdl-modules.com
-- https://github.com/hdl-modules/hdl-modules
-- -------------------------------------------------------------------------------------------------
-- Check that an AXI-Stream-like handshaking bus is compliant with the AXI-Stream standard.
-- Will perform the following checks at each rising clock edge:
--
-- 1. The handshake signals ``ready`` and ``valid`` must be well-defined
--    (not ``'X'``, ``'-'``, etc).
-- 2. ``valid`` must not fall without a transaction (``ready and valid``).
-- 3. No payload on the bus may change while ``valid`` is asserted, unless there is a transaction.
-- 4. ``strobe`` must be well-defined when ``valid`` is asserted.
--
-- If any rule violation is detected, an assertion will be triggered.
-- Use the ``logger_name_suffix`` generic to customize the error message.
--
-- .. note::
--
--   This entity can be instantiated in simulation code as well as in synthesis code.
--   The code is simple and will be stripped by synthesis.
--   Can be useful to check the behavior of a stream that is deep in a hierarchy.
--
--
-- Comparison to VUnit checker
-- ___________________________
--
-- This entity was created as a lightweight and synthesizable alternative to the VUnit AXI-Stream
-- protocol checker (``axi_stream_protocol_checker.vhd``).
-- The VUnit checker is clearly more powerful and has more features, but it also consumes a lot more
-- CPU cycles when simulating.
-- One testbench in this project that uses five protocol checkers decreased its execution time by
-- 45% when switching to this protocol checker instead.
--
-- Compared to the VUnit checker, this entity is missing these features:
--
-- 1. Reset support.
-- 2. Checking for undefined bits in payload fields.
-- 3. Checking that all started packets finish with a proper ``last``.
-- 4. Performance checking that ``ready`` is asserted within a certain number of cycles.
-- 5. Logger support. Meaning, it is not possible to mock or disable the checks in this entity.
-- -------------------------------------------------------------------------------------------------

library ieee;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;

use work.types_pkg.is_01;


entity axi_stream_protocol_checker is
  generic (
    -- Assign a non-zero value in order to use the 'data'/'strobe' ports for protocol checking
    data_width : natural := 0;
    -- Assign a non-zero value in order to use the 'id' port for protocol checking
    id_width : natural := 0;
    -- Assign a non-zero value in order to use the 'user' port for protocol checking
    user_width : natural := 0;
    -- Suffix for error log messages. Can be used to differentiate between multiple instances.
    logger_name_suffix : string := ""
  );
  port (
    clk : in std_ulogic;
    --# {{}}
    ready : in std_ulogic := '1';
    valid : in std_ulogic := '0';
    last : in std_ulogic := '0';
    -- Must set a valid 'data_width' generic value in order to use these.
    data : in std_ulogic_vector(data_width - 1 downto 0) := (others => '0');
    strobe : in std_ulogic_vector(data_width / 8 - 1 downto 0) := (others => '1');
    -- Must set a valid 'id_width' generic value in order to use this.
    id : in u_unsigned(id_width - 1 downto 0) := (others => '0');
    -- Must set a valid 'user_width' generic value in order to use this.
    user : in std_ulogic_vector(user_width - 1 downto 0) := (others => '0')
  );
end entity;

architecture a of axi_stream_protocol_checker is

  constant base_error_message : string := "axi_stream_protocol_checker" & logger_name_suffix & ": ";

  function get_unstable_error_message(signal_name : string) return string is
  begin
    return (
      base_error_message
      & "'"
      & signal_name
      & "' changed without transaction while bus was 'valid'."
    );
  end function;

  signal bus_must_be_same_as_previous : std_ulogic := '0';

begin

  ------------------------------------------------------------------------------
  ready_well_defined_block : block
    constant error_message : string := base_error_message & "'ready' has undefined value.";
  begin

    ------------------------------------------------------------------------------
    ready_well_defined_check : process
    begin
      wait until rising_edge(clk);

      assert is_01(ready) report error_message;
    end process;

  end block;


  ------------------------------------------------------------------------------
  valid_well_defined_block : block
    constant error_message : string := base_error_message & "'valid' has undefined value.";
  begin

    ------------------------------------------------------------------------------
    valid_well_defined_check : process
    begin
      wait until rising_edge(clk);

      assert is_01(valid) report error_message;
    end process;

  end block;


  ------------------------------------------------------------------------------
  handshaking_block : block
    signal ready_p1, valid_p1 : std_ulogic := '0';
  begin

    ------------------------------------------------------------------------------
    handshaking_check : process
      constant error_message : string := base_error_message & "'valid' fell without transaction.";
    begin
      wait until rising_edge(clk);

      if valid = '0' and valid_p1 = '1' then
        assert ready_p1 report error_message;
      end if;

      ready_p1 <= ready;
      valid_p1 <= valid;
    end process;

    -- Nothing on the bus may change while 'valid' is asserted, unless there is a transaction
    -- (i.e. 'ready and valid' is true at a rising edge).
    bus_must_be_same_as_previous <= valid and valid_p1 and not ready_p1;

  end block;


  ------------------------------------------------------------------------------
  last_block : block
    constant error_message : string := get_unstable_error_message("last");
    signal last_p1 : std_ulogic := '0';
  begin

    ------------------------------------------------------------------------------
    last_check : process
    begin
      wait until rising_edge(clk);

      if bus_must_be_same_as_previous then
        assert last = last_p1 report error_message;
      end if;

      last_p1 <= last;
    end process;

  end block;


  ------------------------------------------------------------------------------
  data_gen : if data'length > 0 generate
    constant error_message : string := get_unstable_error_message("data");
    signal data_p1 : std_ulogic_vector(data'range) := (others => '0');
  begin

    ------------------------------------------------------------------------------
    data_check : process
    begin
      wait until rising_edge(clk);

      if bus_must_be_same_as_previous then
        assert data = data_p1 report error_message;
      end if;

      data_p1 <= data;
    end process;

  end generate;


  ------------------------------------------------------------------------------
  strobe_gen : if strobe'length > 0 generate
    constant unstable_error_message : string := get_unstable_error_message("strobe");
    constant undefined_error_message : string := (
      base_error_message & "'strobe' has undefined value while bus is 'valid'."
    );

    signal strobe_p1 : std_ulogic_vector(strobe'range) := (others => '0');
  begin

    ------------------------------------------------------------------------------
    strobe_check : process
    begin
      wait until rising_edge(clk);

      if bus_must_be_same_as_previous then
        assert strobe = strobe_p1 report unstable_error_message;
      end if;

      if ready and valid then
        assert is_01(strobe) report undefined_error_message;
      end if;

      strobe_p1 <= strobe;
    end process;

  end generate;


  ------------------------------------------------------------------------------
  id_gen : if id'length > 0 generate
    constant error_message : string := get_unstable_error_message("id");
    signal id_p1 : u_unsigned(id'range) := (others => '0');
  begin

    ------------------------------------------------------------------------------
    id_check : process
    begin
      wait until rising_edge(clk);

      if bus_must_be_same_as_previous then
        assert id = id_p1 report error_message;
      end if;

      id_p1 <= id;
    end process;

  end generate;


  ------------------------------------------------------------------------------
  user_gen : if user'length > 0 generate
    constant error_message : string := get_unstable_error_message("user");
    signal user_p1 : std_ulogic_vector(user'range) := (others => '0');
  begin

    ------------------------------------------------------------------------------
    user_check : process
    begin
      wait until rising_edge(clk);

      if bus_must_be_same_as_previous then
        assert user = user_p1 report error_message;
      end if;

      user_p1 <= user;
    end process;

  end generate;

end architecture;
