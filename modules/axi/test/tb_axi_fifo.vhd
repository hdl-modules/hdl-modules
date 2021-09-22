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
use vunit_lib.memory_pkg.all;
context vunit_lib.vunit_context;
context vunit_lib.vc_context;

library osvvm;
use osvvm.RandomPkg.all;

library bfm;

use work.axi_pkg.all;


entity tb_axi_fifo is
  generic (
    depth : natural;
    asynchronous : boolean := false;
    runner_cfg : string
  );
end entity;

architecture tb of tb_axi_fifo is

  constant data_width : integer := 32;
  constant id_width : integer := 5;
  constant num_words : integer := 1000;

  constant clk_fast_period : time := 3 ns;
  constant clk_slow_period : time := 7 ns;

  signal clk_input, clk_output : std_logic := '0';

  signal input_read_m2s, output_read_m2s : axi_read_m2s_t := axi_read_m2s_init;
  signal input_read_s2m, output_read_s2m : axi_read_s2m_t := axi_read_s2m_init;
  signal input_write_m2s, output_write_m2s : axi_write_m2s_t := axi_write_m2s_init;
  signal input_write_s2m, output_write_s2m : axi_write_s2m_t := axi_write_s2m_init;

  constant axi_master : bus_master_t := new_bus(
    data_length => data_width,
    address_length => input_read_m2s.ar.addr'length
  );

  constant memory : memory_t := new_memory;
  constant axi_read_slave, axi_write_slave : axi_slave_t := new_axi_slave(
    memory => memory,
    address_fifo_depth => 4,
    write_response_fifo_depth => 4,
    address_stall_probability => 0.3,
    data_stall_probability => 0.3,
    write_response_stall_probability => 0.3,
    min_response_latency => 8 * clk_fast_period,
    max_response_latency => 16 * clk_slow_period,
    logger => get_logger("axi_slave")
  );

begin

  test_runner_watchdog(runner, 1 ms);

  clk_input_gen : if asynchronous generate
    clk_input <= not clk_input after clk_fast_period / 2;
    clk_output <= not clk_output after clk_slow_period / 2;
  else generate
    clk_input <= not clk_input after clk_fast_period / 2;
    clk_output <= not clk_output after clk_fast_period / 2;
  end generate;

  ------------------------------------------------------------------------------
  main : process
    variable rnd : RandomPType;
    variable data : std_logic_vector(data_width - 1 downto 0);
    variable address : integer;
    variable buf : buffer_t;
  begin
    test_runner_setup(runner, runner_cfg);
    rnd.InitSeed(rnd'instance_name);

    buf := allocate(memory, 4 * num_words);

    if run("test_read") then
      for idx in 0 to num_words - 1 loop
        address := 4 * idx;
        data := rnd.RandSlv(data'length);
        write_word(memory, address, data);

        check_bus(net, axi_master, address, data);
      end loop;

    elsif run("test_write") then
      for idx in 0 to num_words - 1 loop
        address := 4 * idx;
        data := rnd.RandSlv(data'length);
        set_expected_word(memory, address, data);

        write_bus(net, axi_master, address, data);
      end loop;

      wait_until_idle(net, as_sync(axi_master));
      check_expected_was_written(memory);
    end if;

    test_runner_cleanup(runner);
  end process;


  ------------------------------------------------------------------------------
  axi_input_inst : entity bfm.axi_master
    generic map (
      bus_handle => axi_master
    )
    port map (
      clk => clk_input,
      --
      axi_read_m2s => input_read_m2s,
      axi_read_s2m => input_read_s2m,
      --
      axi_write_m2s => input_write_m2s,
      axi_write_s2m => input_write_s2m
    );


  ------------------------------------------------------------------------------
  axi_output_inst : entity bfm.axi_slave
  generic map (
    axi_read_slave => axi_read_slave,
    axi_write_slave => axi_write_slave,
    data_width => data_width,
    id_width => id_width
  )
  port map (
    clk => clk_output,
    --
    axi_read_m2s => output_read_m2s,
    axi_read_s2m => output_read_s2m,
    --
    axi_write_m2s => output_write_m2s,
    axi_write_s2m => output_write_s2m
  );


  ------------------------------------------------------------------------------
  axi_ar_fifo_inst : entity work.axi_address_fifo
    generic map (
      id_width => id_width,
      addr_width => 32,
      asynchronous => asynchronous,
      depth => depth
    )
    port map (
      clk => clk_output,
      --
      input_m2s => input_read_m2s.ar,
      input_s2m => input_read_s2m.ar,
      --
      output_m2s => output_read_m2s.ar,
      output_s2m => output_read_s2m.ar,
      --
      clk_input => clk_input
    );


  ------------------------------------------------------------------------------
  axi_r_fifo_inst : entity work.axi_r_fifo
    generic map (
      id_width => id_width,
      data_width => data_width,
      asynchronous => asynchronous,
      depth => depth
    )
    port map (
      clk => clk_output,
      --
      input_m2s => input_read_m2s.r,
      input_s2m => input_read_s2m.r,
      --
      output_m2s => output_read_m2s.r,
      output_s2m => output_read_s2m.r,
      --
      clk_input => clk_input
    );


  ------------------------------------------------------------------------------
  axi_aw_fifo_inst : entity work.axi_address_fifo
    generic map (
      id_width => id_width,
      addr_width => 32,
      asynchronous => asynchronous,
      depth => depth
    )
    port map (
      clk => clk_output,
      --
      input_m2s => input_write_m2s.aw,
      input_s2m => input_write_s2m.aw,
      --
      output_m2s => output_write_m2s.aw,
      output_s2m => output_write_s2m.aw,
      --
      clk_input => clk_input
    );


  ------------------------------------------------------------------------------
  axi_w_fifo_inst : entity work.axi_w_fifo
    generic map (
      data_width => data_width,
      asynchronous => asynchronous,
      depth => depth
    )
    port map (
      clk => clk_output,
      --
      input_m2s => input_write_m2s.w,
      input_s2m => input_write_s2m.w,
      --
      output_m2s => output_write_m2s.w,
      output_s2m => output_write_s2m.w,
      --
      clk_input => clk_input
    );


  ------------------------------------------------------------------------------
  axi_b_fifo_inst : entity work.axi_b_fifo
    generic map (
      id_width => id_width,
      asynchronous => asynchronous,
      depth => depth
    )
    port map (
      clk => clk_output,
      --
      input_m2s => input_write_m2s.b,
      input_s2m => input_write_s2m.b,
      --
      output_m2s => output_write_m2s.b,
      output_s2m => output_write_s2m.b,
      --
      clk_input => clk_input
    );

end architecture;
