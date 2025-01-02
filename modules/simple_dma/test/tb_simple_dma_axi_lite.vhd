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
    runner_cfg : string
  );
end entity;

architecture tb of tb_simple_dma_axi_lite is

  -- ---------------------------------------------------------------------------
  -- Generic constants.
  shared variable rnd : RandomPType;
  impure function initialize_and_get_address_width return positive is
  begin
    rnd.InitSeed(seed);
    return rnd.Uniform(25, 32);
  end function;
  constant address_width : positive := initialize_and_get_address_width;

  impure function get_stream_data_width return positive is
  begin
    -- Between 8 and 128 bits.
    return 8 * 2 ** rnd.Uniform(0, 4);
  end function;
  constant stream_data_width : positive := get_stream_data_width;
  constant stream_bytes_per_beat : positive := stream_data_width / 8;

  -- Only same width supported at the moment.
  constant axi_data_width : positive := stream_data_width;
  constant axi_bytes_per_beat : positive := axi_data_width / 8;

  -- Only one beat supported at the moment.
  constant packet_length_beats : positive := 1;
  constant packet_length_bytes : positive := packet_length_beats * stream_bytes_per_beat;
  constant packet_length_axi_beats : positive := packet_length_bytes / axi_bytes_per_beat;

  impure function get_enable_axi3 return boolean is
  begin
    return rnd.RandBool;
  end function;
  constant enable_axi3 : boolean := get_enable_axi3;

  -- ---------------------------------------------------------------------------
  -- DUT connections.
  constant clk_period : time := 10 ns;
  signal clk : std_ulogic := '0';

  signal stream_ready, stream_valid : std_ulogic := '0';
  signal stream_data : std_ulogic_vector(stream_data_width - 1 downto 0) := (others => '0');

  signal axi_m2s : axi_write_m2s_t := axi_write_m2s_init;
  signal axi_s2m : axi_write_s2m_t := axi_write_s2m_init;

  signal regs_m2s : axi_lite_m2s_t := axi_lite_m2s_init;
  signal regs_s2m : axi_lite_s2m_t := axi_lite_s2m_init;

  -- ---------------------------------------------------------------------------
  -- Testbench stuff.
  constant memory : memory_t := new_memory;
  constant axi_slave : axi_slave_t := new_axi_slave(
    address_fifo_depth => 4,
    memory => memory,
    address_stall_probability => 0.8,
    data_stall_probability => 0.5,
    write_response_stall_probability => 0.5,
    min_response_latency => clk_period,
    max_response_latency => 20 * clk_period
  );

  constant stall_config : stall_configuration_t := (
    stall_probability => 0.2,
    min_stall_cycles => 1,
    max_stall_cycles => 4
  );

  impure function get_w_fifo_depth return natural is
  begin
    -- Optionally test in a configuration where AXI write slave accepts data before address.
    return rnd.Uniform(0, 1) * 4 * packet_length_axi_beats;
  end function;
  constant w_fifo_depth : natural := get_w_fifo_depth;

  constant stream_data_queue : queue_t := new_queue;

begin

  test_runner_watchdog(runner, 1 ms);
  clk <= not clk after 10 ns;


  ------------------------------------------------------------------------------
  main : process
    constant buffer_size_axi_beats : positive := rnd.FavorSmall(4, 16);
    constant buffer_size_bytes : positive := buffer_size_axi_beats * axi_bytes_per_beat;

    -- Make it roll around many times.
    constant test_data_num_bytes : positive := 10 * buffer_size_bytes;

    procedure run_test is
      variable data, data_copy : integer_array_t := null_integer_array;
    begin
      report "buffer_size_axi_beats = " & to_string(buffer_size_axi_beats);

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
        rnd => rnd,
        net => net,
        reference_data => data,
        buffer_size_bytes => buffer_size_bytes,
        buffer_alignment => axi_bytes_per_beat,
        memory => memory
      );
    end procedure;
  begin
    test_runner_setup(runner, runner_cfg);

    report "address_width = " & to_string(address_width);
    report "stream_data_width = " & to_string(stream_data_width);
    report "axi_data_width = " & to_string(axi_data_width);
    report "packet_length_beats = " & to_string(packet_length_beats);
    report "enable_axi3 = " & to_string(enable_axi3);
    report "w_fifo_depth = " & to_string(w_fifo_depth);

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
      data_width => axi_data_width,
      id_width => 0,
      w_fifo_depth => w_fifo_depth,
      enable_axi3 => enable_axi3
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
      stream_data_width => stream_data_width,
      axi_data_width => axi_data_width,
      packet_length_beats => packet_length_beats,
      enable_axi3 => enable_axi3
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
