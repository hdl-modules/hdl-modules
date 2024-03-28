-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the hdl-modules project, a collection of reusable, high-quality,
-- peer-reviewed VHDL building blocks.
-- https://hdl-modules.com
-- https://github.com/hdl-modules/hdl-modules
-- -------------------------------------------------------------------------------------------------

library ieee;
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

use work.axi_bfm_pkg.all;


entity tb_axi_read_bfm is
  generic (
    data_width : positive range 8 to axi_data_sz;
    seed : natural;
    runner_cfg : string
  );
end entity;

architecture tb of tb_axi_read_bfm is

  -- DUT connections
  signal clk : std_ulogic := '0';

  signal axi_read_m2s : axi_read_m2s_t := axi_read_m2s_init;
  signal axi_read_s2m : axi_read_s2m_t := axi_read_s2m_init;

  -- Testbench stuff
  constant id_width : natural := 5;

  constant bytes_per_beat : positive := data_width / 8;

  -- Do short bursts in order to keep the simulation time down
  constant max_burst_length_beats : positive := 16;
  constant max_burst_length_bytes : positive := bytes_per_beat * max_burst_length_beats;

  constant clk_period : time := 5 ns;

  shared variable rnd : RandomPType;

  constant job_queue, data_queue : queue_t := new_queue;

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

  signal num_bursts_checked : natural := 0;

begin

  clk <= not clk after clk_period / 2;
  test_runner_watchdog(runner, 100 us);


  ------------------------------------------------------------------------------
  main : process
    variable num_bursts_expected : natural := 0;

    procedure send_random_burst is
      constant burst_length_bytes : positive := rnd.RandInt(1, max_burst_length_bytes);

      variable random_data : integer_array_t := null_integer_array;
      variable buf, buf_dummy : buffer_t := null_buffer;
      variable job : axi_master_bfm_job_t := axi_master_bfm_job_init;
    begin
      buf := allocate(
        memory=>memory,
        num_bytes=>burst_length_bytes,
        name=>"read_buffer_" & to_string(num_bursts_expected),
        alignment=>4096,
        permissions=>read_only
      );

      if burst_length_bytes mod bytes_per_beat /= 0 then
        buf_dummy := allocate(
          memory=>memory,
          num_bytes=>bytes_per_beat - (burst_length_bytes mod bytes_per_beat),
          name=>"dummy_buffer_to_avoid_reading_from_unallocated_area",
          alignment=>1,
          permissions=>read_only
        );
      end if;

      job.address := base_address(buf);
      job.length_bytes := burst_length_bytes;
      job.id := rnd.RandInt(2 ** id_width - 1);

      push(job_queue, to_slv(job));

      random_integer_array(
        rnd=>rnd,
        integer_array=>random_data,
        width=>burst_length_bytes,
        bits_per_word=>8
      );

      write_integer_array(
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

    wait until num_bursts_checked = num_bursts_expected and rising_edge(clk);

    test_runner_cleanup(runner);
  end process;


  ------------------------------------------------------------------------------
  axi_read_master_inst : entity work.axi_read_master
    generic map (
      id_width => id_width,
      data_width => data_width,
      job_queue => job_queue,
      reference_data_queue => data_queue,
      seed => seed
    )
    port map (
      clk => clk,
      --
      axi_read_m2s => axi_read_m2s,
      axi_read_s2m => axi_read_s2m,
      --
      num_bursts_checked => num_bursts_checked
    );


  ------------------------------------------------------------------------------
  axi_read_slave_inst : entity work.axi_read_slave
    generic map (
      axi_slave => axi_slave,
      data_width => data_width,
      id_width => id_width
    )
    port map (
      clk => clk,
      --
      axi_read_m2s => axi_read_m2s,
      axi_read_s2m => axi_read_s2m
    );


  ------------------------------------------------------------------------------
  check_ar_invalid_values : process
    constant ar_all_x : axi_m2s_a_t := (
      valid => '0',
      id => (others => 'X'),
      addr => (others => 'X'),
      len => (others => 'X'),
      size => (others => 'X'),
      burst => (others => 'X')
    );
  begin
    wait until rising_edge(clk);

    -- The master BFM should drive everything on the AR channel with 'X' when the bus is not valid.

    if not axi_read_m2s.ar.valid then
      assert axi_read_m2s.ar = ar_all_x report "AR not all fields X";
    end if;
  end process;


  ------------------------------------------------------------------------------
  check_r_invalid_values : process
    constant data_all_x : std_ulogic_vector(data_width - 1 downto 0) := (others => 'X');
    constant id_all_x : std_ulogic_vector(id_width - 1 downto 0) := (others => 'X');
    constant resp_all_x : axi_resp_t := (others => 'X');
  begin
    wait until rising_edge(clk);

    -- The slave BFM should drive everything on the R channel with 'X' when the bus is not valid.

    if not axi_read_s2m.r.valid then
      check_equal(axi_read_s2m.r.data(data_all_x'range), data_all_x);
      check_equal(std_ulogic_vector(axi_read_s2m.r.id(id_all_x'range)), id_all_x);
      check_equal(axi_read_s2m.r.resp, resp_all_x);
      check_equal(axi_read_s2m.r.last, 'X');
    end if;
  end process;


end architecture;
