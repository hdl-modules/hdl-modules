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

library vunit_lib;
use vunit_lib.check_pkg.all;
use vunit_lib.run_pkg.all;

library reg_file;
use reg_file.reg_file_pkg.all;


entity tb_interrupt_register is
  generic (
    runner_cfg : string
  );
end entity;

architecture tb of tb_interrupt_register is

  signal clk : std_ulogic := '0';

  signal sources, mask, clear, status : reg_t := (others => '0');
  signal trigger : std_ulogic := '0';

begin

  test_runner_watchdog(runner, 2 ms);
  clk <= not clk after 2 ns;


  ------------------------------------------------------------------------------
  main : process
    procedure wait_one_cycle is
    begin
      wait until rising_edge(clk);
    end procedure;

    procedure wait_a_while is
    begin
      wait until rising_edge(clk);
      wait until rising_edge(clk);
    end procedure;

    procedure check_status(high_bits : integer_vector) is
      variable expected : reg_t := (others => '0');
    begin
      for list_idx in high_bits'range loop
        expected(high_bits(list_idx)) := '1';
      end loop;
      check_equal(status, expected);
    end procedure;

    procedure check_trigger is
    begin
      check_equal(trigger, '1');
    end procedure;

    procedure check_no_trigger is
    begin
      check_equal(trigger, '0');
    end procedure;
  begin
    test_runner_setup(runner, runner_cfg);

    sources <= (0 => '1', 1 => '1', 2 => '1', others => '0');
    wait_a_while;
    check_status((0, 1, 2));
    check_no_trigger;

    -- Source bit and mask bit being high for (at least) one cycle should trigger
    mask(0) <= '1';
    wait_one_cycle;
    sources(0) <= '0';
    wait_a_while;
    check_status((0, 1, 2));
    check_trigger;

    if run("test_clear_register_wipes_trigger") then
      clear(0) <= '1';
      wait_one_cycle;
      clear <= (others => '0');
      wait_one_cycle;
      -- Both status bit and trigger are cleared
      check_status((1, 2));
      check_no_trigger;

    elsif run("test_changing_mask_wipes_trigger") then
      mask(0) <= '0';
      wait_a_while;
      -- Trigger is cleared but status remains
      check_status((0, 1, 2));
      check_no_trigger;

    elsif run("test_clearing_a_constantly_active_source_should_result_in_edge") then
      -- Many interrupt pins, on e.g. a Xilinx PCIe IP core, are edge-triggered, meaning that a
      -- positive edge on the interrupt trigger pin will trigger an interrupt.
      -- In the case where an interrupt is cleared but the root cause of the interrupt has not
      -- been solved, i.e. the interrupt source is static '1', clearing an interrupt should
      -- immediately re-trigger.
      sources(0) <= '1';
      wait_a_while;

      clear(0) <= '1';
      wait_one_cycle;
      clear <= (others => '0');

      wait_one_cycle;
      check_no_trigger;
      wait_one_cycle;
      check_trigger;

    end if;

    test_runner_cleanup(runner);
  end process;


  ------------------------------------------------------------------------------
  dut : entity work.interrupt_register
    port map (
      clk => clk,

      sources => sources,
      mask => mask,
      clear => clear,

      status => status,
      trigger => trigger
    );

end architecture;
