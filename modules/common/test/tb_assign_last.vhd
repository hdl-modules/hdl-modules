-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the hdl-modules project, a collection of reusable, high-quality,
-- peer-reviewed VHDL building blocks.
-- https://hdl-modules.com
-- https://github.com/hdl-modules/hdl-modules
-- -------------------------------------------------------------------------------------------------

library ieee;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;

library osvvm;
use osvvm.RandomPkg.RandomPType;

library vunit_lib;
use vunit_lib.check_pkg.all;
use vunit_lib.integer_array_pkg.all;
use vunit_lib.queue_pkg.all;
use vunit_lib.random_pkg.all;
use vunit_lib.run_pkg.all;

library bfm;
use bfm.stall_bfm_pkg.stall_configuration_t;

use work.types_pkg.all;


entity tb_assign_last is
  generic (
    seed : natural;
    runner_cfg : string
  );
end entity;

architecture tb of tb_assign_last is

  -- Generic constants.
  shared variable rnd : RandomPType;

  impure function initialize_and_get_packet_length_beats return positive is
  begin
    rnd.InitSeed(seed);
    return rnd.Uniform(1, 16);
  end function;
  constant packet_length_beats : positive := initialize_and_get_packet_length_beats;

  constant data_width : positive := 16;
  constant bytes_per_beat : positive := data_width / 8;
  constant packet_length_bytes : natural := packet_length_beats * bytes_per_beat;

  -- DUT connections.
  signal clk : std_ulogic := '0';

  signal ready, valid, last, first : std_ulogic := '0';
  signal data : std_ulogic_vector(data_width - 1 downto 0) := (others => '0');
  signal strobe : std_ulogic_vector(data_width / 8 - 1 downto 0) := (others => '0');

  -- Testbench stuff.
  constant stall_config : stall_configuration_t := (
    stall_probability => 0.2,
    min_stall_cycles => 1,
    max_stall_cycles => 3
  );

  constant input_data_queue, result_data_queue : queue_t := new_queue;

  signal num_packets_checked : natural := 0;

begin

  test_runner_watchdog(runner, 100 us);
  clk <= not clk after 5 ns;


  ------------------------------------------------------------------------------
  main : process
    procedure test_random_data is
      variable test_data, data_copy : integer_array_t := null_integer_array;
    begin
      random_integer_array(
        rnd => rnd,
        integer_array => test_data,
        width => packet_length_bytes,
        bits_per_word => 8,
        is_signed => false
      );
      data_copy := copy(test_data);

      push_ref(input_data_queue, test_data);
      push_ref(result_data_queue, data_copy);
    end procedure;

  begin
    test_runner_setup(runner, runner_cfg);

    report "Running with packet_length_beats = " & to_string(packet_length_beats);

    if run("test_random_data") then
      for test_idx in 0 to 50 - 1 loop
        test_random_data;
      end loop;
    end if;

    wait until num_packets_checked = 50 and rising_edge(clk);

    test_runner_cleanup(runner);
  end process;


  ------------------------------------------------------------------------------
  axi_stream_master_inst : entity bfm.axi_stream_master
    generic map (
      data_width => data'length,
      data_queue => input_data_queue,
      stall_config => stall_config,
      seed => seed,
      logger_name_suffix => " - input"
    )
    port map (
      clk => clk,
      --
      ready => ready,
      valid => valid,
      last => open,
      data => data,
      strobe => strobe
    );


  ------------------------------------------------------------------------------
  axi_stream_slave_inst : entity bfm.axi_stream_slave
    generic map (
      data_width => data'length,
      reference_data_queue => result_data_queue,
      stall_config => stall_config,
      seed => seed,
      logger_name_suffix => " - result"
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
  check_first : process
    variable count : natural := 0;
  begin
    wait until ready and valid and rising_edge(clk);

    check_equal(first, count = 0);
    count := (count + 1) mod packet_length_beats;
  end process;


  ------------------------------------------------------------------------------
  dut : entity work.assign_last
    generic map(
      packet_length_beats => packet_length_beats
    )
    port map(
      clk => clk,
      --
      ready => ready,
      valid => valid,
      last => last,
      first => first
    );

end architecture;
