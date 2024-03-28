-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the hdl-modules project, a collection of reusable, high-quality,
-- peer-reviewed VHDL building blocks.
-- https://hdl-modules.com
-- https://github.com/hdl-modules/hdl-modules
-- -------------------------------------------------------------------------------------------------
-- Wrapper around VUnit ``axi_write_slave`` verification component.
-- Uses convenient record types for the AXI signals.
-- This BFM will also perform protocol checking to verify that the upstream AXI master is
-- performing everything correctly.
--
-- The instantiated verification component will process the incoming AXI operations and
-- apply them to the :ref:`VUnit memory model <vunit:memory_model>`.
-- -------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
use vunit_lib.axi_slave_pkg.all;
use vunit_lib.check_pkg.all;
use vunit_lib.queue_pkg.all;

library axi;
use axi.axi_pkg.all;

library common;
use common.types_pkg.all;


entity axi_write_slave is
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
    -- Optionally add a FIFO to the W channel. Makes it possible to perform W transactions
    -- before AW transactions.
    w_fifo_depth : natural := 0;
    -- Optionally check the AXI3 'WID' signal against the previously negotiated 'AWID'.
    -- Does NOT support write interleaving, and will fail if any 'W' transaction happens before
    -- the corresponding 'AW' transaction.
    enable_axi3 : boolean := false;
    -- Suffix for error log messages. Can be used to differentiate between multiple instances.
    logger_name_suffix : string := ""
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

  -- Is present in AXI3 but not AXI4.
  constant wid_width : natural := id_width * to_int(enable_axi3);

  signal w_fifo_m2s : axi_m2s_w_t := axi_m2s_w_init;
  signal w_fifo_s2m : axi_s2m_w_t := axi_s2m_w_init;

  signal awid, bid : std_ulogic_vector(id_width - 1 downto 0) := (others => '0');
  signal awaddr : std_ulogic_vector(address_width - 1 downto 0) := (others => '0');
  signal awlen : std_ulogic_vector(axi_write_m2s.aw.len'range) := (others => '0');
  signal awsize : std_ulogic_vector(axi_write_m2s.aw.size'range) := (others => '0');

begin

  ------------------------------------------------------------------------------
  assert sanity_check_axi_data_width(data_width)
    report "Invalid AXI data width, see printout above"
    severity failure;


  ------------------------------------------------------------------------------
  check_strobe_zero_outside_of_data : process
    constant expected : std_ulogic_vector(axi_write_m2s.w.strb'high downto strobe_width) := (
      others => '0'
    );
    constant error_message : string := (
      " - axi_write_slave - B" & logger_name_suffix & ": WSTRB is non-zero outside of data"
    );
  begin
    wait until axi_write_s2m.w.ready and axi_write_m2s.w.valid and rising_edge(clk);

    -- Must be explicitly zero, can not be '-'.
    check_equal(axi_write_m2s.w.strb(expected'range), expected, error_message);
  end process;


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
  awaddr <= std_logic_vector(axi_write_m2s.aw.addr(awaddr'range));
  awlen <= std_logic_vector(axi_write_m2s.aw.len);
  awsize <= std_logic_vector(axi_write_m2s.aw.size);

  axi_write_s2m.b.id(bid'range) <= unsigned(bid);


  ------------------------------------------------------------------------------
  count_num_bursts : process
  begin
    wait until rising_edge(clk);

    num_bursts_done <= (
      num_bursts_done + to_int(axi_write_m2s.b.ready and axi_write_s2m.b.valid)
    );
  end process;


  ------------------------------------------------------------------------------
  -- Use AXI stream protocol checkers to ensure that ready/valid behave as they should,
  -- and that none of the fields change value unless a transaction has occurred.
  aw_axi_stream_protocol_checker_block : block
    constant packed_width : positive := axi_m2s_a_sz(id_width=>id_width, addr_width=>address_width);
    signal packed : std_ulogic_vector(packed_width - 1 downto 0) := (others => '0');
  begin

    ------------------------------------------------------------------------------
    aw_axi_stream_protocol_checker_inst : entity common.axi_stream_protocol_checker
      generic map (
        data_width => packed'length,
        logger_name_suffix => " - axi_write_slave - AW" & logger_name_suffix
      )
      port map (
        clk => clk,
        --
        ready => axi_write_s2m.aw.ready,
        valid => axi_write_m2s.aw.valid,
        data => packed
      );

    packed <= to_slv(data=>axi_write_m2s.aw, id_width=>id_width, addr_width=>address_width);

  end block;


  ------------------------------------------------------------------------------
  w_axi_stream_protocol_checker_block : block
    constant packed_width : positive := axi_m2s_w_sz(data_width=>data_width, id_width=>wid_width);
    signal packed : std_ulogic_vector(packed_width - 1 downto 0) := (others => '0');
  begin

    ------------------------------------------------------------------------------
    w_axi_stream_protocol_checker_inst : entity common.axi_stream_protocol_checker
      generic map (
        data_width => packed'length,
        logger_name_suffix => " - axi_write_slave - W" & logger_name_suffix
      )
      port map (
        clk => clk,
        --
        ready => axi_write_s2m.w.ready,
        valid => axi_write_m2s.w.valid,
        data => packed
      );

    packed <= to_slv(data=>axi_write_m2s.w, data_width=>data_width, id_width=>wid_width);

  end block;


  ------------------------------------------------------------------------------
  check_wid_gen : if wid_width > 0 generate
    constant wid_queue : queue_t := new_queue;
    signal is_first_beat_of_burst : std_ulogic := '1';
  begin

    ------------------------------------------------------------------------------
    push_reference_wid : process
    begin
      wait until axi_write_s2m.aw.ready and axi_write_m2s.aw.valid and rising_edge(clk);

      -- Set expected WID for this burst.
      push(wid_queue, axi_write_m2s.aw.id(awid'range));
    end process;


    ------------------------------------------------------------------------------
    check_wid : process
      constant error_message : string := (
        " - axi_write_slave - B"
        & logger_name_suffix
        & ": Must receive AW transaction before corresponding W transactions"
      );
      variable reference_wid : u_unsigned(awid'range) := (others => '0');
    begin
      wait until axi_write_s2m.w.ready and axi_write_m2s.w.valid and rising_edge(clk);

      if is_first_beat_of_burst then
        check_equal(is_empty(wid_queue), false, error_message);
        reference_wid := pop(wid_queue);
      end if;

      check_equal(axi_write_m2s.w.id(reference_wid'range), reference_wid);

      is_first_beat_of_burst <= axi_write_m2s.w.last;
    end process;

  end generate;


  ------------------------------------------------------------------------------
  b_axi_stream_protocol_checker_inst : entity common.axi_stream_protocol_checker
    generic map (
      logger_name_suffix => " - axi_write_slave - B" & logger_name_suffix
    )
    port map (
      clk => clk,
      --
      ready => axi_write_m2s.b.ready
    );

end architecture;
