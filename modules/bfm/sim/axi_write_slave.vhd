-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the hdl_modules project, a collection of reusable, high-quality,
-- peer-reviewed VHDL building blocks.
-- https://hdl-modules.com
-- https://gitlab.com/hdl_modules/hdl_modules
-- -------------------------------------------------------------------------------------------------
-- Wrapper around VUnit BFM that uses convenient record types for the AXI signals.
--
-- Instantiates the VUnit ``axi_read_slave`` verification component, which acts as an AXI slave
-- and writes data to the :ref:`VUnit memory model <vunit:memory_model>`.
-- -------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
context vunit_lib.vc_context;
context vunit_lib.vunit_context;

library axi;
use axi.axi_pkg.all;

library common;
use common.types_pkg.all;


entity axi_write_slave is
  generic (
    axi_slave : axi_slave_t;
    data_width : positive;
    -- Note that the VUnit BFM creates and integer_vector_ptr of length 2**id_width, so a large
    -- value for id_width might crash your simulator.
    id_width : natural range 0 to axi_id_sz;
    -- Optionally add a FIFO to the W channel. Makes it possible to perform W transactions
    -- before AW transactions.
    w_fifo_depth : natural := 0
  );
  port (
    clk : in std_ulogic;
    --# {{}}
    axi_write_m2s : in axi_write_m2s_t;
    axi_write_s2m : out axi_write_s2m_t := axi_write_s2m_init;
    --# {{}}
    -- The number of bursts where data has been written to memory (AW and W done), and the
    -- B transaction has completed.
    num_bursts_done : out natural := 0
  );
end entity;

architecture a of axi_write_slave is

  constant strobe_width : positive := data_width / 8;

  signal w_fifo_m2s : axi_m2s_w_t := axi_m2s_w_init;
  signal w_fifo_s2m : axi_s2m_w_t := axi_s2m_w_init;

  signal awid, bid : std_ulogic_vector(id_width - 1 downto 0) := (others => '0');
  signal awaddr : std_ulogic_vector(axi_write_m2s.aw.addr'range) := (others => '0');
  signal awlen : std_ulogic_vector(axi_write_m2s.aw.len'range) := (others => '0');
  signal awsize : std_ulogic_vector(axi_write_m2s.aw.size'range) := (others => '0');

begin

  ------------------------------------------------------------------------------
  -- Optionally use a FIFO for the data channel. This enables a data flow pattern where
  -- the AXI slave can accept a lot of data (many bursts) before a single address transaction
  -- occurs. This can affect the behavior of your AXI master, and is a case that needs to
  -- be tested sometimes.
  axi_w_fifo_inst : entity axi.axi_w_fifo
    generic map (
      data_width => data_width,
      asynchronous => false,
      depth => w_fifo_depth
    )
    port map (
      clk => clk,
      --
      input_m2s => axi_write_m2s.w,
      input_s2m => axi_write_s2m.w,
      --
      output_m2s => w_fifo_m2s,
      output_s2m => w_fifo_s2m
    );


  ------------------------------------------------------------------------------
  axi_write_slave_inst : entity vunit_lib.axi_write_slave
    generic map (
      axi_slave => axi_slave
    )
    port map (
      aclk => clk,
      --
      awvalid => axi_write_m2s.aw.valid,
      awready => axi_write_s2m.aw.ready,
      awid => awid,
      awaddr => awaddr,
      awlen => awlen,
      awsize => awsize,
      awburst => axi_write_m2s.aw.burst,
      --
      wvalid => w_fifo_m2s.valid,
      wready => w_fifo_s2m.ready,
      wdata => w_fifo_m2s.data(data_width - 1 downto 0),
      wstrb => w_fifo_m2s.strb,
      wlast => w_fifo_m2s.last,
      --
      bvalid => axi_write_s2m.b.valid,
      bready => axi_write_m2s.b.ready,
      bid => bid,
      bresp => axi_write_s2m.b.resp
    );

  awid <= std_logic_vector(axi_write_m2s.aw.id(awid'range));
  awaddr <= std_logic_vector(axi_write_m2s.aw.addr);
  awlen <= std_logic_vector(axi_write_m2s.aw.len);
  awsize <= std_logic_vector(axi_write_m2s.aw.size);

  axi_write_s2m.b.id(bid'range) <= unsigned(bid);


  ------------------------------------------------------------------------------
  count_num_bursts : process
  begin
    wait until rising_edge(clk);

    num_bursts_done <=
      num_bursts_done + to_int(axi_write_m2s.b.ready and axi_write_s2m.b.valid);
  end process;


  ------------------------------------------------------------------------------
  -- Use AXI stream protocol checkers to ensure that ready/valid behave as they should,
  -- and that none of the fields change value unless a transaction has occurred.
  aw_axi_stream_protocol_checker_block : block
    constant packed_width : positive := axi_m2s_a_sz(id_width=>id_width, addr_width=>axi_a_addr_sz);
    signal packed : std_ulogic_vector(packed_width - 1 downto 0) := (others => '0');

    constant logger : logger_t
      := get_logger(get_name(get_logger(axi_slave)) & "_aw_axi_stream_protocol_checker");
    constant protocol_checker : axi_stream_protocol_checker_t := new_axi_stream_protocol_checker(
      data_length => packed_width,
      logger => logger,
      -- Suppress the
      --   "rule 4: Check failed for performance - tready active N clock cycles after tvalid."
      -- warning by setting a very high value for the limit.
      -- This warning is considered noise in most testbenches that exercise backpressure.
      max_waits => natural'high
    );
  begin

    ------------------------------------------------------------------------------
    axi_stream_protocol_checker_inst : entity vunit_lib.axi_stream_protocol_checker
      generic map (
        protocol_checker => protocol_checker
      )
      port map (
        aclk => clk,
        tvalid => axi_write_m2s.aw.valid,
        tready => axi_write_s2m.aw.ready,
        tdata => packed,
        tlast => '1',
        tstrb => (others => '1'),
        tkeep => (others => '1')
      );

    packed <= to_slv(data=>axi_write_m2s.aw, id_width=>id_width, addr_width=>axi_a_addr_sz);

  end block;


  ------------------------------------------------------------------------------
  w_axi_stream_protocol_checker_block : block
    constant packed_width : positive := axi_m2s_w_sz(data_width=>data_width);
    signal packed : std_ulogic_vector(packed_width - 1 downto 0) := (others => '0');

    constant logger : logger_t
      := get_logger(get_name(get_logger(axi_slave)) & "_w_axi_stream_protocol_checker");
    constant protocol_checker : axi_stream_protocol_checker_t := new_axi_stream_protocol_checker(
      data_length => packed_width,
      logger => logger,
      -- Suppress the
      --   "rule 4: Check failed for performance - tready active N clock cycles after tvalid."
      -- warning by setting a very high value for the limit.
      -- This warning is considered noise in most testbenches that exercise backpressure.
      max_waits => natural'high
    );
  begin

    ------------------------------------------------------------------------------
    -- For protocol checking of WDATA.
    -- The VUnit axi_stream_protocol_checker does not allow any bit in tdata to be e.g. '-' or 'X'
    -- when tvalid is asserted. Even when that bit is strobed out by tstrb/tkeep.
    -- This often becomes a problem, since many implementations assign don't care to strobed out
    -- byte lanes as a way of minimizing LUT consumption. Also testbenches that use the AXI-Stream
    -- master will often have 'X' assigned to input bytes that are strobed out, which can propagate
    -- to this checker.
    -- Hence the workaround is to assign '0' to all bits that are in strobed out lanes.
    assign_data_without_invalid : process(all)
      variable axi_m2s_w_strobed : axi_m2s_w_t := axi_m2s_w_init;
    begin
      axi_m2s_w_strobed := axi_write_m2s.w;

      for byte_idx in 0 to strobe_width - 1 loop
        if not axi_write_m2s.w.strb(byte_idx) then
          axi_m2s_w_strobed.data((byte_idx + 1) * 8 - 1 downto byte_idx * 8 ) := (others => '0');
        end if;
      end loop;

      -- TODO does not include WID when in AXI3 mode
      packed <= to_slv(data=>axi_m2s_w_strobed, data_width=>data_width);
    end process;


    ------------------------------------------------------------------------------
    axi_stream_protocol_checker_inst : entity vunit_lib.axi_stream_protocol_checker
      generic map (
        protocol_checker => protocol_checker
      )
      port map (
        aclk => clk,
        tvalid => axi_write_m2s.w.valid,
        tready => axi_write_s2m.w.ready,
        tdata => packed,
        tlast => '1',
        tstrb => (others => '1'),
        tkeep => (others => '1')
      );

  end block;

end architecture;
