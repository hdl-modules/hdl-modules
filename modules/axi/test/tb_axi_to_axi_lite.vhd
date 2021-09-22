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
use work.axi_lite_pkg.all;


entity tb_axi_to_axi_lite is
  generic (
    data_width : integer;
    runner_cfg : string
  );
end entity;

architecture tb of tb_axi_to_axi_lite is
  signal clk : std_logic := '0';
  constant clk_period : time := 10 ns;

  signal axi_m2s : axi_m2s_t;
  signal axi_s2m : axi_s2m_t;

  signal axi_lite_m2s : axi_lite_m2s_t;
  signal axi_lite_s2m : axi_lite_s2m_t := axi_lite_s2m_init;

  constant memory : memory_t := new_memory;
  constant axi_read_slave, axi_write_slave : axi_slave_t := new_axi_slave(
    memory => memory,
    address_fifo_depth => 8,
    write_response_fifo_depth => 8,
    address_stall_probability => 0.3,
    data_stall_probability => 0.3,
    write_response_stall_probability => 0.3,
    min_response_latency => 8 * clk_period,
    max_response_latency => 16 * clk_period,
    logger => get_logger("axi_slave")
  );
  constant axi_master : bus_master_t := new_bus(
    data_length => data_width,
    address_length => axi_m2s.read.ar.addr'length
  );

begin

  test_runner_watchdog(runner, 10 ms);
  clk <= not clk after clk_period / 2;


  ------------------------------------------------------------------------------
  main : process
    variable rnd : RandomPType;
    variable data, got : std_logic_vector(data_width - 1 downto 0);
    constant num_words : integer := 1000;
    constant bytes_per_word : integer := data_width / 8;
    variable address : integer;
    variable buf : buffer_t;
  begin
    test_runner_setup(runner, runner_cfg);
    rnd.InitSeed(rnd'instance_name);
    buf := allocate(memory, num_words * bytes_per_word);

    if run("read_write_data") then
      for i in 0 to num_words - 1 loop
        address := i * bytes_per_word;
        data := rnd.RandSLV(data'length);
        set_expected_word(memory, address, data);
        write_bus(net, axi_master, address, data);
        read_bus(net, axi_master, address, got);
        check_equal(got, data);
      end loop;
    end if;

    check_expected_was_written(memory);
    test_runner_cleanup(runner);
  end process;


  ------------------------------------------------------------------------------
  axi_master_inst : entity bfm.axi_master
    generic map (
      bus_handle => axi_master
    )
    port map (
      clk => clk,

      axi_read_m2s => axi_m2s.read,
      axi_read_s2m => axi_s2m.read,

      axi_write_m2s => axi_m2s.write,
      axi_write_s2m => axi_s2m.write
    );


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
      axi_lite_read_m2s => axi_lite_m2s.read,
      axi_lite_read_s2m => axi_lite_s2m.read,
      --
      axi_lite_write_m2s => axi_lite_m2s.write,
      axi_lite_write_s2m => axi_lite_s2m.write
    );


  ------------------------------------------------------------------------------
  dut : entity work.axi_to_axi_lite
    generic map (
      data_width => data_width
    )
    port map (
      clk => clk,

      axi_m2s => axi_m2s,
      axi_s2m => axi_s2m,

      axi_lite_m2s => axi_lite_m2s,
      axi_lite_s2m => axi_lite_s2m
    );

end architecture;
