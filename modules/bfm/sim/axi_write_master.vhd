-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the hdl_modules project, a collection of reusable, high-quality,
-- peer-reviewed VHDL building blocks.
-- https://hdl-modules.com
-- https://gitlab.com/hdl_modules/hdl_modules
-- -------------------------------------------------------------------------------------------------
-- BFM that creates AXI write transactions based on a simple interface.
-- ``AW`` transactions will be created based on jobs (``axi_master_bfm_job_t``) that the user
-- pushes to the ``job_queue``.
-- A ``W`` burst will be created based on the ``integer_array_t`` data
-- pushed by the user to the ``data_queue``.
-- Each ``AW`` transaction will result in a check that the eventually returned ``BID`` is correct.
--
-- The job address is assumed to be aligned with bus data width.
--
-- The byte length of the transactions (as set in the ``job_queue`` records, as well as indicated by
-- the length of the ``data_queue`` arrays) does not need to be aligned with the data width of
-- the bus.
-- If unaligned, the last AXI beat will have a strobe that is not '1' for all byte lanes.
--
-- Note that data can be pushed to ``data_queue`` before the corresponding job is pushed.
-- This data will be pushed to the AXI ``W`` channel straight away, unless in AXI3 mode.
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

use work.axi_bfm_pkg.all;


entity axi_write_master is
  generic (
    -- The desired width of the 'AWID' and, possibly if using AXI3, 'WID' signals.
    id_width : natural;
    -- The desired width of the 'WDATA' signal.
    data_width : positive;
    -- Push jobs (SLV of axi_master_bfm_job_t) to this queue. Each job pushed will result in an
    -- AW transaction and eventually a B check.
    job_queue : queue_t;
    -- Push data (integer_array_t with push_ref()) to this queue. Each element should be an
    -- unsigned byte. Little endian byte order is assumed.
    data_queue : queue_t;
    -- Stall configuration for the AW channel master
    aw_stall_config : stall_config_t := default_address_stall_config;
    -- Stall configuration for the W channel master
    w_stall_config : stall_config_t := default_data_stall_config;
    -- Stall configuration for the B channel slave
    b_stall_config : stall_config_t := default_data_stall_config;
    -- Random seed for handshaking stall/jitter.
    -- Set to something unique in order to vary the random sequence.
    seed : natural := 0;
    -- Suffix for the VUnit logger name. Can be used to differentiate between multiple instances.
    logger_name_suffix : string := "";
    -- When this generic is set, 'WID' will be assigned to same ID as corresponding AW transaction.
    -- Also means that W data will never be sent before an AW transaction
    set_axi3_w_id : boolean := false
  );
  port (
    clk : in std_ulogic;
    --# {{}}
    axi_write_m2s : out axi_write_m2s_t := axi_write_m2s_init;
    axi_write_s2m : in axi_write_s2m_t
  );
end entity;

architecture a of axi_write_master is

  constant bytes_per_beat : positive := data_width / 8;

  constant b_id_queue, w_id_queue : queue_t := new_queue;

begin

  ------------------------------------------------------------------------------
  aw_block : block
    signal data_is_valid : std_ulogic := '0';

    signal id_target : u_unsigned(axi_write_m2s.aw.id'range) := (others => 'X');
    signal addr_target : u_unsigned(axi_write_m2s.aw.addr'range) := (others => 'X');
    signal len_target : u_unsigned(axi_write_m2s.aw.len'range) := (others => 'X');
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

      if set_axi3_w_id then
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
        logger_name_suffix => "_axi_write_master_aw" & logger_name_suffix
      )
      port map (
        clk => clk,
        --
        data_is_valid => data_is_valid,
        --
        ready => axi_write_s2m.aw.ready,
        valid => axi_write_m2s.aw.valid
      );

    axi_write_m2s.aw.id <= id_target when axi_write_m2s.aw.valid else (others => 'X');
    axi_write_m2s.aw.addr <= addr_target when axi_write_m2s.aw.valid else (others => 'X');
    axi_write_m2s.aw.len <= len_target when axi_write_m2s.aw.valid else (others => 'X');
    axi_write_m2s.aw.size <= to_size(data_width) when axi_write_m2s.aw.valid else (others => 'X');
    axi_write_m2s.aw.burst <= axi_a_burst_incr when axi_write_m2s.aw.valid else (others => 'X');

  end block;


  ------------------------------------------------------------------------------
  w_block : block
    -- When we should set WID, we have to wait with sending the W transaction until we know the
    -- AWID. Hence the control logic is a little different. In this case we use an intermediary
    -- queue for the W data.
    impure function get_w_data_queue return queue_t is
    begin
      if set_axi3_w_id then
        return new_queue;
      end if;
      return data_queue;
    end function;
    constant w_data_queue : queue_t := get_w_data_queue;
  begin

    ------------------------------------------------------------------------------
    handle_w_id : if set_axi3_w_id generate
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
        logger_name_suffix => "_axi_write_master_w" & logger_name_suffix
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
    signal b_slv : std_ulogic_vector(axi_s2m_b_sz(id_width=>id_width) - 1 downto 0)
      := (others => '0');
  begin

    ------------------------------------------------------------------------------
    check_b : process
      variable id_reference : natural := 0;
    begin
      wait until axi_write_m2s.b.ready and axi_write_s2m.b.valid and rising_edge(clk);

      id_reference := pop(b_id_queue);

      -- Response code OKAY
      check_equal(axi_write_s2m.b.resp, 0);
      check_equal(axi_write_s2m.b.id, id_reference);
    end process;


    ------------------------------------------------------------------------------
    handshake_slave_inst : entity work.handshake_slave
      generic map (
        stall_config => b_stall_config,
        seed => seed,
        logger_name_suffix => "_axi_write_master_b" & logger_name_suffix,
        data_width => b_slv'length
      )
      port map (
        clk => clk,
        --
        ready => axi_write_m2s.b.ready,
        valid => axi_write_s2m.b.valid,
        data => b_slv
      );

    b_slv <= to_slv(axi_write_s2m.b, id_width=>id_width);

  end block;

end architecture;
