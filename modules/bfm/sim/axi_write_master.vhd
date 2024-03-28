-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the hdl-modules project, a collection of reusable, high-quality,
-- peer-reviewed VHDL building blocks.
-- https://hdl-modules.com
-- https://github.com/hdl-modules/hdl-modules
-- -------------------------------------------------------------------------------------------------
-- BFM that creates AXI write transactions and checkers based on a simple interface.
--
-- ``AW`` transactions will be created based on jobs (``axi_master_bfm_job_t``) that the user
-- pushes to the ``job_queue`` :doc:`VUnit queue <vunit:data_types/queue>`.
-- A ``W`` burst will be created based on the
-- :doc:`integer_array_t <vunit:data_types/integer_array>` data pushed by the user to
-- the ``data_queue``.
-- Each ``AW`` transaction will result in a check that the eventually returned ``BID`` is correct.
--
-- .. note::
--
--   This BFM will inject random handshake jitter/stalling on the AXI channels for good
--   verification coverage.
--   Modify the ``aw_stall_config``, ``w_stall_config`` and ``b_stall_config`` generics to change
--   the behavior.
--   You can also set ``seed`` to something unique in order to vary the randomization in each
--   simulation run.
--   This can be done conveniently with the
--   :meth:`add_vunit_config() <tsfpga.module.BaseModule.add_vunit_config>` method if using tsfpga.
--
-- The byte length of the transactions (as set in the ``job`` as well as by the length of the
-- ``data_queue`` arrays) does not need to be aligned with the data width of the bus.
-- If unaligned, the last AXI beat will have a strobe that is not '1' for all byte lanes.
--
-- The ``job`` address, however, is assumed to be aligned with bus data width.
--
-- Note that data can be pushed to ``data_queue`` before the corresponding job is pushed.
-- This data will be pushed to the AXI ``W`` channel straight away, possibly before the ``AW``
-- transaction (unless in AXI3 mode).
--
-- This BFM will also perform protocol checking to verify that the downstream AXI slave is
-- performing everything correctly.
-- -------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
use vunit_lib.check_pkg.all;
use vunit_lib.integer_array_pkg.all;
use vunit_lib.queue_pkg.all;

library axi;
use axi.axi_pkg.all;

library bfm;
use bfm.stall_bfm_pkg.stall_configuration_t;

library common;
use common.types_pkg.all;

use work.axi_bfm_pkg.all;


entity axi_write_master is
  generic (
    -- The desired width of the 'AWID' and 'BID' signals, as well as 'WID' if using AXI3.
    id_width : natural range 0 to axi_id_sz;
    -- The desired width of the 'WDATA' signal.
    data_width : positive range 8 to axi_data_sz;
    -- Push jobs (SLV of axi_master_bfm_job_t) to this queue. Each job pushed will result in an
    -- AW transaction and eventually a B check.
    job_queue : queue_t;
    -- Push data (integer_array_t with push_ref()) to this queue. Each element should be an
    -- unsigned byte. Little endian byte order is assumed.
    data_queue : queue_t;
    -- Stall configuration for the AW channel master
    aw_stall_config : stall_configuration_t := default_address_stall_config;
    -- Stall configuration for the W channel master
    w_stall_config : stall_configuration_t := default_data_stall_config;
    -- Stall configuration for the B channel slave
    b_stall_config : stall_configuration_t := default_data_stall_config;
    -- Random seed for handshaking stall/jitter.
    -- Set to something unique in order to vary the random sequence.
    seed : natural := 0;
    -- Suffix for error log messages. Can be used to differentiate between multiple instances.
    logger_name_suffix : string := "";
    -- When this generic is set, 'WID' will be assigned to same ID as corresponding
    -- 'AW' transaction.
    -- It also changes the transaction behavior, so that 'W' data will never be sent before
    -- the 'AW' transaction
    enable_axi3 : boolean := false;
    -- When 'AWVALID' or 'WVALID' is zero, the associated output ports will be driven with
    -- this value.
    -- This is to avoid a DUT sampling the values in the wrong clock cycle.
    drive_invalid_value : std_ulogic := 'X'
  );
  port (
    clk : in std_ulogic;
    --# {{}}
    axi_write_m2s : out axi_write_m2s_t := axi_write_m2s_init;
    axi_write_s2m : in axi_write_s2m_t;
    --# {{}}
    num_bursts_done : out natural := 0
  );
end entity;

architecture a of axi_write_master is

  constant bytes_per_beat : positive := data_width / 8;

  constant b_id_queue, w_id_queue : queue_t := new_queue;

begin

  ------------------------------------------------------------------------------
  assert sanity_check_axi_data_width(data_width)
    report "Invalid AXI data width, see printout above"
    severity failure;


  ------------------------------------------------------------------------------
  aw_block : block
    signal data_is_valid : std_ulogic := '0';

    constant size_target : axi_a_size_t := to_size(data_width);
    constant burst_target : axi_a_burst_t := axi_a_burst_incr;

    signal id_target : u_unsigned(axi_write_m2s.aw.id'range) := (others => '0');
    signal addr_target : u_unsigned(axi_write_m2s.aw.addr'range) := (others => '0');
    signal len_target : axi_a_len_t := (others => '0');
  begin

    ------------------------------------------------------------------------------
    set_aw : process
      variable job_slv : std_ulogic_vector(axi_master_bfm_job_size - 1 downto 0) := (others => '0');
      variable job : axi_master_bfm_job_t := axi_master_bfm_job_init;
    begin
      while is_empty(job_queue) loop
        wait until rising_edge(clk);
      end loop;
      job_slv := pop(job_queue);
      job := to_axi_bfm_job(job_slv);

      if enable_axi3 then
        push(w_id_queue, job.id);
      end if;

      push(b_id_queue, job.id);

      id_target <= to_unsigned(job.id, id_target'length);
      addr_target <= to_unsigned(job.address, addr_target'length);
      len_target <= to_len((job.length_bytes + bytes_per_beat - 1) / bytes_per_beat);

      data_is_valid <= '1';

      wait until axi_write_s2m.aw.ready and axi_write_m2s.aw.valid and rising_edge(clk);

      data_is_valid <= '0';
    end process;


    ------------------------------------------------------------------------------
    handshake_master_inst : entity work.handshake_master
      generic map (
        stall_config => aw_stall_config,
        seed => seed,
        logger_name_suffix => " - axi_write_master - AW" & logger_name_suffix
      )
      port map (
        clk => clk,
        --
        data_is_valid => data_is_valid,
        --
        ready => axi_write_s2m.aw.ready,
        valid => axi_write_m2s.aw.valid
      );

    axi_write_m2s.aw.id <=
      id_target when axi_write_m2s.aw.valid else (others => drive_invalid_value);

    axi_write_m2s.aw.addr <=
      addr_target when axi_write_m2s.aw.valid else (others => drive_invalid_value);

    axi_write_m2s.aw.len <=
      len_target when axi_write_m2s.aw.valid else (others => drive_invalid_value);

    axi_write_m2s.aw.size <=
      size_target when axi_write_m2s.aw.valid else (others => drive_invalid_value);

    axi_write_m2s.aw.burst <=
      burst_target when axi_write_m2s.aw.valid else (others => drive_invalid_value);

  end block;


  ------------------------------------------------------------------------------
  w_block : block
    -- When we should set WID, we have to wait with sending the W transaction until we know the
    -- AWID. Hence the control logic is a little different. In this case we use an intermediary
    -- queue for the W data.
    impure function get_w_data_queue return queue_t is
    begin
      if enable_axi3 then
        return new_queue;
      end if;
      return data_queue;
    end function;
    constant w_data_queue : queue_t := get_w_data_queue;
  begin

    ------------------------------------------------------------------------------
    handle_w_id : if enable_axi3 generate
      signal current_w_id : natural := 0;
    begin

      ------------------------------------------------------------------------------
      set_data_and_id : process
        variable data : integer_array_t := null_integer_array;
      begin
        while is_empty(data_queue) loop
          wait until rising_edge(clk);
        end loop;
        data := pop_ref(data_queue);

        -- Wait until we know the WID
        while is_empty(w_id_queue) loop
          wait until rising_edge(clk);
        end loop;
        current_w_id <= pop(w_id_queue);

        -- Start sending W data via the axi_stream_master now that we know the WID
        push_ref(w_data_queue, data);

        -- Set new WID next burst
        wait until
          (axi_write_s2m.w.ready and axi_write_m2s.w.valid and axi_write_m2s.w.last) = '1'
          and rising_edge(clk);
      end process;

      -- Set the WID only when bus is valid
      axi_write_m2s.w.id(id_width - 1 downto 0) <=
        to_unsigned(current_w_id, id_width) when axi_write_m2s.w.valid
        else (others => 'X');

    end generate;


    ------------------------------------------------------------------------------
    axi_stream_master_inst : entity work.axi_stream_master
      generic map (
        data_width => data_width,
        data_queue => w_data_queue,
        stall_config => w_stall_config,
        seed => seed,
        logger_name_suffix => " - axi_write_master - W" & logger_name_suffix,
        drive_invalid_value => drive_invalid_value
      )
      port map (
        clk => clk,
        --
        ready => axi_write_s2m.w.ready,
        valid => axi_write_m2s.w.valid,
        last => axi_write_m2s.w.last,
        data => axi_write_m2s.w.data(data_width - 1 downto 0),
        strobe => axi_write_m2s.w.strb(bytes_per_beat - 1 downto 0)
      );

  end block;


  ------------------------------------------------------------------------------
  b_block : block
  begin

    ------------------------------------------------------------------------------
    check_b : process
      variable id_reference : natural := 0;
    begin
      wait until axi_write_m2s.b.ready and axi_write_s2m.b.valid and rising_edge(clk);

      check_equal(axi_write_s2m.b.resp, axi_resp_okay);

      id_reference := pop(b_id_queue);
      if id_width > 0 then
        check_equal(axi_write_s2m.b.id(id_width - 1 downto 0), id_reference);
      end if;

      num_bursts_done <= num_bursts_done + 1;
    end process;


    ------------------------------------------------------------------------------
    handshake_slave_inst : entity work.handshake_slave
      generic map (
        stall_config => b_stall_config,
        seed => seed,
        logger_name_suffix => " - axi_write_master - B" & logger_name_suffix
      )
      port map (
        clk => clk,
        --
        ready => axi_write_m2s.b.ready,
        valid => axi_write_s2m.b.valid
      );


    ------------------------------------------------------------------------------
    b_protocol_checker_inst : entity common.axi_stream_protocol_checker
      generic map (
        id_width => id_width,
        user_width => axi_write_s2m.b.resp'length,
        logger_name_suffix => " - axi_write_master - B"
      )
      port map (
        clk => clk,
        --
        ready => axi_write_m2s.b.ready,
        valid => axi_write_s2m.b.valid,
        id => axi_write_s2m.b.id(id_width - 1 downto 0),
        user => axi_write_s2m.b.resp
      );

  end block;

end architecture;
