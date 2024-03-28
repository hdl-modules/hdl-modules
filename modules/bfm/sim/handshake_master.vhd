-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the hdl-modules project, a collection of reusable, high-quality,
-- peer-reviewed VHDL building blocks.
-- https://hdl-modules.com
-- https://github.com/hdl-modules/hdl-modules
-- -------------------------------------------------------------------------------------------------
-- Toggle the ``valid`` signal based on probabilities set via generics.
-- This realizes a handshake master with jitter that is compliant with the AXI-Stream standard.
-- According to the standard, ``valid`` may be lowered only after a transaction.
--
-- This BFM can be more convenient to use than the :ref:`bfm.axi_stream_master` BFM in
-- some cases.
-- Specifically when the data is not an SLV, but instead a record.
-- When using AXI-Stream BFMs we would need to have conversion functions to and from SLV.
-- When using this BFM instead for the handshaking,
-- the data can be handled as records in the testbench with no conversion necessary.
--
-- See the testbench ``tb_handshake_bfm`` for example usage.
-- -------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

library osvvm;
use osvvm.RandomPkg.RandomPType;

use work.stall_bfm_pkg.all;


entity handshake_master is
  generic (
    stall_config : stall_configuration_t;
    -- Random seed for handshaking stall/jitter.
    -- Set to something unique in order to vary the random sequence.
    seed : natural := 0;
    -- Suffix for error log messages. Can be used to differentiate between multiple instances.
    logger_name_suffix : string := ""
  );
  port (
    clk : in std_ulogic;
    --# {{}}
    -- Set by testbench when there is data available.
    data_is_valid : in std_ulogic := '1';
    --# {{}}
    ready : in std_ulogic := '1';
    valid : out std_ulogic := '0'
  );
end entity;

architecture a of handshake_master is

  signal let_data_through : std_ulogic := '1';

begin

  valid <= data_is_valid and let_data_through;


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

        wait until (ready and valid) = '1' and rising_edge(clk);
      end loop;
    end process;

  end generate;

end architecture;
