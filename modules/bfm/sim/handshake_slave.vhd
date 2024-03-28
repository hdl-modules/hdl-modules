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
-- This BFM can be more convenient to use than the :ref:`bfm.axi_stream_slave` BFM in some cases.
-- Specifically when the data is not an SLV, but instead a record.
-- When using AXI-Stream BFMs we would need to have conversion functions to and from SLV.
-- When using this BFM instead for the handshaking,
-- the data can be handled as records in the testbench with no conversion necessary.
--
-- See the testbench 'tb_handshake_bfm' for example usage.
-- -------------------------------------------------------------------------------------------------

library ieee;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;

library osvvm;
use osvvm.RandomPkg.RandomPType;

use work.stall_bfm_pkg.all;


entity handshake_slave is
  generic (
    stall_config : stall_configuration_t;
    -- Random seed for handshaking stall/jitter.
    -- Set to something unique in order to vary the random sequence.
    seed : natural := 0;
    -- If true: Once asserted, 'ready' will not fall until valid has been asserted (i.e. a
    -- handshake has happened). Note that according to the AXI-Stream standard 'ready' may fall
    -- at any time (regardless of 'valid'). However, many modules are developed with this
    -- well-behavedness as a way of saving resources.
    well_behaved_stall : boolean := false;
    -- Suffix for error log messages. Can be used to differentiate between multiple instances.
    logger_name_suffix : string := ""
  );
  port (
    clk : in std_ulogic;
    --# {{}}
    -- Can be set to '0' by testbench when it is not yet ready to receive data.
    data_is_ready : in std_ulogic := '1';
    --# {{}}
    ready : out std_ulogic := '0';
    -- Must be connected if 'well_behaved_stall' is true. Otherwise it has no effect.
    valid : in std_ulogic := '0'
  );
end entity;

architecture a of handshake_slave is

  signal let_data_through : std_ulogic := '1';

begin

  ready <= data_is_ready and let_data_through;


  ------------------------------------------------------------------------------
  toggle_stall_gen : if stall_config.stall_probability > 0.0 generate

    ------------------------------------------------------------------------------
    toggle_stall : process
      variable rnd : RandomPType;
    begin
      rnd.InitSeed(rnd'instance_name & "_" & to_string(seed) & logger_name_suffix);

      loop
        let_data_through <= '0';
        random_stall(stall_config=>stall_config, rnd=>rnd, clk=>clk);
        let_data_through <= '1';

        wait until (valid = '1' or not well_behaved_stall) and rising_edge(clk);
      end loop;
    end process;

  end generate;

end architecture;
