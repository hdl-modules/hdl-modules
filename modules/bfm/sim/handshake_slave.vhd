-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the tsfpga project.
-- https://tsfpga.com
-- https://gitlab.com/tsfpga/tsfpga
-- -------------------------------------------------------------------------------------------------
-- Toggle the 'ready' signal based on probabilities set via generics.
-- This realizes a handshake slave with jitter that is compliant with the AXI-Stream standard.
-- According to the standard, 'ready' can be lowered at any time, not just after a transaction.
--
-- This BFM can be more convenient to use than the VUnit 'axi_stream_slave' BFM in some cases.
-- Specifically
--   1. When the data is not an SLV, but instead a record. When using VUnit BFMs we would need to
--      have conversion functions to and from SLV. When using this BFM instead for the handshaking,
--      the data can be handled as records in the testbench with no conversion necessary.
--   2. When full throughput in the slave is desirable. When using the VUnit BFM the pops must be
--      queued up and "pop references" must be queued up in a separate queue before data is read.
--      This is a lot of boilerplate code that is hard to read.
-- Using this simple BFM is also significantly faster.
-- A drawback of this BFM is that the tesbench code becomes more "RTL"-like compared to the VUnit
-- BFM, which results in more "high level" code.
-- See the testbench 'tb_handshake_bfm' for example usage.
--
-- This entity can also optionally perform protocol checking on the handshaking data interface.
-- This will verify that the AXI-Stream standard is followed.
-- Assign the valid/last/data/strobe ports and set the correct 'data_width' generic in order to
-- use this.
-- -------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

library osvvm;
use osvvm.RandomPkg.RandomPType;

library vunit_lib;
context vunit_lib.vc_context;
context vunit_lib.vunit_context;

use work.bfm_pkg.all;


entity handshake_slave is
  generic (
    stall_config : in stall_config_t;
    -- Is also used for the random seed
    -- Set to something unique in order to vary the random sequence.
    logger_name_suffix : string := "";
    -- Assign a non-zero value in order to use the 'data' port for protocol checking
    data_width : natural := 0;
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
    -- Can be set to '0' by testbench when it is not yet ready to receive data
    data_is_ready : in std_logic := '1';
    --
    ready : out std_logic := '0';
    -- Only for protocol checking
    valid : in std_logic := '0';
    last : in std_logic := '1';
    -- Must set 'data_width' generic in order to use these ports for protocol checking
    data : in std_logic_vector(data_width - 1 downto 0) := (others => '0');
    strobe : in std_logic_vector(data_width / 8 - 1 downto 0) := (others => '1')
  );
end entity;

architecture a of handshake_slave is

  signal stall_data : std_logic := '1';

begin

  ready <= data_is_ready and not stall_data;


  ------------------------------------------------------------------------------
  toggle_stall : process
    variable rnd : RandomPType;
  begin
    rnd.InitSeed(rnd'instance_name & logger_name_suffix);

    loop
      stall_data <= '1';
      random_stall(stall_config, rnd, clk);
      stall_data <= '0';

      wait until rising_edge(clk);
    end loop;
  end process;


  ------------------------------------------------------------------------------
  axi_stream_protocol_checker_inst : entity vunit_lib.axi_stream_protocol_checker
    generic map (
      protocol_checker => new_axi_stream_protocol_checker(
        logger => get_logger("handshake_slave" & logger_name_suffix),
        data_length => data'length,
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
      tkeep => strobe
    );

end architecture;
