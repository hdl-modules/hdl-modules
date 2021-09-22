-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the tsfpga project.
-- https://tsfpga.com
-- https://gitlab.com/tsfpga/tsfpga
-- -------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
context vunit_lib.vunit_context;
context vunit_lib.vc_context;

library osvvm;
use osvvm.RandomPkg.all;

library axi;
use axi.axi_pkg.all;
use axi.axi_lite_pkg.all;

library bfm;


entity tb_axi_simple_crossbar is
  generic(
    runner_cfg : string;
    test_axi_lite : boolean
  );
end entity;

architecture tb of tb_axi_simple_crossbar is

  constant num_inputs : integer := 4;
  constant clk_period : time := 5 ns;

  signal clk : std_logic := '0';

  constant axi_port_data_width : integer := 32;
  type bus_master_vec_t is array (integer range <>) of bus_master_t;
  constant input_masters : bus_master_vec_t(0 to 4 - 1) := (
    0 => new_bus(data_length => axi_port_data_width, address_length => axi_a_addr_sz),
    1 => new_bus(data_length => axi_port_data_width, address_length => axi_a_addr_sz),
    2 => new_bus(data_length => axi_port_data_width, address_length => axi_a_addr_sz),
    3 => new_bus(data_length => axi_port_data_width, address_length => axi_a_addr_sz)
  );

  constant memory : memory_t := new_memory;
  constant axi_read_slave, axi_write_slave : axi_slave_t := new_axi_slave(
    memory => memory,
    address_fifo_depth => 8,
    write_response_fifo_depth => 8,
    address_stall_probability => 0.3,
    data_stall_probability => 0.3,
    write_response_stall_probability => 0.3,
    min_response_latency => 12 * clk_period,
    max_response_latency => 20 * clk_period,
    logger => get_logger("axi_rd_slave")
  );

begin

  clk <= not clk after clk_period / 2;
  test_runner_watchdog(runner, 1 ms);


  ------------------------------------------------------------------------------
  main : process
    constant num_words : integer := 1000;
    constant bytes_per_word : integer := axi_port_data_width / 8;
    variable got, expected : std_logic_vector(axi_port_data_width - 1 downto 0);
    variable address : integer;
    variable buf : buffer_t;
    variable rnd : RandomPType;

    variable input_select : integer;
    variable bus_reference : bus_reference_t;

    variable bus_reference_queue : queue_t := new_queue;
  begin
    test_runner_setup(runner, runner_cfg);
    rnd.InitSeed(rnd'instance_name);

    buf := allocate(memory, num_words * bytes_per_word);

    if run("read_random_data_from_random_input_master") then
      -- Set random data in read memory
      for idx in 0 to num_words - 1 loop
        address := idx * bytes_per_word;
        expected := rnd.RandSlv(expected'length);
        write_word(memory, address, expected);
      end loop;

      -- Queue up reads from random input master
      for idx in 0 to num_words - 1 loop
        input_select := rnd.RandInt(0, input_masters'high);
        read_bus(net, input_masters(input_select), address, bus_reference);
        push(bus_reference_queue, bus_reference);
      end loop;

      -- Verify read data
      for idx in 0 to num_words - 1 loop
        expected := read_word(memory, address, bytes_per_word);
        bus_reference := pop(bus_reference_queue);
        await_read_bus_reply(net, bus_reference, got);
        check_equal(got, expected, "idx=" & to_string(idx));
      end loop;

      assert is_empty(bus_reference_queue);

    elsif run("write_random_data_from_random_input_master") then
      -- Set expected random data and queue up write
      for idx in 0 to num_words - 1 loop
        address := idx * bytes_per_word;
        expected := rnd.RandSlv(expected'length);
        set_expected_word(memory, address, expected);

        input_select := rnd.RandInt(0, input_masters'high);
        write_bus(net, input_masters(input_select), address, expected);
      end loop;

      -- Wait until all writes are completed
      wait for 300 us;
      check_expected_was_written(memory);
    end if;

    test_runner_cleanup(runner);
  end process;


  ------------------------------------------------------------------------------
  bfm_generate : if test_axi_lite generate
    signal inputs_read_m2s : axi_lite_read_m2s_vec_t(0 to num_inputs - 1) := (others => axi_lite_read_m2s_init);
    signal inputs_read_s2m : axi_lite_read_s2m_vec_t(inputs_read_m2s'range) := (others => axi_lite_read_s2m_init);

    signal inputs_write_m2s : axi_lite_write_m2s_vec_t(0 to num_inputs - 1) := (others => axi_lite_write_m2s_init);
    signal inputs_write_s2m : axi_lite_write_s2m_vec_t(inputs_read_m2s'range) := (others => axi_lite_write_s2m_init);

    signal output_m2s : axi_lite_m2s_t := axi_lite_m2s_init;
    signal output_s2m : axi_lite_s2m_t := axi_lite_s2m_init;
  begin

    ------------------------------------------------------------------------------
    input_masters_gen : for idx in inputs_read_m2s'range generate
    begin
      axi_lite_master_inst : entity bfm.axi_lite_master
        generic map (
          bus_handle => input_masters(idx)
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
    axi_slave_inst : entity bfm.axi_lite_slave
      generic map (
        axi_read_slave => axi_read_slave,
        axi_write_slave => axi_write_slave,
        data_width => axi_port_data_width
      )
      port map (
        clk => clk,
        --
        axi_lite_write_m2s => output_m2s.write,
        axi_lite_write_s2m => output_s2m.write,
        --
        axi_lite_read_m2s => output_m2s.read,
        axi_lite_read_s2m => output_s2m.read
      );


    ------------------------------------------------------------------------------
    dut_read : entity work.axi_lite_simple_read_crossbar
      generic map(
        num_inputs => num_inputs
      )
      port map(
        clk => clk,
        --
        input_ports_m2s => inputs_read_m2s,
        input_ports_s2m => inputs_read_s2m,
        --
        output_m2s => output_m2s.read,
        output_s2m => output_s2m.read
      );

    ------------------------------------------------------------------------------
    dut_write : entity work.axi_lite_simple_write_crossbar
      generic map(
        num_inputs => num_inputs
      )
      port map(
        clk => clk,
        --
        input_ports_m2s => inputs_write_m2s,
        input_ports_s2m => inputs_write_s2m,
        --
        output_m2s => output_m2s.write,
        output_s2m => output_s2m.write
      );

  else generate
    signal inputs_read_m2s : axi_read_m2s_vec_t(0 to num_inputs - 1) := (others => axi_read_m2s_init);
    signal inputs_read_s2m : axi_read_s2m_vec_t(inputs_read_m2s'range) := (others => axi_read_s2m_init);

    signal inputs_write_m2s : axi_write_m2s_vec_t(0 to num_inputs - 1) := (others => axi_write_m2s_init);
    signal inputs_write_s2m : axi_write_s2m_vec_t(inputs_read_m2s'range) := (others => axi_write_s2m_init);

    signal output_m2s : axi_m2s_t := axi_m2s_init;
    signal output_s2m : axi_s2m_t := axi_s2m_init;
  begin

    ------------------------------------------------------------------------------
    input_masters_gen : for idx in inputs_read_m2s'range generate
    begin
      axi_master_inst : entity bfm.axi_master
        generic map (
          bus_handle => input_masters(idx)
        )
        port map (
          clk => clk,
          --
          axi_read_m2s => inputs_read_m2s(idx),
          axi_read_s2m => inputs_read_s2m(idx),
          --
          axi_write_m2s => inputs_write_m2s(idx),
          axi_write_s2m => inputs_write_s2m(idx)
        );
    end generate;

    ------------------------------------------------------------------------------
    axi_slave_inst : entity bfm.axi_slave
      generic map (
        axi_read_slave => axi_read_slave,
        axi_write_slave => axi_write_slave,
        data_width => axi_port_data_width
      )
      port map (
        clk => clk,
        --
        axi_read_m2s => output_m2s.read,
        axi_read_s2m => output_s2m.read,
        --
        axi_write_m2s => output_m2s.write,
        axi_write_s2m => output_s2m.write
      );


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
        output_m2s => output_m2s.read,
        output_s2m => output_s2m.read
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
        output_m2s => output_m2s.write,
        output_s2m => output_s2m.write
      );

  end generate;

end architecture;
