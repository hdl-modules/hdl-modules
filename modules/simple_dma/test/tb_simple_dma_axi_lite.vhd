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
use vunit_lib.com_pkg.net;
use vunit_lib.integer_array_pkg.all;
use vunit_lib.memory_pkg.all;
use vunit_lib.queue_pkg.all;
use vunit_lib.random_pkg.all;
use vunit_lib.run_pkg.all;

library axi;
use axi.axi_pkg.all;

library axi_lite;
use axi_lite.axi_lite_pkg.all;

library bfm;
use bfm.stall_bfm_pkg.all;

use work.simple_dma_sim_pkg.all;


entity tb_simple_dma_axi_lite is
  generic (
    seed : natural;
    buffer_size_words : positive;
    data_width : positive;
    runner_cfg : string
  );
end entity;

architecture tb of tb_simple_dma_axi_lite is

  -- ---------------------------------------------------------------------------
  -- Generics
  constant address_width : positive := 32;

  -- ---------------------------------------------------------------------------
  -- DUT connections
  constant clk_period : time := 10 ns;
  signal clk : std_ulogic := '0';

  signal stream_ready, stream_valid : std_ulogic := '0';
  signal stream_data : std_ulogic_vector(data_width - 1 downto 0) := (others => '0');

  signal axi_m2s : axi_write_m2s_t := axi_write_m2s_init;
  signal axi_s2m : axi_write_s2m_t := axi_write_s2m_init;

  signal regs_m2s : axi_lite_m2s_t := axi_lite_m2s_init;
  signal regs_s2m : axi_lite_s2m_t := axi_lite_s2m_init;

  -- ---------------------------------------------------------------------------
  -- Testbench stuff
  constant memory : memory_t := new_memory;
  constant axi_slave : axi_slave_t := new_axi_slave(
    address_fifo_depth => 4,
    memory => memory,
    address_stall_probability => 0.5,
    data_stall_probability => 0.5,
    write_response_stall_probability => 0.5,
    min_response_latency => clk_period,
    max_response_latency => 10 * clk_period
  );

  constant stall_config : stall_configuration_t := (
    stall_probability => 0.5,
    min_stall_cycles => 1,
    max_stall_cycles => 10
  );

  constant stream_data_queue : queue_t := new_queue;

begin

  test_runner_watchdog(runner, 1 ms);
  clk <= not clk after 10 ns;


  ------------------------------------------------------------------------------
  main : process
    constant buffer_size_bytes : positive := buffer_size_words * (data_width / 8);
    -- Make it roll around many times.
    constant test_data_num_bytes : positive := 10 * buffer_size_bytes;

    variable rnd : RandomPType;

    procedure run_test is
      variable data, data_copy : integer_array_t := null_integer_array;
    begin
      random_integer_array(
        rnd => rnd,
        integer_array => data,
        width => test_data_num_bytes,
        bits_per_word => 8,
        is_signed => false
      );
      data_copy := copy(data);
      push_ref(stream_data_queue, data_copy);

      run_simple_dma_test(
        net => net,
        reference_data => data,
        buffer_size_bytes => buffer_size_bytes,
        buffer_alignment => stream_data'length / 8,
        memory => memory
      );
    end procedure;
  begin
    test_runner_setup(runner, runner_cfg);
    rnd.InitSeed(rnd'instance_name);

    if run("test_simple_dma") then
      run_test;

    end if;

    check_expected_was_written(memory);

    test_runner_cleanup(runner);
  end process;


  ------------------------------------------------------------------------------
  axi_stream_master_inst : entity bfm.axi_stream_master
    generic map (
      data_width => stream_data'length,
      data_queue => stream_data_queue,
      stall_config => stall_config,
      seed => seed,
      logger_name_suffix => " - stream"
    )
    port map (
      clk => clk,
      --
      ready => stream_ready,
      valid => stream_valid,
      data => stream_data
    );


  ------------------------------------------------------------------------------
  axi_lite_master_inst : entity bfm.axi_lite_master
    port map (
      clk => clk,
      --
      axi_lite_m2s => regs_m2s,
      axi_lite_s2m => regs_s2m
    );


  ------------------------------------------------------------------------------
  axi_slave_inst : entity bfm.axi_write_slave
    generic map (
      axi_slave => axi_slave,
      data_width => data_width,
      id_width => 0
    )
    port map (
      clk => clk,
      --
      axi_write_m2s => axi_m2s,
      axi_write_s2m => axi_s2m
    );


  ------------------------------------------------------------------------------
  dut : entity work.simple_dma_axi_lite
    generic map (
      address_width => address_width,
      stream_data_width => data_width,
      axi_data_width => data_width,
      burst_length_beats => 1
    )
    port map (
      clk => clk,
      --
      stream_ready => stream_ready,
      stream_valid => stream_valid,
      stream_data => stream_data,
      --
      regs_m2s => regs_m2s,
      regs_s2m => regs_s2m,
      --
      axi_write_m2s => axi_m2s,
      axi_write_s2m => axi_s2m
    );

end architecture;
