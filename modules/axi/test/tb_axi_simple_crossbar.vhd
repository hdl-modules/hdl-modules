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
use ieee.numeric_std.all;

library osvvm;
use osvvm.RandomPkg.RandomPType;

library vunit_lib;
use vunit_lib.axi_slave_pkg.all;
use vunit_lib.integer_array_pkg.all;
use vunit_lib.logger_pkg.all;
use vunit_lib.memory_pkg.all;
use vunit_lib.memory_utils_pkg.all;
use vunit_lib.queue_pkg.all;
use vunit_lib.random_pkg.all;
use vunit_lib.run_pkg.all;

library bfm;
use bfm.axi_bfm_pkg.all;
use bfm.queue_bfm_pkg.all;

library common;
use common.types_pkg.all;

use work.axi_pkg.all;


entity tb_axi_simple_crossbar is
  generic(
    runner_cfg : string
  );
end entity;

architecture tb of tb_axi_simple_crossbar is

  -- Generic constants.
  constant num_inputs : positive := 4;
  constant id_width : positive := 8;
  constant data_width : positive := 32;

  -- DUT connections.
  constant clk_period : time := 5 ns;
  signal clk : std_ulogic := '0';

  signal inputs_read_m2s : axi_read_m2s_vec_t(num_inputs - 1 downto 0) := (
    others => axi_read_m2s_init
  );
  signal inputs_read_s2m : axi_read_s2m_vec_t(inputs_read_m2s'range) := (
    others => axi_read_s2m_init
  );

  signal inputs_write_m2s : axi_write_m2s_vec_t(inputs_read_m2s'range) := (
    others => axi_write_m2s_init
  );
  signal inputs_write_s2m : axi_write_s2m_vec_t(inputs_read_m2s'range) := (
    others => axi_write_s2m_init
  );

  signal output_write_m2s : axi_write_m2s_t := axi_write_m2s_init;
  signal output_write_s2m : axi_write_s2m_t := axi_write_s2m_init;

  signal output_read_m2s : axi_read_m2s_t := axi_read_m2s_init;
  signal output_read_s2m : axi_read_s2m_t := axi_read_s2m_init;

  -- Testbench stuff.
  constant memory : memory_t := new_memory;

  constant read_job_queues, read_data_queues, write_job_queues, write_data_queues : queue_vec_t(
    inputs_read_m2s'range
  ) := get_new_queues(inputs_read_m2s'length);

  signal num_read_bursts_checked, num_write_bursts_done : natural_vec_t(inputs_read_m2s'range) := (
    others => 0
  );

begin

  clk <= not clk after clk_period / 2;
  test_runner_watchdog(runner, 100 us);


  ------------------------------------------------------------------------------
  main : process
    variable rnd : RandomPType;

    constant num_bursts : positive := 4 * num_inputs;
    variable num_reads_expected, num_writes_expected : natural_vec_t(inputs_read_m2s'range) := (
      others => 0
    );

    procedure send_bursts(read_not_write : boolean) is
      constant bytes_per_beat : positive := data_width / 8;

      variable burst_length_bytes : positive := 1;
      variable input_select : natural := 0;

      variable buf : buffer_t := null_buffer;
      variable job : axi_master_bfm_job_t := axi_master_bfm_job_init;
      variable random_data : integer_array_t := null_integer_array;
    begin
      for burst_index in 0 to num_bursts - 1 loop
        -- The DUT does nothing with the burst length, so testing all the way up to the maximum
        -- length does not add any value.
        -- It only increases the simulation time.
        -- Run short bursts instead to increase the input switching.
        burst_length_bytes := bytes_per_beat * rnd.FavorSmall(1, 16);
        input_select := rnd.RandInt(inputs_read_m2s'high);

        random_integer_array(
          rnd=>rnd,
          integer_array=>random_data,
          width=>burst_length_bytes,
          bits_per_word=>8
        );

        if read_not_write then
          buf := write_integer_array(
            memory=>memory,
            integer_array=>random_data,
            name=>"read buffer #" & to_string(burst_index),
            alignment=>4096
          );
        else
          buf := set_expected_integer_array(
            memory=>memory,
            integer_array=>random_data,
            name=>"write buffer #" & to_string(burst_index),
            alignment=>4096
          );
        end if;

        job.address := base_address(buf);
        job.length_bytes := burst_length_bytes;
        job.id := rnd.RandInt(2 ** id_width - 1);

        report "address " & to_string(job.address) & ", length_bytes " &
          to_string(job.length_bytes) & ", id " & to_string(job.id);

        if read_not_write then
          push(read_job_queues(input_select), to_slv(job));
          push_ref(read_data_queues(input_select), random_data);
          num_reads_expected(input_select) := num_reads_expected(input_select) + 1;
        else
          push(write_job_queues(input_select), to_slv(job));
          push_ref(write_data_queues(input_select), random_data);
          num_writes_expected(input_select) := num_writes_expected(input_select) + 1;
        end if;
      end loop;
    end procedure;

  begin
    test_runner_setup(runner, runner_cfg);
    rnd.InitSeed(get_string_seed(runner_cfg));

    if run("test_random_read") then
      send_bursts(read_not_write=>true);

    elsif run("test_random_write") then
      send_bursts(read_not_write=>false);

    end if;

    wait until (
      num_read_bursts_checked = num_reads_expected
      and num_write_bursts_done = num_writes_expected
      and rising_edge(clk)
    );

    check_expected_was_written(memory);

    test_runner_cleanup(runner);
  end process;


  ------------------------------------------------------------------------------
  input_masters_gen : for index in inputs_read_m2s'range generate

    ------------------------------------------------------------------------------
    axi_read_master_inst : entity bfm.axi_read_master
      generic map (
        id_width => id_width,
        data_width => data_width,
        job_queue => read_job_queues(index),
        reference_data_queue => read_data_queues(index),
        logger_name_suffix => " - input #" & to_string(index)
      )
      port map (
        clk => clk,
        --
        axi_read_m2s => inputs_read_m2s(index),
        axi_read_s2m => inputs_read_s2m(index),
        --
        num_bursts_checked => num_read_bursts_checked(index)
      );


    ------------------------------------------------------------------------------
    axi_write_master_inst : entity bfm.axi_write_master
      generic map (
        id_width => id_width,
        data_width => data_width,
        job_queue => write_job_queues(index),
        data_queue => write_data_queues(index),
        logger_name_suffix => " - input #" & to_string(index)
      )
      port map (
        clk => clk,
        --
        axi_write_m2s => inputs_write_m2s(index),
        axi_write_s2m => inputs_write_s2m(index),
        --
        num_bursts_done => num_write_bursts_done(index)
      );

  end generate;


  ------------------------------------------------------------------------------
  axi_slave_block : block
    constant axi_read_slave, axi_write_slave : axi_slave_t := new_axi_slave(
      memory => memory,
      address_fifo_depth => 8,
      write_response_fifo_depth => 8,
      address_stall_probability => 0.3,
      data_stall_probability => 0.3,
      write_response_stall_probability => 0.3,
      min_response_latency => 12 * clk_period,
      max_response_latency => 20 * clk_period,
      logger => get_logger("axi_slave")
    );
  begin

    ------------------------------------------------------------------------------
    axi_slave_inst : entity bfm.axi_slave
      generic map (
        axi_read_slave => axi_read_slave,
        axi_write_slave => axi_write_slave,
        data_width => data_width,
        id_width => id_width
      )
      port map (
        clk => clk,
        --
        axi_read_m2s => output_read_m2s,
        axi_read_s2m => output_read_s2m,
        --
        axi_write_m2s => output_write_m2s,
        axi_write_s2m => output_write_s2m
      );

  end block;


  ------------------------------------------------------------------------------
  dut_read : entity work.axi_simple_read_crossbar
    generic map(
      num_inputs => num_inputs
    )
    port map(
      clk => clk,
      --
      input_ports_m2s => inputs_read_m2s,
      input_ports_s2m => inputs_read_s2m,
      --
      output_m2s => output_read_m2s,
      output_s2m => output_read_s2m
    );


  ------------------------------------------------------------------------------
  dut_write : entity work.axi_simple_write_crossbar
    generic map(
      num_inputs => num_inputs
    )
    port map(
      clk => clk,
      --
      input_ports_m2s => inputs_write_m2s,
      input_ports_s2m => inputs_write_s2m,
      --
      output_m2s => output_write_m2s,
      output_s2m => output_write_s2m
    );

end architecture;
