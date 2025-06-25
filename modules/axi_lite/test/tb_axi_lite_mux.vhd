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
use vunit_lib.check_pkg.all;
use vunit_lib.com_pkg.net;
use vunit_lib.memory_pkg.all;
use vunit_lib.run_pkg.all;
use vunit_lib.sync_pkg.all;

library axi;
use axi.axi_pkg.all;

library bfm;
use bfm.axi_lite_bfm_pkg.all;
use bfm.axi_slave_bfm_pkg.all;
use bfm.memory_bfm_pkg.all;

library common;
use common.addr_pkg.all;

library register_file;
use register_file.register_operations_pkg.register_bus_master;

use work.axi_lite_pkg.all;


entity tb_axi_lite_mux is
  generic (
    runner_cfg : string
  );
end entity;

architecture tb of tb_axi_lite_mux is

  constant data_width : integer := 32;
  constant bytes_per_word : integer := data_width / 8;

  constant num_base_addresses : integer := 19;
  subtype base_address_range is integer range 0 to num_base_addresses - 1;

  constant num_words : integer := 32;

  constant base_addresses : addr_vec_t(base_address_range) := (
    x"0000_1000",
    x"0000_2000",
    x"0000_3000",
    x"0000_4000",
    x"0000_5000",
    x"0000_6000",
    x"0000_7000",
    x"0000_8000",
    x"0000_9000",
    x"0000_A000",
    x"0000_B000",
    x"0000_C000",
    x"0000_D000",
    x"0000_E000",
    x"0000_F000",
    x"0001_0000",
    x"0002_0200",
    x"0002_0100",
    x"0002_0300"
  );

  constant clk_period : time := 10 ns;
  signal clk : std_ulogic := '0';

  signal axi_lite_m2s : axi_lite_m2s_t;
  signal axi_lite_s2m : axi_lite_s2m_t;

  signal axi_lite_m2s_vec : axi_lite_m2s_vec_t(base_address_range);
  signal axi_lite_s2m_vec : axi_lite_s2m_vec_t(base_address_range);

  constant memory : memory_vec_t(base_address_range) := get_new_memories(num_base_addresses);

  constant axi_read_slave, axi_write_slave : axi_slave_vec_t(base_address_range) := (
    new_axi_slave(address_fifo_depth => 1, memory => memory(0)),
    new_axi_slave(address_fifo_depth => 1, memory => memory(1)),
    new_axi_slave(address_fifo_depth => 1, memory => memory(2)),
    new_axi_slave(address_fifo_depth => 1, memory => memory(3)),
    new_axi_slave(address_fifo_depth => 1, memory => memory(4)),
    new_axi_slave(address_fifo_depth => 1, memory => memory(5)),
    new_axi_slave(address_fifo_depth => 1, memory => memory(6)),
    new_axi_slave(address_fifo_depth => 1, memory => memory(7)),
    new_axi_slave(address_fifo_depth => 1, memory => memory(8)),
    new_axi_slave(address_fifo_depth => 1, memory => memory(9)),
    new_axi_slave(address_fifo_depth => 1, memory => memory(10)),
    new_axi_slave(address_fifo_depth => 1, memory => memory(11)),
    new_axi_slave(address_fifo_depth => 1, memory => memory(12)),
    new_axi_slave(address_fifo_depth => 1, memory => memory(13)),
    new_axi_slave(address_fifo_depth => 1, memory => memory(14)),
    new_axi_slave(address_fifo_depth => 1, memory => memory(15)),
    new_axi_slave(address_fifo_depth => 1, memory => memory(16)),
    new_axi_slave(address_fifo_depth => 1, memory => memory(17)),
    new_axi_slave(address_fifo_depth => 1, memory => memory(18))
  );

begin

  test_runner_watchdog(runner, 2 ms);
  clk <= not clk after clk_period / 2;


  ------------------------------------------------------------------------------
  main : process

    function bank_address(slave_index, word_index : integer) return integer is
    begin
      return to_integer(base_addresses(slave_index)) + word_index * bytes_per_word;
    end function;

    procedure wait_for_idle is
    begin
      wait_until_idle(net, as_sync(register_bus_master));
    end procedure;

    variable rnd : RandomPType;
    variable data : std_ulogic_vector(data_width - 1 downto 0);
    variable address : integer;
    variable buf : buffer_t;

    variable hardcoded_address : u_unsigned(31 downto 0) := (others => '0');

  begin
    test_runner_setup(runner, runner_cfg);
    rnd.InitSeed(get_string_seed(runner_cfg));

    for slave_idx in memory'range loop
      buf := allocate(memory=>memory(slave_idx), num_bytes=>bank_address(slave_idx, num_words));
    end loop;

    if run("read_and_write_to_buffer") then
      for slave_idx in memory'range loop
        for word in 0 to num_words - 1 loop
          address := bank_address(slave_idx, word);
          data := rnd.RandSLV(data'length);
          set_expected_word(memory(slave_idx), address, data);

          write_bfm(net=>net, address=>to_unsigned(address, addr_width), data=>data);
        end loop;
      end loop;
      wait_for_idle;

      -- Test that everything was written correctly to memory
      for slave_idx in memory'range loop
        check_expected_was_written(memory(slave_idx));
      end loop;

      -- Test reading back data
      for slave_idx in memory'range loop
        for word in 0 to num_words - 1 loop
          address := bank_address(slave_idx, word);
          data := read_word(memory(slave_idx), address, 4);

          check_bfm(net=>net, address=>to_unsigned(address, addr_width), data=>data);
        end loop;
      end loop;

    elsif run("read_from_non_existent_slave_base_address") then
      hardcoded_address := x"0000_0000";
      check_bfm(
        net=>net, address=>hardcoded_address, data=>data, response=>axi_resp_decerr
      );

      data := rnd.RandSLV(data'length);
      write_word(memory(0), bank_address(slave_index=>0, word_index=>0), data);
      check_bfm(net=>net, address=>base_addresses(0), data=>data);

      hardcoded_address := x"4F00_0000";
      check_bfm(
        net=>net, address=>hardcoded_address, data=>data, response=>axi_resp_decerr
      );

      data := rnd.RandSLV(data'length);
      write_word(memory(1), bank_address(slave_index=>1, word_index=>0), data);
      check_bfm(net=>net, address=>base_addresses(1), data=>data);

    elsif run("write_to_non_existent_slave_base_address") then
      hardcoded_address := x"0003_4000";
      write_bfm(
        net=>net,
        address=>hardcoded_address,
        data=>x"0102_0304",
        response=>axi_resp_decerr
      );

      data := rnd.RandSLV(data'length);
      set_expected_word(memory(0), bank_address(slave_index=>0, word_index=>0), data);
      write_bfm(net=>net, address=>base_addresses(0), data=>data);

      hardcoded_address := x"0003_5000";
      write_bfm(
        net=>net, address=>hardcoded_address, data=>x"0102_0304", response=>axi_resp_decerr
      );

      data := rnd.RandSLV(data'length);
      set_expected_word(memory(1), bank_address(slave_index=>1, word_index=>0), data);
      write_bfm(net=>net, address=>base_addresses(1), data=>data);
    end if;


    wait until rising_edge(clk);
    wait_for_idle;
    wait until rising_edge(clk);

    test_runner_cleanup(runner);
  end process;


  ------------------------------------------------------------------------------
  axi_lite_master_inst : entity bfm.axi_lite_master_bfm
    generic map (
      drive_invalid_value => '0'
    )
    port map (
      clk => clk,

      axi_lite_m2s => axi_lite_m2s,
      axi_lite_s2m => axi_lite_s2m
    );


  ------------------------------------------------------------------------------
  axi_lite_slave_gen : for i in axi_read_slave'range generate

    ------------------------------------------------------------------------------
    axi_lite_slave_inst : entity bfm.axi_lite_slave
      generic map (
        axi_read_slave => axi_read_slave(i),
        axi_write_slave => axi_write_slave(i),
        data_width => data_width,
        logger_name_suffix => "output #" & to_string(i)
      )
      port map (
        clk => clk,
        --
        axi_lite_read_m2s => axi_lite_m2s_vec(i).read,
        axi_lite_read_s2m => axi_lite_s2m_vec(i).read,
        --
        axi_lite_write_m2s => axi_lite_m2s_vec(i).write,
        axi_lite_write_s2m => axi_lite_s2m_vec(i).write
      );

  end generate;


  ------------------------------------------------------------------------------
  dut : entity work.axi_lite_mux
    generic map (
      base_addresses => base_addresses
    )
    port map (
      clk => clk,
      --
      axi_lite_m2s => axi_lite_m2s,
      axi_lite_s2m => axi_lite_s2m,
      --
      axi_lite_m2s_vec => axi_lite_m2s_vec,
      axi_lite_s2m_vec => axi_lite_s2m_vec
    );

end architecture;
