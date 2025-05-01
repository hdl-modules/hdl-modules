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
--
--
-- Randomization
-- _____________
--
-- This BFM will inject random handshake stall/jitter, for good verification coverage.
-- Modify the ``stall_config`` generic to get your desired behavior.
-- The random seed is provided by a VUnit mechanism
-- (see the "seed" portion of `this document <https://vunit.github.io/run/user_guide.html>`__).
-- Use the ``--seed`` command line argument if you need to set a static seed.
-- -------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

library vunit_lib;
use vunit_lib.run_pkg.all;
use vunit_lib.run_types_pkg.all;

library osvvm;
use osvvm.RandomPkg.RandomPType;

use work.stall_bfm_pkg.all;


entity handshake_master is
  generic (
    stall_config : stall_configuration_t
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
      variable seed : string_seed_t;
      variable rnd : RandomPType;
    begin
      -- Use salt so that parallel instances of this entity get unique random sequences.
      get_seed(seed, salt=>handshake_master'path_name);
      rnd.InitSeed(seed);

      loop
        let_data_through <= '0';
        random_stall(stall_config=>stall_config, rnd=>rnd, clk=>clk);
        let_data_through <= '1';

        wait until (ready and valid) = '1' and rising_edge(clk);
      end loop;
    end process;

  end generate;

end architecture;
