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
use vunit_lib.bus_master_pkg.all;
use vunit_lib.com_pkg.net;
use vunit_lib.logger_pkg.all;
use vunit_lib.memory_pkg.all;
use vunit_lib.run_pkg.all;

library axi_lite;
use axi_lite.axi_lite_pkg.all;

library bfm;
use bfm.axi_lite_bfm_pkg.all;


entity tb_axi_lite_simple_crossbar is
  generic(
    runner_cfg : string
  );
end entity;

architecture tb of tb_axi_lite_simple_crossbar is

  -- Generic constants.
  constant num_inputs : positive := 4;
  constant data_width : positive := 32;

  -- DUT connections.
  constant clk_period : time := 5 ns;
  signal clk : std_ulogic := '0';

  signal inputs_read_m2s : axi_lite_read_m2s_vec_t(num_inputs - 1 downto 0) := (
    others => axi_lite_read_m2s_init
  );
  signal inputs_read_s2m : axi_lite_read_s2m_vec_t(inputs_read_m2s'range) := (
    others => axi_lite_read_s2m_init
  );

  signal inputs_write_m2s : axi_lite_write_m2s_vec_t(inputs_read_m2s'range) := (
    others => axi_lite_write_m2s_init
  );
  signal inputs_write_s2m : axi_lite_write_s2m_vec_t(inputs_read_m2s'range) := (
    others => axi_lite_write_s2m_init
  );

  signal output_read_m2s : axi_lite_read_m2s_t := axi_lite_read_m2s_init;
  signal output_read_s2m : axi_lite_read_s2m_t := axi_lite_read_s2m_init;

  signal output_write_m2s : axi_lite_write_m2s_t := axi_lite_write_m2s_init;
  signal output_write_s2m : axi_lite_write_s2m_t := axi_lite_write_s2m_init;

  -- Testbench stuff.
  type bus_master_vec_t is array (integer range <>) of bus_master_t;
  constant input_masters : bus_master_vec_t(inputs_read_m2s'range) := (
    0 => new_bus(data_length => data_width, address_length => 32),
    1 => new_bus(data_length => data_width, address_length => 32),
    2 => new_bus(data_length => data_width, address_length => 32),
    3 => new_bus(data_length => data_width, address_length => 32)
  );

  constant memory : memory_t := new_memory;

begin

  clk <= not clk after clk_period / 2;
  test_runner_watchdog(runner, 1 ms);


  ------------------------------------------------------------------------------
  main : process
    constant num_words : positive := 2;
    constant bytes_per_word : positive := data_width / 8;

    variable expected : std_ulogic_vector(data_width - 1 downto 0) := (others => '0');
    variable address : natural := 0;
    variable buf : buffer_t := null_buffer;
    variable rnd : RandomPType;

    variable input_select : natural := 0;
  begin
    test_runner_setup(runner, runner_cfg);
    rnd.InitSeed(get_string_seed(runner_cfg));

    buf := allocate(memory, num_words * bytes_per_word);

    if run("test_random_read") then
      -- Set random data in read memory
      for index in 0 to num_words - 1 loop
        address := bytes_per_word * index;
        expected := rnd.RandSlv(expected'length);
        write_word(memory=>memory, address=>address, word=>expected);

        input_select := rnd.Uniform(0, input_masters'high);
        check_bfm(net=>net, bus_handle=>input_masters(input_select), index=>index, data=>expected);
      end loop;

    elsif run("test_random_write") then
      for index in 0 to num_words - 1 loop
        address := index * bytes_per_word;
        expected := rnd.RandSlv(expected'length);
        set_expected_word(memory=>memory, address=>address, expected=>expected);

        input_select := rnd.Uniform(0, input_masters'high);
        write_bfm(net=>net, bus_handle=>input_masters(input_select), index=>index, data=>expected);
      end loop;
    end if;

    for handle_idx in input_masters'range loop
      wait_until_bfm_idle(net=>net, bus_handle=>input_masters(handle_idx));
    end loop;

    check_expected_was_written(memory);

    test_runner_cleanup(runner);
  end process;


  ------------------------------------------------------------------------------
  input_masters_gen : for idx in inputs_read_m2s'range generate

    ------------------------------------------------------------------------------
    axi_lite_master_inst : entity bfm.axi_lite_master_bfm
      generic map (
        bus_handle => input_masters(idx),
        logger_name_suffix => " - input " & to_string(idx),
        drive_invalid_value => '0'
      )
      port map (
        clk => clk,
        --
        axi_lite_m2s.read => inputs_read_m2s(idx),
        axi_lite_m2s.write => inputs_write_m2s(idx),
        axi_lite_s2m.read => inputs_read_s2m(idx),
        axi_lite_s2m.write => inputs_write_s2m(idx)
      );

  end generate;


  ------------------------------------------------------------------------------
  axi_lite_slave_block : block
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
    axi_lite_slave_inst : entity bfm.axi_lite_slave
      generic map (
        axi_read_slave => axi_read_slave,
        axi_write_slave => axi_write_slave,
        data_width => data_width
      )
      port map (
        clk => clk,
        --
        axi_lite_write_m2s => output_write_m2s,
        axi_lite_write_s2m => output_write_s2m,
        --
        axi_lite_read_m2s => output_read_m2s,
        axi_lite_read_s2m => output_read_s2m
      );

  end block;


  ------------------------------------------------------------------------------
  dut_read : entity axi_lite.axi_lite_simple_read_crossbar
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
  dut_write : entity axi_lite.axi_lite_simple_write_crossbar
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
