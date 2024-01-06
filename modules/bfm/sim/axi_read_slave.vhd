-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the hdl-modules project, a collection of reusable, high-quality,
-- peer-reviewed VHDL building blocks.
-- https://hdl-modules.com
-- https://github.com/hdl-modules/hdl-modules
-- -------------------------------------------------------------------------------------------------
-- Wrapper around VUnit BFM that uses convenient record types for the AXI signals.
--
-- Instantiates the VUnit ``axi_read_slave`` verification component, which acts as an AXI slave
-- and reads data from the :ref:`VUnit memory model <vunit:memory_model>`.
-- -------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
context vunit_lib.vc_context;

library axi;
use axi.axi_pkg.all;


entity axi_read_slave is
  generic (
    axi_slave : axi_slave_t;
    data_width : positive;
    -- Note that the VUnit BFM creates and integer_vector_ptr of length 2**id_width, so a large
    -- value for id_width might crash your simulator.
    id_width : natural range 0 to axi_id_sz;
    -- Optionally limit the address width.
    -- Is required if unused parts of the address field contains e.g. '-', since the VUnit BFM
    -- converts the field to an integer.
    address_width : positive range 1 to axi_a_addr_sz := axi_a_addr_sz
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

end architecture;
