-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the hdl-modules project, a collection of reusable, high-quality,
-- peer-reviewed VHDL building blocks.
-- https://hdl-modules.com
-- https://github.com/hdl-modules/hdl-modules
-- -------------------------------------------------------------------------------------------------

library ieee;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;

library osvvm;
use osvvm.RandomPkg.RandomPType;

library vunit_lib;
use vunit_lib.axi_slave_pkg.all;
use vunit_lib.check_pkg.all;
use vunit_lib.integer_array_pkg.all;
use vunit_lib.logger_pkg.all;
use vunit_lib.memory_pkg.all;
use vunit_lib.memory_utils_pkg.all;
use vunit_lib.queue_pkg.all;
use vunit_lib.random_pkg.all;
use vunit_lib.run_pkg.all;

library axi;
use axi.axi_pkg.all;

library common;
use common.types_pkg.all;

use work.axi_bfm_pkg.all;


entity tb_axi_write_bfm is
  generic (
    data_width : positive range 8 to axi_data_sz;
    data_before_address : boolean;
    enable_axi3 : boolean;
    seed : natural;
    runner_cfg : string
  );
end entity;

architecture tb of tb_axi_write_bfm is

  -- DUT connections
  signal clk : std_ulogic := '0';

  signal axi_write_m2s : axi_write_m2s_t := axi_write_m2s_init;
  signal axi_write_s2m : axi_write_s2m_t := axi_write_s2m_init;

  -- Testbench stuff
  constant id_width : natural := 5;

  constant bytes_per_beat : positive := data_width / 8;

  -- Do short bursts in order to keep the simulation time down
  constant max_burst_length_beats : positive := 16;
  constant max_burst_length_bytes : positive := bytes_per_beat * max_burst_length_beats;

  constant clk_period : time := 5 ns;

  shared variable rnd : RandomPType;

  constant job_queue, intermediary_job_queue, data_queue : queue_t := new_queue;

  constant memory : memory_t := new_memory;
  constant axi_slave : axi_slave_t := new_axi_slave(
    memory => memory,
    address_fifo_depth => 4,
    address_stall_probability => 0.3,
    data_stall_probability => 0.5,
    min_response_latency => 12 * clk_period,
    max_response_latency => 20 * clk_period,
    logger => get_logger("axi_slave")
  );

  -- When testing in this mode we should have a FIFO on the W channel, to allow a lot of
  -- W transactions/bursts before the AW transaction.
  constant w_fifo_depth : natural := 1024 * to_int(data_before_address);

  signal num_bursts_written : natural := 0;

begin

  clk <= not clk after clk_period / 2;
  test_runner_watchdog(runner, 100 us);


  ------------------------------------------------------------------------------
  main : process
    variable num_bursts_expected : natural := 0;

    procedure send_random_burst is
      constant burst_length_bytes : positive := rnd.RandInt(1, max_burst_length_bytes);

      variable random_data : integer_array_t := null_integer_array;
      variable buf : buffer_t := null_buffer;
      variable job : axi_master_bfm_job_t := axi_master_bfm_job_init;
    begin
      buf := allocate(
        memory=>memory,
        num_bytes=>burst_length_bytes,
        name=>"write_buffer_" & to_string(num_bursts_expected),
        alignment=>4096,
        permissions=>write_only
      );

      job.address := base_address(buf);
      job.length_bytes := burst_length_bytes;
      job.id := rnd.RandInt(2 ** id_width - 1);

      if data_before_address then
        -- Push to an intermediary queue that will be delayed, compared to the data that will
        -- be sent straight away from the push below.
        push(intermediary_job_queue, to_slv(job));
      else
        -- Send job at the same time as the data.
        push(job_queue, to_slv(job));
      end if;

      random_integer_array(
        rnd=>rnd,
        integer_array=>random_data,
        width=>burst_length_bytes,
        bits_per_word=>8
      );

      set_expected_integer_array(
        memory=>memory,
        base_address=>base_address(buf),
        integer_array=>random_data
      );

      push_ref(data_queue, random_data);

      num_bursts_expected := num_bursts_expected + 1;
    end procedure;

  begin
    test_runner_setup(runner, runner_cfg);
    rnd.InitSeed(seed);

    if run("test_random_transactions") then
      for i in 0 to 50 loop
        send_random_burst;
      end loop;
    end if;

    wait until num_bursts_written = num_bursts_expected and rising_edge(clk);
    check_expected_was_written(memory);

    test_runner_cleanup(runner);
  end process;


  ------------------------------------------------------------------------------
  delay_job_block : if data_before_address generate

    ------------------------------------------------------------------------------
    delay_job : process
    begin
      -- In this mode, the main process sends job to this intermediary queue
      while is_empty(intermediary_job_queue) loop
        wait until rising_edge(clk);
      end loop;

      -- Send job on the real queue after a long while
      for delay_cycle in 1 to rnd.RandInt(100, 200) loop
        wait until rising_edge(clk);
      end loop;

      push_std_ulogic_vector(job_queue, pop_std_ulogic_vector(intermediary_job_queue));
    end process;

  end generate;


  ------------------------------------------------------------------------------
  axi_write_master_inst : entity work.axi_write_master
    generic map (
      id_width => id_width,
      data_width => data_width,
      job_queue => job_queue,
      data_queue => data_queue,
      seed => seed,
      enable_axi3 => enable_axi3
    )
    port map (
      clk => clk,
      --
      axi_write_m2s => axi_write_m2s,
      axi_write_s2m => axi_write_s2m,
      --
      num_bursts_done => num_bursts_written
    );


  ------------------------------------------------------------------------------
  axi_write_slave_inst : entity work.axi_write_slave
    generic map (
      axi_slave => axi_slave,
      data_width => data_width,
      id_width => id_width,
      w_fifo_depth => w_fifo_depth
    )
    port map (
      clk => clk,
      --
      axi_write_m2s => axi_write_m2s,
      axi_write_s2m => axi_write_s2m
    );


  ------------------------------------------------------------------------------
  check_aw_invalid_values : process
    constant aw_all_x : axi_m2s_a_t := (
      valid => '0',
      id => (others => 'X'),
      addr => (others => 'X'),
      len => (others => 'X'),
      size => (others => 'X'),
      burst => (others => 'X')
    );
  begin
    wait until rising_edge(clk);

    -- The master BFM should drive everything on the AW channel with 'X' when the bus is not valid.

    if not axi_write_m2s.aw.valid then
      assert axi_write_m2s.aw = aw_all_x report "AW not all fields X";
    end if;
  end process;


  ------------------------------------------------------------------------------
  check_w_invalid_values : process
    constant data_all_x : std_ulogic_vector(data_width - 1 downto 0) := (others => 'X');
    constant strb_all_x : std_ulogic_vector(data_width / 8 - 1 downto 0) := (others => 'X');
  begin
    wait until rising_edge(clk);

    -- The master BFM should drive everything on the W channel with 'X' when the bus is not valid.

    if not axi_write_m2s.w.valid then
      check_equal(axi_write_m2s.w.data(data_width - 1 downto 0), data_all_x);
      check_equal(axi_write_m2s.w.strb(strb_all_x'range), strb_all_x);
      check_equal(axi_write_m2s.w.last, 'X');
    end if;
  end process;


  ------------------------------------------------------------------------------
  check_b_invalid_values : process
    constant id_all_x : std_ulogic_vector(id_width - 1 downto 0) := (others => 'X');
    constant resp_all_x : axi_resp_t := (others => 'X');
  begin
    wait until rising_edge(clk);

    -- The slave BFM should drive everything on the B channel with 'X' when the bus is not valid.

    if not axi_write_s2m.b.valid then
      check_equal(std_ulogic_vector(axi_write_s2m.b.id(id_all_x'range)), id_all_x);
      check_equal(axi_write_s2m.b.resp, resp_all_x);
    end if;
  end process;

end architecture;
