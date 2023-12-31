-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the hdl-modules project, a collection of reusable, high-quality,
-- peer-reviewed VHDL building blocks.
-- https://hdl-modules.com
-- https://github.com/hdl-modules/hdl-modules
-- -------------------------------------------------------------------------------------------------
-- Toggle the 'ready' signal based on probabilities set via generics.
-- This realizes a handshake slave with jitter that is compliant with the AXI-Stream standard.
-- According to the standard, 'ready' can be lowered at any time, not just after a transaction.
--
-- This BFM can be more convenient to use than the VUnit 'axi_stream_slave' BFM in some cases.
-- Specifically
--
-- 1. When the data is not an SLV, but instead a record. When using VUnit BFMs we would need to
--    have conversion functions to and from SLV. When using this BFM instead for the handshaking,
--    the data can be handled as records in the testbench with no conversion necessary.
-- 2. When full throughput in the slave is desirable. When using the VUnit BFM the pops must be
--    queued up and "pop references" must be queued up in a separate queue before data is read.
--    This is a lot of boilerplate code that is hard to read.
--
-- Using this simple BFM is also significantly faster.
-- A drawback of this BFM is that the testbench code becomes more "RTL"-like compared to the VUnit
-- BFM, which results in more "high level" code.
-- See the testbench 'tb_handshake_bfm' for example usage.
--
-- This entity can also optionally perform protocol checking on the handshaking data interface.
-- This will verify that the AXI-Stream standard is followed.
-- Assign the ``valid``/``last``/``data``/``strobe`` ports and set the correct ``data_width``
-- generic in order to use this.
-- -------------------------------------------------------------------------------------------------

library ieee;
context ieee.ieee_std_context;

library osvvm;
use osvvm.RandomPkg.RandomPType;

library vunit_lib;
context vunit_lib.vc_context;

library common;

use work.bfm_pkg.all;


entity handshake_slave is
  generic (
    stall_config : stall_config_t;
    -- Random seed for handshaking stall/jitter.
    -- Set to something unique in order to vary the random sequence.
    seed : natural := 0;
    -- Suffix for the VUnit logger name. Can be used to differentiate between multiple instances.
    logger_name_suffix : string := "";
    -- Assign a non-zero value in order to use the 'id' port for protocol checking.
    id_width : natural := 0;
    -- Assign a non-zero value in order to use the 'data'/'strobe' ports for protocol checking.
    data_width : natural := 0;
    -- If true: Once asserted, 'ready' will not fall until valid has been asserted (i.e. a
    -- handshake has happened). Note that according to the AXI-Stream standard 'ready' may fall
    -- at any time (regardless of 'valid'). However, many modules are developed with this
    -- well-behavedness as a way of saving resources.
    well_behaved_stall : boolean := false;
    -- This can be used to essentially disable the
    --   "rule 4: Check failed for performance - tready active N clock cycles after tvalid."
    -- warning by setting a very high value for the limit.
    -- This warning is considered noise in most testbenches that exercise backpressure.
    -- Set to a lower value in order the enable the warning.
    rule_4_performance_check_max_waits : natural := natural'high
  );
  port (
    clk : in std_ulogic;
    --# {{}}
    -- Can be set to '0' by testbench when it is not yet ready to receive data
    data_is_ready : in std_ulogic := '1';
    --# {{}}
    ready : out std_ulogic := '0';
    -- Must be connected if 'well_behaved_stall' is true. Otherwise it is optional and
    -- only for protocol checking.
    valid : in std_ulogic := '0';
    --# {{}}
    -- The signals below are optional to connect. Only used for protocol checking.
    last : in std_ulogic := '1';
    -- Must set 'id_width' generic in order to use this.
    id : in u_unsigned(id_width - 1 downto 0) := (others => '0');
    -- Must set 'data_width' generic in order to use these.
    data : in std_ulogic_vector(data_width - 1 downto 0) := (others => '0');
    strobe : in std_ulogic_vector(data_width / 8 - 1 downto 0) := (others => '1')
  );
end entity;

architecture a of handshake_slave is

  signal stall_data : std_ulogic := '1';

begin

  ready <= data_is_ready and not stall_data;


  ------------------------------------------------------------------------------
  toggle_stall : process
    variable rnd : RandomPType;
  begin
    rnd.InitSeed(rnd'instance_name & "_" & to_string(seed) & logger_name_suffix);

    loop
      stall_data <= '1';
      random_stall(stall_config, rnd, clk);
      stall_data <= '0';

      wait until (valid = '1' or not well_behaved_stall) and rising_edge(clk);
    end loop;
  end process;


  ------------------------------------------------------------------------------
  axi_stream_protocol_checker_inst : entity common.axi_stream_protocol_checker
    generic map (
      data_width => data'length,
      id_width => id'length,
      logger_name_suffix => "_handshake_slave" & logger_name_suffix,
      rule_4_performance_check_max_waits => rule_4_performance_check_max_waits
    )
    port map (
      clk => clk,
      --
      ready => ready,
      valid => valid,
      last => last,
      id => std_logic_vector(id),
      data => data,
      strobe => strobe
    );

end architecture;
