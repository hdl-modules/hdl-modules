-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the hdl-modules project, a collection of reusable, high-quality,
-- peer-reviewed VHDL building blocks.
-- https://hdl-modules.com
-- https://github.com/hdl-modules/hdl-modules
-- -------------------------------------------------------------------------------------------------
-- Wrapper around VUnit ``axi_read_slave`` verification component.
-- Uses convenient record types for the AXI-Lite signals.
-- Performs protocol checking to verify that the upstream AXI-Lite master is performing
-- everything correctly.
--
-- The instantiated verification component will process the incoming AXI-Lite operations and
-- apply them to the :ref:`VUnit memory model <vunit:memory_model>`.
-- -------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

library axi;
use axi.axi_pkg.all;

library axi_lite;
use axi_lite.axi_lite_pkg.all;

library common;

library vunit_lib;
use vunit_lib.axi_slave_pkg.all;


entity axi_lite_read_slave is
  generic (
    axi_slave : axi_slave_t;
    data_width : positive range 1 to axi_lite_data_sz;
    -- Suffix for error log messages. Can be used to differentiate between multiple instances.
    logger_name_suffix : string := ""
  );
  port (
    clk : in std_ulogic;
    --# {{}}
    axi_lite_read_m2s : in axi_lite_read_m2s_t := axi_lite_read_m2s_init;
    axi_lite_read_s2m : out axi_lite_read_s2m_t := axi_lite_read_s2m_init
  );
end entity;

architecture a of axi_lite_read_slave is

  constant len : axi_a_len_t := to_len(1);
  constant size : axi_a_size_t := to_size(data_width);

  -- Using "open" not ok in GHDL: unconstrained port "rid" must be connected
  signal rid, arid : std_ulogic_vector(8 - 1 downto 0) := (others => '0');

  signal araddr : std_ulogic_vector(axi_lite_read_m2s.ar.addr'range) := (others => '0');

begin

  ------------------------------------------------------------------------------
  assert sanity_check_axi_lite_data_width(data_width)
    report "Invalid AXI-Lite data width, see printout above"
    severity failure;


  ------------------------------------------------------------------------------
  axi_read_slave_inst : entity vunit_lib.axi_read_slave
    generic map (
      axi_slave => axi_slave
    )
    port map (
      aclk => clk,
      --
      arvalid => axi_lite_read_m2s.ar.valid,
      arready => axi_lite_read_s2m.ar.ready,
      arid => arid,
      araddr => araddr,
      arlen => std_ulogic_vector(len),
      arsize => std_ulogic_vector(size),
      arburst => axi_a_burst_fixed,
      --
      rvalid => axi_lite_read_s2m.r.valid,
      rready => axi_lite_read_m2s.r.ready,
      rid => rid,
      rdata => axi_lite_read_s2m.r.data(data_width - 1 downto 0),
      rresp => axi_lite_read_s2m.r.resp,
      rlast => open
    );

  araddr <= std_logic_vector(axi_lite_read_m2s.ar.addr);


  ------------------------------------------------------------------------------
  ar_protocol_checker_inst : entity common.axi_stream_protocol_checker
    generic map (
      data_width => araddr'length,
      logger_name_suffix => " - axi_lite_read_slave - AR" & logger_name_suffix
    )
    port map (
      clk => clk,
      --
      ready => axi_lite_read_s2m.ar.ready,
      valid => axi_lite_read_m2s.ar.valid,
      data => araddr
    );


  ------------------------------------------------------------------------------
  r_protocol_checker_inst : entity common.axi_stream_protocol_checker
    generic map (
      logger_name_suffix => " - axi_lite_read_slave - R" & logger_name_suffix
    )
    port map (
      clk => clk,
      --
      ready => axi_lite_read_m2s.r.ready
    );

end architecture;
