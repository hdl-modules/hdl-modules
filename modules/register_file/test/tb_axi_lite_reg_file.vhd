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

use work.reg_file_pkg.all;


entity tb_axi_lite_reg_file is
  generic (
    seed : natural;
    use_axi_lite_bfm : boolean := true;
    runner_cfg : string
  );
end entity;

architecture tb of tb_axi_lite_reg_file is

  -- Generic constants.
  constant regs : reg_definition_vec_t(0 to 15 - 1) := (
    (idx => 0, reg_type => r),
    (idx => 1, reg_type => r),
    (idx => 2, reg_type => r),
    (idx => 3, reg_type => w),
    (idx => 4, reg_type => w),
    (idx => 5, reg_type => w),
    (idx => 6, reg_type => r_w),
    (idx => 7, reg_type => r_w),
    (idx => 8, reg_type => r_w),
    (idx => 9, reg_type => wpulse),
    (idx => 10, reg_type => wpulse),
    (idx => 11, reg_type => wpulse),
    (idx => 12, reg_type => r_wpulse),
    (idx => 13, reg_type => r_wpulse),
    (idx => 14, reg_type => r_wpulse)
  );

  constant default_values : reg_vec_t(regs'range) := (
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
  signal clk : std_ulogic := '0';

  signal hardcoded_m2s, axi_lite_m2s : axi_lite_m2s_t;
  signal axi_lite_s2m : axi_lite_s2m_t;

  signal regs_up : reg_vec_t(regs'range) := (others => (others => '0'));
  signal regs_down : reg_vec_t(regs'range);
  signal reg_was_read, reg_was_written : std_ulogic_vector(regs'range);

  -- Testbench stuff.
  constant axi_master : bus_master_t := new_bus(
    data_length => reg_width,
    address_length => axi_lite_m2s.read.ar.addr'length
  );

  constant reg_was_accessed_zero : std_ulogic_vector(reg_was_written'range) := (others => '0');

  signal regs_down_non_default_count : natural := 0;

begin

  test_runner_watchdog(runner, 2 ms);
  clk <= not clk after clk_period / 2;


  ------------------------------------------------------------------------------
  main : process
    variable rnd : RandomPType;
    variable fabric_data, bus_data : reg_vec_t(0 to regs'length - 1);

    procedure reg_stimuli(reg : reg_definition_t) is
    begin
      if is_write_type(reg.reg_type) then
        write_bus(net, axi_master, 4 * reg.idx, bus_data(reg.idx));
      end if;

      if is_fabric_gives_value_type(reg.reg_type) then
        regs_up(reg.idx) <= fabric_data(reg.idx);
      end if;
    end procedure;

    procedure reg_data_check(reg : reg_definition_t) is
      variable reg_was_accessed_expected : std_ulogic_vector(reg_was_written'range)
        := (others => '0');
      variable read_bus_reference : bus_reference_t;
      variable read_bus_data : reg_t;
    begin
      reg_was_accessed_expected(reg.idx) := '1';

      if is_write_type(reg.reg_type) then
        wait_for_write_to_go_through : while true loop
          if is_write_pulse_type(reg.reg_type) then
            -- The value that fabric gets should be default all cycles except the one where the
            -- write happens
            check_equal(regs_down(reg.idx), default_values(reg.idx));
          end if;

          wait until rising_edge(clk);
          if reg_was_written /= reg_was_accessed_zero then
            check_equal(reg_was_written, reg_was_accessed_expected);
            exit wait_for_write_to_go_through;
          end if;
        end loop;

        check_equal(regs_down(reg.idx), bus_data(reg.idx));
      end if;

      if is_write_pulse_type(reg.reg_type) then
        wait until rising_edge(clk);
        -- The value that fabric gets should be default all cycles except the one where the
        -- write happens
        check_equal(regs_down(reg.idx), default_values(reg.idx));
      end if;

      if is_read_type(reg.reg_type) then
        -- Initiate a non-blocking read
        read_bus(net, axi_master, 4 * reg.idx, read_bus_reference);

        wait until reg_was_read /= reg_was_accessed_zero and rising_edge(clk);
        check_equal(reg_was_read, reg_was_accessed_expected);

        await_read_bus_reply(net, read_bus_reference, read_bus_data);

        if is_fabric_gives_value_type(reg.reg_type) then
          check_equal(read_bus_data, fabric_data(reg.idx));
        else
          check_equal(read_bus_data, bus_data(reg.idx));
        end if;
      end if;
    end procedure;

    procedure read_hardcoded(reg_index : integer) is
    begin
      hardcoded_m2s.read.ar.addr <= to_unsigned(4 * reg_index, hardcoded_m2s.read.ar.addr'length);
      hardcoded_m2s.read.ar.valid <= '1';
      wait until
        (axi_lite_s2m.read.ar.ready and axi_lite_m2s.read.ar.valid) = '1'
        and rising_edge(clk);
      hardcoded_m2s.read.ar.valid <= '0';

      hardcoded_m2s.read.r.ready <= '1';
      wait until
        (axi_lite_m2s.read.r.ready and axi_lite_s2m.read.r.valid) = '1'
        and rising_edge(clk);
      hardcoded_m2s.read.r.ready <= '0';
    end procedure;

    procedure write_hardcoded(reg_index : integer) is
    begin
      hardcoded_m2s.write.aw.addr <= to_unsigned(4 * reg_index, hardcoded_m2s.write.aw.addr'length);
      hardcoded_m2s.write.aw.valid <= '1';
      wait until
        (axi_lite_s2m.write.aw.ready and axi_lite_m2s.write.aw.valid) = '1'
        and rising_edge(clk);
      hardcoded_m2s.write.aw.valid <= '0';

      hardcoded_m2s.write.w.valid <= '1';
      wait until
        (axi_lite_s2m.write.w.ready and axi_lite_m2s.write.w.valid) = '1'
        and rising_edge(clk);
      hardcoded_m2s.write.w.valid <= '0';

      hardcoded_m2s.write.b.ready <= '1';
      wait until
        (axi_lite_m2s.write.b.ready and axi_lite_s2m.write.b.valid) = '1'
        and rising_edge(clk);
      hardcoded_m2s.write.b.ready <= '0';
    end procedure;

  begin
    test_runner_setup(runner, runner_cfg);
    rnd.InitSeed(seed);

    if run("test_default_register_values") then
      wait for 10 * clk_period;

      check_equal(regs_down_non_default_count, 0);

    elsif run("test_random_read_and_write") then
      for list_idx in regs'range loop
        fabric_data(list_idx) := rnd.RandSLV(fabric_data(0)'length);
        bus_data(list_idx) := rnd.RandSLV(bus_data(0)'length);
      end loop;

      for list_idx in regs'range loop
        reg_stimuli(regs(list_idx));
        reg_data_check(regs(list_idx));
      end loop;

    elsif run("test_read_from_non_existent_register") then
      read_hardcoded(regs(regs'high).idx + 1);
      check_equal(axi_lite_s2m.read.r.resp, axi_resp_slverr);

      read_hardcoded(regs(regs'high).idx);
      check_equal(axi_lite_s2m.read.r.resp, axi_resp_okay);

    elsif run("test_write_to_non_existent_register") then
      write_hardcoded(regs(regs'high).idx + 1);
      check_equal(axi_lite_s2m.write.b.resp, axi_resp_slverr);

      write_hardcoded(regs(regs'high).idx);
      check_equal(axi_lite_s2m.write.b.resp, axi_resp_okay);

    elsif run("test_read_from_non_read_type_register") then
      assert regs(3).reg_type = w;
      read_hardcoded(3);
      check_equal(axi_lite_s2m.read.r.resp, axi_resp_slverr);

      read_hardcoded(regs(regs'high).idx);
      check_equal(axi_lite_s2m.read.r.resp, axi_resp_okay);

    elsif run("test_write_to_non_write_type_register") then
      assert regs(0).reg_type = r;
      write_hardcoded(0);
      check_equal(axi_lite_s2m.write.b.resp, axi_resp_slverr);

      write_hardcoded(regs(regs'high).idx);
      check_equal(axi_lite_s2m.write.b.resp, axi_resp_okay);
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
    axi_lite_m2s <= hardcoded_m2s;
  end generate;


  ------------------------------------------------------------------------------
  dut : entity work.axi_lite_reg_file
    generic map (
      regs => regs,
      default_values => default_values
    )
    port map (
      clk => clk,
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
