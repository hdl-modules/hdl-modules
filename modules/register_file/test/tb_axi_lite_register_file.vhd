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

library vunit_lib;
use vunit_lib.bus_master_pkg.all;
use vunit_lib.check_pkg.all;
use vunit_lib.queue_pkg.all;
use vunit_lib.com_pkg.net;
use vunit_lib.run_pkg.all;

library osvvm;
use osvvm.RandomPkg.RandomPType;

library bfm;

library common;
use common.addr_pkg.all;
use common.types_pkg.all;

library axi;
use axi.axi_pkg.all;

library axi_lite;
use axi_lite.axi_lite_pkg.all;

use work.register_file_pkg.all;


entity tb_axi_lite_register_file is
  generic (
    seed : natural;
    use_axi_lite_bfm : boolean := true;
    runner_cfg : string
  );
end entity;

architecture tb of tb_axi_lite_register_file is

  -- Generic constants.
  constant regs : register_definition_vec_t(0 to 15 - 1) := (
    (index => 0, mode => r, utilized_width=>32),
    (index => 1, mode => r, utilized_width=>32),
    (index => 2, mode => r, utilized_width=>32),
    (index => 3, mode => w, utilized_width=>32),
    (index => 4, mode => w, utilized_width=>32),
    (index => 5, mode => w, utilized_width=>32),
    (index => 6, mode => r_w, utilized_width=>32),
    (index => 7, mode => r_w, utilized_width=>32),
    (index => 8, mode => r_w, utilized_width=>32),
    (index => 9, mode => wpulse, utilized_width=>32),
    (index => 10, mode => wpulse, utilized_width=>32),
    (index => 11, mode => wpulse, utilized_width=>32),
    (index => 12, mode => r_wpulse, utilized_width=>32),
    (index => 13, mode => r_wpulse, utilized_width=>32),
    (index => 14, mode => r_wpulse, utilized_width=>32)
  );

  constant default_values : register_vec_t(regs'range) := (
    0 => x"dcd3e0e6",
    1 => x"323e4bfd",
    2 => x"7ddd475b",
    3 => x"0c4c3891",
    4 => x"cb40a113",
    5 => x"f8c6f339",
    6 => x"a17f0a63",
    7 => x"333665c6",
    8 => x"136f6857",
    9 => x"9901a7d0",
    10 => x"45974c0b",
    11 => x"067b0394",
    12 => x"c5b5d0fc",
    13 => x"86130210",
    14 => x"ad1f5653"
  );

  -- DUT connections.
  constant clk_period : time := 10 ns;
  signal clk, reset : std_ulogic := '0';

  signal hardcoded_m2s, axi_lite_m2s : axi_lite_m2s_t := axi_lite_m2s_init;
  signal axi_lite_s2m : axi_lite_s2m_t := axi_lite_s2m_init;

  signal regs_up : register_vec_t(regs'range) := (others => (others => '0'));
  signal regs_down : register_vec_t(regs'range);
  signal reg_was_read, reg_was_written : std_ulogic_vector(regs'range);

  -- Testbench stuff.
  constant axi_master : bus_master_t := new_bus(
    data_length => register_width,
    address_length => axi_lite_m2s.read.ar.addr'length
  );

  constant reg_was_accessed_zero : std_ulogic_vector(reg_was_written'range) := (others => '0');

  signal regs_down_non_default_count : natural := 0;

  constant read_index_queue, write_index_queue, write_data_queue : queue_t := new_queue;

begin

  test_runner_watchdog(runner, 200 us);
  clk <= not clk after clk_period / 2;


  ------------------------------------------------------------------------------
  main : process
    variable rnd : RandomPType;
    variable fabric_data, bus_data : register_vec_t(0 to regs'length - 1);

    procedure reg_stimuli(reg : register_definition_t) is
    begin
      if is_write_mode(reg.mode) then
        write_bus(net, axi_master, 4 * reg.index, bus_data(reg.index));
      end if;

      if is_application_gives_value_mode(reg.mode) then
        regs_up(reg.index) <= fabric_data(reg.index);
      end if;
    end procedure;

    procedure reg_data_check(reg : register_definition_t) is
      variable reg_was_accessed_expected : std_ulogic_vector(reg_was_written'range)
        := (others => '0');
      variable read_bus_reference : bus_reference_t;
      variable read_bus_data : register_t;
    begin
      reg_was_accessed_expected(reg.index) := '1';

      if is_write_mode(reg.mode) then
        wait_for_write_to_go_through : while true loop
          if is_write_pulse_mode(reg.mode) then
            -- The value that fabric gets should be default all cycles except the one where the
            -- write happens
            check_equal(regs_down(reg.index), default_values(reg.index));
          end if;

          wait until rising_edge(clk);
          if reg_was_written /= reg_was_accessed_zero then
            check_equal(reg_was_written, reg_was_accessed_expected);
            exit wait_for_write_to_go_through;
          end if;
        end loop;

        check_equal(regs_down(reg.index), bus_data(reg.index));
      end if;

      if is_write_pulse_mode(reg.mode) then
        wait until rising_edge(clk);
        -- The value that fabric gets should be default all cycles except the one where the
        -- write happens
        check_equal(regs_down(reg.index), default_values(reg.index));
      end if;

      if is_read_mode(reg.mode) then
        -- Initiate a non-blocking read
        read_bus(net, axi_master, 4 * reg.index, read_bus_reference);

        wait until reg_was_read /= reg_was_accessed_zero and rising_edge(clk);
        check_equal(reg_was_read, reg_was_accessed_expected);

        await_read_bus_reply(net, read_bus_reference, read_bus_data);

        if is_application_gives_value_mode(reg.mode) then
          check_equal(read_bus_data, fabric_data(reg.index));
        else
          check_equal(read_bus_data, bus_data(reg.index));
        end if;
      end if;
    end procedure;

    procedure read_hardcoded(reg_index : integer) is
    begin
      push(read_index_queue, reg_index);
    end procedure;

    procedure read_and_wait_hardcoded(reg_index : integer) is
    begin
      read_hardcoded(reg_index);

      wait until
        ((axi_lite_m2s.read.r.ready and axi_lite_s2m.read.r.valid) or reset) = '1'
        and rising_edge(clk);
    end procedure;

    procedure write_hardcoded(reg_index : integer; data : register_t := (others => '0')) is
    begin
      push(write_index_queue, reg_index);
      push(write_data_queue, data);
    end procedure;

    procedure write_and_wait_hardcoded(reg_index : integer; data : register_t := (others => '0')) is
    begin
      write_hardcoded(reg_index, data);

      wait until
        ((axi_lite_m2s.write.b.ready and axi_lite_s2m.write.b.valid) or reset) = '1'
        and rising_edge(clk);
    end procedure;

  begin
    test_runner_setup(runner, runner_cfg);
    rnd.InitSeed(seed);

    if run("test_default_register_values") then
      wait for 10 * clk_period;

      check_equal(regs_down_non_default_count, 0);

    elsif run("test_random_read_and_write") then
      for list_index in regs'range loop
        fabric_data(list_index) := rnd.RandSLV(fabric_data(0)'length);
        bus_data(list_index) := rnd.RandSLV(bus_data(0)'length);
      end loop;

      for list_index in regs'range loop
        reg_stimuli(regs(list_index));
        reg_data_check(regs(list_index));
      end loop;

    elsif run("test_read_from_non_existent_register") then
      read_and_wait_hardcoded(regs(regs'high).index + 1);
      check_equal(axi_lite_s2m.read.r.resp, axi_resp_slverr);

      read_and_wait_hardcoded(regs(regs'high).index);
      check_equal(axi_lite_s2m.read.r.resp, axi_resp_okay);

    elsif run("test_write_to_non_existent_register") then
      write_and_wait_hardcoded(regs(regs'high).index + 1);
      check_equal(axi_lite_s2m.write.b.resp, axi_resp_slverr);

      write_and_wait_hardcoded(regs(regs'high).index);
      check_equal(axi_lite_s2m.write.b.resp, axi_resp_okay);

    elsif run("test_read_from_non_read_type_register") then
      assert regs(3).mode = w;
      read_and_wait_hardcoded(3);
      check_equal(axi_lite_s2m.read.r.resp, axi_resp_slverr);

      read_and_wait_hardcoded(regs(regs'high).index);
      check_equal(axi_lite_s2m.read.r.resp, axi_resp_okay);

    elsif run("test_write_to_non_write_type_register") then
      assert regs(0).mode = r;
      write_and_wait_hardcoded(0);
      check_equal(axi_lite_s2m.write.b.resp, axi_resp_slverr);

      write_and_wait_hardcoded(regs(regs'high).index);
      check_equal(axi_lite_s2m.write.b.resp, axi_resp_okay);

    elsif run("test_reset_read") then
      assert regs(7).mode = r_w;
      read_and_wait_hardcoded(7);
      check_equal(axi_lite_s2m.read.r.data(default_values(0)'range), default_values(7));

      for wait_cycles in 0 to 20 loop
        write_and_wait_hardcoded(7, default_values(8));

        read_and_wait_hardcoded(7);
        check_equal(axi_lite_s2m.read.r.data(default_values(0)'range), default_values(8));

        read_hardcoded(7);
        for wait_cycle_idx in 1 to wait_cycles loop
          wait until rising_edge(clk);
        end loop;
        reset <= '1';

        for reset_cycle in 0 to 10 loop
          wait until rising_edge(clk);
        end loop;

        reset <= '0';
        read_and_wait_hardcoded(7);
        check_equal(axi_lite_s2m.read.r.data(default_values(0)'range), default_values(7));
      end loop;

    elsif run("test_reset_write") then
      for reg_index in 6 to 14 loop
        for wait_cycles in 0 to 20 loop
          write_and_wait_hardcoded(reg_index, default_values(reg_index - 1));

          write_hardcoded(reg_index);
          for wait_cycle_idx in 1 to wait_cycles loop
            wait until rising_edge(clk);
          end loop;
          reset <= '1';

          for reset_cycle in 0 to 10 loop
            wait until rising_edge(clk);
          end loop;

          reset <= '0';
          wait until rising_edge(clk);
          check_equal(
            regs_down(reg_index),
            default_values(reg_index),
            "reg_index=" & to_string(reg_index)
          );
        end loop;
      end loop;

    end if;

    test_runner_cleanup(runner);
  end process;


  ------------------------------------------------------------------------------
  count_status : process
  begin
    wait until rising_edge(clk);

    regs_down_non_default_count <= (
      regs_down_non_default_count + to_int(regs_down /= default_values)
    );
  end process;


  ------------------------------------------------------------------------------
  axi_lite_master_generate : if use_axi_lite_bfm generate

    ------------------------------------------------------------------------------
    axi_lite_master_inst : entity bfm.axi_lite_master
      generic map (
        bus_handle => axi_master
      )
      port map (
        clk => clk,
        --
        axi_lite_m2s => axi_lite_m2s,
        axi_lite_s2m => axi_lite_s2m
      );

  ------------------------------------------------------------------------------
  else generate

    axi_lite_m2s <= hardcoded_m2s;

  end generate;


  ------------------------------------------------------------------------------
  hardcoded_read : process
    procedure perform_read(index : natural) is
    begin
      hardcoded_m2s.read.ar.addr <= to_unsigned(4 * index, hardcoded_m2s.read.ar.addr'length);
      hardcoded_m2s.read.ar.valid <= '1';
      wait until
        ((axi_lite_s2m.read.ar.ready and axi_lite_m2s.read.ar.valid) or reset) = '1'
        and rising_edge(clk);
      hardcoded_m2s.read.ar.valid <= '0';

      if reset then
        return;
      end if;

      hardcoded_m2s.read.r.ready <= '1';
      wait until
        ((axi_lite_m2s.read.r.ready and axi_lite_s2m.read.r.valid) or reset) = '1'
        and rising_edge(clk);
      hardcoded_m2s.read.r.ready <= '0';
    end procedure;
  begin
    while is_empty(read_index_queue) or reset = '1' loop
      wait until rising_edge(clk);
    end loop;

    perform_read(index=>pop(read_index_queue));
  end process;


  ------------------------------------------------------------------------------
  hardcoded_write : process
    procedure perform_write(index : natural; data : register_t) is
    begin
      hardcoded_m2s.write.aw.addr <= to_unsigned(4 * index, hardcoded_m2s.write.aw.addr'length);
      hardcoded_m2s.write.aw.valid <= '1';
      wait until
        ((axi_lite_s2m.write.aw.ready and axi_lite_m2s.write.aw.valid) or reset) = '1'
        and rising_edge(clk);
      hardcoded_m2s.write.aw.valid <= '0';

      if reset then
        return;
      end if;

      hardcoded_m2s.write.w.data(data'range) <= data;
      hardcoded_m2s.write.w.valid <= '1';
      wait until
        ((axi_lite_s2m.write.w.ready and axi_lite_m2s.write.w.valid) or reset) = '1'
        and rising_edge(clk);
      hardcoded_m2s.write.w.valid <= '0';

      if reset then
        return;
      end if;

      hardcoded_m2s.write.b.ready <= '1';
      wait until
        ((axi_lite_m2s.write.b.ready and axi_lite_s2m.write.b.valid) or reset) = '1'
        and rising_edge(clk);
      hardcoded_m2s.write.b.ready <= '0';
    end procedure;
  begin
    while is_empty(write_index_queue) or reset = '1' loop
      wait until rising_edge(clk);
    end loop;

    perform_write(index=>pop(write_index_queue), data=>pop(write_data_queue));
  end process;


  ------------------------------------------------------------------------------
  dut : entity work.axi_lite_register_file
    generic map (
      registers => regs,
      default_values => default_values
    )
    port map (
      clk => clk,
      reset => reset,
      --
      axi_lite_m2s => axi_lite_m2s,
      axi_lite_s2m => axi_lite_s2m,
      --
      regs_up => regs_up,
      regs_down => regs_down,
      --
      reg_was_read => reg_was_read,
      reg_was_written => reg_was_written
    );

end architecture;
