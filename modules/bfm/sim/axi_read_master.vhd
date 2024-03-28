-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the hdl-modules project, a collection of reusable, high-quality,
-- peer-reviewed VHDL building blocks.
-- https://hdl-modules.com
-- https://github.com/hdl-modules/hdl-modules
-- -------------------------------------------------------------------------------------------------
-- BFM that creates AXI read transactions and checkers based on a simple interface.
--
-- ``AR`` transactions will be created based on jobs (``axi_master_bfm_job_t``) that the user
-- pushes to the ``job_queue`` :doc:`VUnit queue <vunit:data_types/queue>`.
-- The data returned on the ``R`` channel will be checked against the
-- :doc:`integer_array_t <vunit:data_types/integer_array>` data
-- pushed by the user to the ``reference_data_queue``.
-- The returned ``RID`` will be checked that it is the same as the corresponding ``ARID``.
--
-- .. note::
--
--   This BFM will inject random handshake jitter/stalling on the AXI channels for good
--   verification coverage.
--   Modify the ``ar_stall_config`` and ``r_stall_config`` generics to change the behavior.
--   You can also set ``seed`` to something unique in order to vary the randomization in each
--   simulation run.
--   This can be done conveniently with the
--   :meth:`add_vunit_config() <tsfpga.module.BaseModule.add_vunit_config>` method if using tsfpga.
--
-- This BFM will also perform AXI-Stream protocol checking on the ``R`` channels to verify that the
-- downstream AXI slave is performing everything correctly.
--
-- The byte length of the transactions (as set in the ``job`` as well as by the length of the
-- ``reference_data`` arrays) does not need to be aligned with the data width of the bus.
-- If unaligned, the last AXI beat will not have all byte lanes checked against reference data.
--
-- .. warning::
--
--   The ``RID`` check is based on the assumption that ``R`` transactions are returned in the same
--   order as ``AR`` transactions are sent.
--
--   Also the ``job`` address is assumed to be aligned with the bus data width.
-- -------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
use vunit_lib.check_pkg.all;
use vunit_lib.queue_pkg.all;

library axi;
use axi.axi_pkg.all;

library bfm;
use bfm.stall_bfm_pkg.stall_configuration_t;

library common;
use common.types_pkg.all;

use work.axi_bfm_pkg.all;


entity axi_read_master is
  generic (
    -- The desired width of the 'ARID' and 'RID' signals.
    id_width : natural range 0 to axi_id_sz;
    -- The desired width of the 'RDATA' signal.
    data_width : positive range 8 to axi_data_sz;
    -- Push jobs (SLV of axi_master_bfm_job_t) to this queue. Each job pushed will result in an
    -- AR transaction.
    job_queue : queue_t;
    -- Push reference data (integer_array_t with push_ref()) to this queue.
    -- Each element should be an unsigned byte. Little endian byte order is assumed.
    -- The data returned on the R channel will be checked against this data.
    reference_data_queue : queue_t;
    -- Stall configuration for the AR channel master
    ar_stall_config : stall_configuration_t := default_address_stall_config;
    -- Stall configuration for the R channel slave
    r_stall_config : stall_configuration_t := default_data_stall_config;
    -- Random seed for handshaking stall/jitter.
    -- Set to something unique in order to vary the random sequence.
    seed : natural := 0;
    -- Suffix for error log messages. Can be used to differentiate between multiple instances.
    logger_name_suffix : string := "";
    -- When 'ARVALID' is zero, the associated output ports will be driven with this value.
    -- This is to avoid a DUT sampling the values in the wrong clock cycle.
    drive_invalid_value : std_ulogic := 'X'
  );
  port (
    clk : in std_ulogic;
    --# {{}}
    axi_read_m2s : out axi_read_m2s_t := axi_read_m2s_init;
    axi_read_s2m : in axi_read_s2m_t;
    --# {{}}
    num_bursts_checked : out natural := 0
  );
end entity;

architecture a of axi_read_master is

  constant bytes_per_beat : positive := data_width / 8;

  constant r_id_queue : queue_t := new_queue;

begin

  ------------------------------------------------------------------------------
  assert sanity_check_axi_data_width(data_width)
    report "Invalid AXI data width, see printout above"
    severity failure;


  ------------------------------------------------------------------------------
  ar_block : block
    signal data_is_valid : std_ulogic := '0';

    constant size_target : axi_a_size_t := to_size(data_width);
    constant burst_target : axi_a_burst_t := axi_a_burst_incr;

    signal id_target : u_unsigned(axi_read_m2s.ar.id'range) := (others => '0');
    signal addr_target : u_unsigned(axi_read_m2s.ar.addr'range) := (others => '0');
    signal len_target : axi_a_len_t := (others => '0');
  begin

    ------------------------------------------------------------------------------
    set_ar : process
      variable job_slv : std_ulogic_vector(axi_master_bfm_job_size - 1 downto 0) := (others => '0');
      variable job : axi_master_bfm_job_t := axi_master_bfm_job_init;
    begin
      while is_empty(job_queue) loop
        wait until rising_edge(clk);
      end loop;

      job_slv := pop(job_queue);
      job := to_axi_bfm_job(job_slv);

      push(r_id_queue, job.id);

      id_target <= to_unsigned(job.id, id_target'length);
      addr_target <= to_unsigned(job.address, addr_target'length);
      len_target <= to_len((job.length_bytes + bytes_per_beat - 1) / bytes_per_beat);

      data_is_valid <= '1';

      wait until axi_read_s2m.ar.ready and axi_read_m2s.ar.valid and rising_edge(clk);

      data_is_valid <= '0';
    end process;


    ------------------------------------------------------------------------------
    handshake_master_inst : entity work.handshake_master
      generic map (
        stall_config => ar_stall_config,
        seed => seed,
        logger_name_suffix => " - axi_read_master - AR" & logger_name_suffix
      )
      port map (
        clk => clk,
        --
        data_is_valid => data_is_valid,
        --
        ready => axi_read_s2m.ar.ready,
        valid => axi_read_m2s.ar.valid
      );

    axi_read_m2s.ar.id <= id_target when axi_read_m2s.ar.valid else (others => drive_invalid_value);

    axi_read_m2s.ar.addr <=
      addr_target when axi_read_m2s.ar.valid else (others => drive_invalid_value);

    axi_read_m2s.ar.len <=
      len_target when axi_read_m2s.ar.valid else (others => drive_invalid_value);

    axi_read_m2s.ar.size <=
      size_target when axi_read_m2s.ar.valid else (others => drive_invalid_value);

    axi_read_m2s.ar.burst <=
      burst_target when axi_read_m2s.ar.valid else (others => drive_invalid_value);

  end block;


  ------------------------------------------------------------------------------
  r_block : block
  begin

    ------------------------------------------------------------------------------
    check_r : process
      constant error_message_base : string := (
        "axi_read_master - R"  & logger_name_suffix & ": 'RRESP' check in burst_idx="
      );
    begin
      wait until axi_read_m2s.r.ready and axi_read_s2m.r.valid and rising_edge(clk);

      -- Check response code OKAY (everything else is checked in the axi_stream_slave)
      check_equal(
        axi_read_s2m.r.resp,
        axi_resp_okay,
        error_message_base & to_string(num_bursts_checked)
      );

      num_bursts_checked <= num_bursts_checked + to_int(axi_read_s2m.r.last);
    end process;


    ------------------------------------------------------------------------------
    axi_stream_slave_inst : entity work.axi_stream_slave
      generic map (
        data_width => data_width,
        reference_data_queue => reference_data_queue,
        id_width => id_width,
        reference_id_queue => r_id_queue,
        stall_config => r_stall_config,
        seed => seed,
        logger_name_suffix => " - axi_read_master - R" & logger_name_suffix,
        enable_strobe => false
      )
      port map (
        clk => clk,
        --
        ready => axi_read_m2s.r.ready,
        valid => axi_read_s2m.r.valid,
        last => axi_read_s2m.r.last,
        id => axi_read_s2m.r.id(id_width - 1 downto 0),
        data => axi_read_s2m.r.data(data_width - 1 downto 0)
      );

  end block;

end architecture;
