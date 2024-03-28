-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the hdl-modules project, a collection of reusable, high-quality,
-- peer-reviewed VHDL building blocks.
-- https://hdl-modules.com
-- https://github.com/hdl-modules/hdl-modules
-- -------------------------------------------------------------------------------------------------
-- Wrapper around VUnit ``axi_read_slave`` verification component.
-- Uses convenient record types for the AXI signals.
-- This BFM will also perform protocol to verify that the upstream AXI master is performing
-- everything correctly.
--
-- The instantiated verification component will process the incoming AXI operations and
-- apply them to the :ref:`VUnit memory model <vunit:memory_model>`.
-- -------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
use vunit_lib.axi_slave_pkg.all;

library axi;
use axi.axi_pkg.all;

library common;


entity axi_read_slave is
  generic (
    axi_slave : axi_slave_t;
    data_width : positive range 8 to axi_data_sz;
    -- Note that the VUnit BFM creates and integer_vector_ptr of length 2**id_width, so a large
    -- value for id_width might crash your simulator.
    id_width : natural range 0 to axi_id_sz;
    -- Optionally limit the address width.
    -- Is required if unused parts of the address field contains e.g. '-', since the VUnit BFM
    -- converts the field to an integer.
    address_width : positive range 1 to axi_a_addr_sz := axi_a_addr_sz;
    -- Suffix for error log messages. Can be used to differentiate between multiple instances.
    logger_name_suffix : string := ""
  );
  port (
    clk : in std_ulogic;
    --# {{}}
    axi_read_m2s : in axi_read_m2s_t;
    axi_read_s2m : out axi_read_s2m_t := axi_read_s2m_init
  );
end entity;

architecture a of axi_read_slave is

  signal arid, rid : std_ulogic_vector(id_width - 1 downto 0) := (others => '0');
  signal araddr : std_ulogic_vector(address_width - 1 downto 0) := (others => '0');
  signal arlen : std_ulogic_vector(axi_read_m2s.ar.len'range) := (others => '0');
  signal arsize : std_ulogic_vector(axi_read_m2s.ar.size'range) := (others => '0');

begin

  ------------------------------------------------------------------------------
  assert sanity_check_axi_data_width(data_width)
    report "Invalid AXI data width, see printout above"
    severity failure;


  ------------------------------------------------------------------------------
  axi_read_slave_inst : entity vunit_lib.axi_read_slave
    generic map (
      axi_slave => axi_slave
    )
    port map (
      aclk => clk,
      --
      arvalid => axi_read_m2s.ar.valid,
      arready => axi_read_s2m.ar.ready,
      arid => arid,
      araddr => araddr,
      arlen => arlen,
      arsize => arsize,
      arburst => axi_read_m2s.ar.burst,
      --
      rvalid => axi_read_s2m.r.valid,
      rready => axi_read_m2s.r.ready,
      rid => rid,
      rdata => axi_read_s2m.r.data(data_width - 1 downto 0),
      rresp => axi_read_s2m.r.resp,
      rlast => axi_read_s2m.r.last
    );

  arid <= std_logic_vector(axi_read_m2s.ar.id(arid'range));
  araddr <= std_logic_vector(axi_read_m2s.ar.addr(araddr'range));
  arlen <= std_logic_vector(axi_read_m2s.ar.len);
  arsize <= std_logic_vector(axi_read_m2s.ar.size);

  axi_read_s2m.r.id(rid'range) <= unsigned(rid);


  ------------------------------------------------------------------------------
  -- Use AXI stream protocol checkers to ensure that ready/valid behave as they should,
  -- and that none of the fields change value unless a transaction has occurred.
  ar_axi_stream_protocol_checker_block : block
    constant packed_width : positive := axi_m2s_a_sz(id_width=>id_width, addr_width=>address_width);
    signal packed : std_ulogic_vector(packed_width - 1 downto 0) := (others => '0');
  begin

    ------------------------------------------------------------------------------
    ar_axi_stream_protocol_checker_inst : entity common.axi_stream_protocol_checker
      generic map (
        data_width => packed'length,
        logger_name_suffix => " - axi_read_slave - AR" & logger_name_suffix
      )
      port map (
        clk => clk,
        --
        ready => axi_read_s2m.ar.ready,
        valid => axi_read_m2s.ar.valid,
        data => packed
      );

    packed <= to_slv(data=>axi_read_m2s.ar, id_width=>id_width, addr_width=>address_width);

  end block;


  ------------------------------------------------------------------------------
  r_axi_stream_protocol_checker_inst : entity common.axi_stream_protocol_checker
    generic map (
      logger_name_suffix => " - axi_read_slave - R" & logger_name_suffix
    )
    port map (
      clk => clk,
      --
      ready => axi_read_m2s.r.ready
    );

end architecture;
