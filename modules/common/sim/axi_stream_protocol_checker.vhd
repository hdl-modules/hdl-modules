-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the tsfpga project.
-- https://tsfpga.com
-- https://gitlab.com/tsfpga/tsfpga
-- -------------------------------------------------------------------------------------------------
-- A wrapper around the VUnit AXI-Stream protocol checker. Has simpler interface, and can hence
-- be included in synthesizable code with a generate guard:
--
--    if in_simulation generate
--
--      axi_stream_protocol_checker_inst : comon.axi_stream_protocol_checker
--        generic map (
--          ...
--
--    end generate;
--
-- Without the generate guard, synthesis will fail. The file is placed in the "sim" folder,
-- so it will not be included in synthesis or formal projects.
-- -------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

library vunit_lib;
context vunit_lib.vc_context;
context vunit_lib.vunit_context;


entity axi_stream_protocol_checker is
  generic (
    -- Assign a non-zero value in order to use the 'data'/'strobe' ports for protocol checking
    data_width : natural := 0;
    -- Assign a non-zero value in order to use the 'id' port for protocol checking
    id_width : natural := 0;
    logger_name_suffix : string := "";
    -- This can be used to essentially disable the
    --   "rule 4: Check failed for performance - tready active N clock cycles after tvalid."
    -- warning by setting a very high value for the limit.
    -- This warning is considered noise in most testbenches that exercise backpressure.
    -- Set to a lower value in order the enable the warning.
    rule_4_performance_check_max_waits : natural := natural'high
  );
  port (
    clk : in std_logic;
    --
    ready : in std_logic;
    valid : in std_logic;
    -- Optional to connect.
    last : in std_logic := '1';
    -- Optional to connect.
    -- Must set a valid 'id_width' generic value in order to use these.
    id : in std_logic_vector(id_width - 1 downto 0) := (others => '0');
    -- Optional to connect.
    -- Must set a valid 'data_width' generic value in order to use these.
    data : in std_logic_vector(data_width - 1 downto 0) := (others => '0');
    strobe : in std_logic_vector(data_width / 8 - 1 downto 0) := (others => '1')
  );
end entity;

architecture a of axi_stream_protocol_checker is

begin

  ------------------------------------------------------------------------------
  axi_stream_protocol_checker_inst : entity vunit_lib.axi_stream_protocol_checker
    generic map (
      protocol_checker => new_axi_stream_protocol_checker(
        data_length => data'length,
        id_length => id'length,
        logger => get_logger("axi_stream_protocol_checker" & logger_name_suffix),
        max_waits => rule_4_performance_check_max_waits
      )
    )
    port map (
      aclk => clk,
      tvalid => valid,
      tready => ready,
      tdata => data,
      tlast => last,
      tstrb => strobe,
      tkeep => strobe,
      tid => id
    );

end architecture;
