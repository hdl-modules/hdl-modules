-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the hdl_modules project, a collection of reusable, high-quality,
-- peer-reviewed VHDL building blocks.
-- https://hdl-modules.com
-- https://gitlab.com/hdl_modules/hdl_modules
-- -------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

library osvvm;
use osvvm.RandomPkg.all;

library vunit_lib;
context vunit_lib.vc_context;
context vunit_lib.vunit_context;
use vunit_lib.random_pkg.all;

library common;


entity tb_axi_stream_bfm is
  generic (
    master_stall_probability_percent : natural;
    slave_stall_probability_percent : natural;
    data_width : natural;
    seed : natural;
    runner_cfg : string
  );
end entity;

architecture tb of tb_axi_stream_bfm is

  -- Generics
  constant drive_invalid_value : std_logic := 'X';

  -- DUT connections
  constant clk_period : time := 10 ns;
  signal clk : std_logic := '0';

  signal ready, valid, last : std_logic := '0';
  signal data : std_logic_vector(data_width - 1 downto 0) := (others => '0');
  signal strobe : std_logic_vector(data_width / 8 - 1 downto 0) := (others => '0');

  -- Testbench stuff
  constant master_stall_config : stall_config_t := (
    stall_probability => real(master_stall_probability_percent) / 100.0,
    min_stall_cycles => 1,
    max_stall_cycles => 3
  );

  constant slave_stall_config : stall_config_t := (
    stall_probability => real(slave_stall_probability_percent) / 100.0,
    min_stall_cycles => 1,
    max_stall_cycles => 3
  );

  constant input_data_queue, reference_data_queue : queue_t := new_queue;

  signal num_packets_checked : natural := 0;

begin

  test_runner_watchdog(runner, 2 ms);
  clk <= not clk after clk_period / 2;


  ------------------------------------------------------------------------------
  main : process
    variable rnd : RandomPType;

    variable num_packets_expected : natural := 0;

    procedure test_random_packet is
      variable data, data_copy : integer_array_t := null_integer_array;
    begin
      random_integer_array(
        rnd=>rnd,
        integer_array=>data,
        width=>rnd.RandInt(1, 30),
        bits_per_word => 8,
        is_signed => false
      );
      data_copy := copy(data);

      push_ref(input_data_queue, data);
      push_ref(reference_data_queue, data_copy);

      num_packets_expected := num_packets_expected + 1;
    end procedure;

  begin
    test_runner_setup(runner, runner_cfg);

    rnd.InitSeed(seed);

    if run("test_random_data") then
      for idx in 0 to 100 loop
        test_random_packet;
      end loop;
    end if;

    wait until num_packets_checked = num_packets_expected and rising_edge(clk);

    test_runner_cleanup(runner);
  end process;


  ------------------------------------------------------------------------------
  axi_stream_master_inst : entity work.axi_stream_master
    generic map (
      data_width => data'length,
      data_queue => input_data_queue,
      stall_config => master_stall_config,
      seed => seed,
      logger_name_suffix => "_input"
    )
    port map (
      clk => clk,
      --
      ready => ready,
      valid => valid,
      last => last,
      data => data,
      strobe => strobe
    );


  ------------------------------------------------------------------------------
  axi_stream_slave_inst : entity work.axi_stream_slave
    generic map (
      data_width => data'length,
      reference_data_queue => reference_data_queue,
      stall_config => slave_stall_config,
      seed => seed,
      logger_name_suffix => "_result"
    )
    port map (
      clk => clk,
      --
      ready => ready,
      valid => valid,
      last => last,
      data => data,
      strobe => strobe,
      --
      num_packets_checked => num_packets_checked
    );


  ------------------------------------------------------------------------------
  check_invalid_value : process
    constant data_all_invalid : std_logic_vector(data'range) :=
      (others => drive_invalid_value);
    constant strobe_all_invalid : std_logic_vector(strobe'range) :=
      (others => drive_invalid_value);
    constant byte_invalid : std_logic_vector(8 - 1 downto 0) := (others => drive_invalid_value);
  begin
    wait until rising_edge(clk);

    -- AXI-Stream master should drive the 'invalid' value when bus is not valid.

    if valid then
      for byte_idx in strobe'range loop
        if not strobe(byte_idx) then
          -- Even when valid, lanes that are strobed out should have data driven with 'invalid'
          check_equal(
            data((byte_idx + 1) * 8 - 1 downto byte_idx * 8),
            byte_invalid,
            "byte_idx=" & to_string(byte_idx)
          );
        end if;
      end loop;

    else
      check_equal(last, drive_invalid_value);
      check_equal(data, data_all_invalid);
      check_equal(strobe, strobe_all_invalid);
    end if;
  end process;

end architecture;
