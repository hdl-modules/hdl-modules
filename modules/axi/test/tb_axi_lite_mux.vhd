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
use bfm.bfm_pkg.all;

library common;
use common.addr_pkg.all;

use work.axi_lite_pkg.all;


entity tb_axi_lite_mux is
  generic (
    use_axi_lite_bfm : boolean := true;
    runner_cfg : string
  );
end entity;

architecture tb of tb_axi_lite_mux is

  constant data_width : integer := 32;
  constant bytes_per_word : integer := data_width / 8;
  constant num_slaves : integer := 4;
  subtype slaves_rng is integer range 0 to num_slaves - 1;

  constant num_words : integer := 32;
  constant addr_offset : integer := 4096; -- Corresponding to the base addresses below

  constant slave_addrs : addr_and_mask_vec_t(slaves_rng) := (
    (addr => x"0000_0000", mask => x"0000_7000"),
    (addr => x"0000_1000", mask => x"0000_7000"),
    (addr => x"0000_2000", mask => x"0000_7000"),
    (addr => x"0000_3000", mask => x"0000_7000")
  );

  constant clk_period : time := 10 ns;
  signal clk : std_logic := '0';

  signal axi_lite_m2s, hard_coded_m2s : axi_lite_m2s_t;
  signal axi_lite_s2m : axi_lite_s2m_t;

  signal axi_lite_m2s_vec : axi_lite_m2s_vec_t(slaves_rng);
  signal axi_lite_s2m_vec : axi_lite_s2m_vec_t(slaves_rng);

  constant axi_master : bus_master_t := new_bus(data_length => data_width, address_length => axi_lite_m2s.read.ar.addr'length);

  constant memory : memory_vec_t(slaves_rng) := get_new_memories(num_slaves);

  constant axi_read_slave, axi_write_slave : axi_slave_vec_t(slaves_rng) := (
    0 => new_axi_slave(address_fifo_depth => 1, memory => memory(0)),
    1 => new_axi_slave(address_fifo_depth => 1, memory => memory(1)),
    2 => new_axi_slave(address_fifo_depth => 1, memory => memory(2)),
    3 => new_axi_slave(address_fifo_depth => 1, memory => memory(3))
  );

begin

  test_runner_watchdog(runner, 2 ms);
  clk <= not clk after clk_period / 2;


  ------------------------------------------------------------------------------
  main : process

  function bank_address(slave, word : integer) return integer is
    begin
      return slave * addr_offset + word * bytes_per_word;
    end function;

    procedure hard_coded_read_data(addr : in unsigned(slave_addrs(0).addr'range)) is
    begin
      hard_coded_m2s.read.ar.valid <= '1';
      hard_coded_m2s.read.ar.addr <= x"0000_0000" & addr;
      wait until (axi_lite_s2m.read.ar.ready and axi_lite_m2s.read.ar.valid) = '1' and rising_edge(clk);
      hard_coded_m2s.read.ar.valid <= '0';

      hard_coded_m2s.read.r.ready <= '1';
      wait until (axi_lite_m2s.read.r.ready and axi_lite_s2m.read.r.valid) = '1' and rising_edge(clk);
      hard_coded_m2s.read.r.ready <= '0';
    end procedure;

    procedure hard_coded_write_data(addr : in unsigned(slave_addrs(0).addr'range);
                                    data : in std_logic_vector(data_width - 1 downto 0)) is
    begin
      hard_coded_m2s.write.aw.valid <= '1';
      hard_coded_m2s.write.aw.addr <= x"0000_0000" & addr;
      wait until (axi_lite_s2m.write.aw.ready and axi_lite_m2s.write.aw.valid) = '1' and rising_edge(clk);
      hard_coded_m2s.write.aw.valid <= '0';

      hard_coded_m2s.write.w.valid <= '1';
      hard_coded_m2s.write.w.data <= x"0000_0000" & data;
      hard_coded_m2s.write.w.strb <= x"0f";
      wait until (axi_lite_s2m.write.w.ready and axi_lite_m2s.write.w.valid) = '1' and rising_edge(clk);
      hard_coded_m2s.write.w.valid <= '0';

      hard_coded_m2s.write.b.ready <= '1';
      wait until (axi_lite_m2s.write.b.ready and axi_lite_s2m.write.b.valid) = '1' and rising_edge(clk);
      hard_coded_m2s.write.b.ready <= '0';
    end procedure;

    variable rnd : RandomPType;
    variable data : std_logic_vector(data_width - 1 downto 0);
    variable address : integer;
    variable buf : buffer_t;

  begin
    test_runner_setup(runner, runner_cfg);
    rnd.InitSeed(rnd'instance_name);

    for slave_idx in memory'range loop
      buf := allocate(memory(slave_idx), bank_address(slave_idx, num_words));
    end loop;

    if run("read_and_write_to_buffer") then
      for slave_idx in memory'range loop
        for word in 0 to num_words - 1 loop
          address := bank_address(slave_idx, word);
          data := rnd.RandSLV(data'length);
          set_expected_word(memory(slave_idx), address, data);

          -- Call is non-blocking. I.e. we will build up a queue of writes.
          write_bus(net, axi_master, address, data);
          wait until rising_edge(clk);
        end loop;
      end loop;
      wait_until_idle(net, as_sync(axi_master));

      -- Test that everything was written correctly to memory
      for slave_idx in memory'range loop
        check_expected_was_written(memory(slave_idx));
      end loop;

      -- Test reading back data
      for slave_idx in memory'range loop
        for word in 0 to num_words - 1 loop
          address := bank_address(slave_idx, word);
          data := read_word(memory(slave_idx), address, 4);

          check_bus(net, axi_master, address, data);
        end loop;
      end loop;

    elsif run("read_from_non_existent_slave_base_address") then
      hard_coded_read_data(x"0000_4000");
      check_equal(axi_lite_s2m.read.r.resp, axi_resp_decerr);

      data := rnd.RandSLV(data'length);
      write_word(memory(0), bank_address(0, 0), data);
      hard_coded_read_data(slave_addrs(0).addr);
      check_equal(axi_lite_s2m.read.r.resp, axi_resp_okay);
      check_equal(axi_lite_s2m.read.r.data(data'range), data);

      hard_coded_read_data(x"0000_5000");
      check_equal(axi_lite_s2m.read.r.resp, axi_resp_decerr);

      data := rnd.RandSLV(data'length);
      write_word(memory(1), bank_address(1, 0), data);
      hard_coded_read_data(slave_addrs(1).addr);
      check_equal(axi_lite_s2m.read.r.resp, axi_resp_okay);
      check_equal(axi_lite_s2m.read.r.data(data'range), data);

    elsif run("write_to_non_existent_slave_base_address") then
      hard_coded_write_data(x"0000_4000", x"0102_0304");
      check_equal(axi_lite_s2m.write.b.resp, axi_resp_decerr);

      data := rnd.RandSLV(data'length);
      set_expected_word(memory(0), bank_address(0, 0), data);
      hard_coded_write_data(slave_addrs(0).addr, data);
      check_equal(axi_lite_s2m.write.b.resp, axi_resp_okay);
      check_expected_was_written(memory(0));

      hard_coded_write_data(x"0000_5000", x"0102_0304");
      check_equal(axi_lite_s2m.write.b.resp, axi_resp_decerr);

      data := rnd.RandSLV(data'length);
      set_expected_word(memory(1), bank_address(1, 0), data);
      hard_coded_write_data(slave_addrs(1).addr, data);
      check_equal(axi_lite_s2m.write.b.resp, axi_resp_okay);
      check_expected_was_written(memory(1));
    end if;

    test_runner_cleanup(runner);
  end process;


  ------------------------------------------------------------------------------
  axi_lite_master_generate : if use_axi_lite_bfm generate
    axi_lite_master_inst : entity bfm.axi_lite_master
      generic map (
        bus_handle => axi_master
      )
      port map (
        clk => clk,

        axi_lite_m2s => axi_lite_m2s,
        axi_lite_s2m => axi_lite_s2m
      );

  else generate

    axi_lite_m2s <= hard_coded_m2s;
  end generate;


  ------------------------------------------------------------------------------
  axi_lite_slave_gen : for i in axi_read_slave'range generate
  begin
    axi_lite_slave_inst : entity bfm.axi_lite_slave
      generic map (
        axi_read_slave => axi_read_slave(i),
        axi_write_slave => axi_write_slave(i),
        data_width => data_width
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
      slave_addrs => slave_addrs
    )
    port map (
      clk => clk,

      axi_lite_m2s => axi_lite_m2s,
      axi_lite_s2m => axi_lite_s2m,

      axi_lite_m2s_vec => axi_lite_m2s_vec,
      axi_lite_s2m_vec => axi_lite_s2m_vec
    );

end architecture;
