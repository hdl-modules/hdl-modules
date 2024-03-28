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

library common;
use common.types_pkg.all;


entity tb_keep_remover is
  generic (
    seed : natural;
    data_width : positive;
    strobe_unit_width : positive;
    -- Will be set false when testing for full throughput, but should be enabled for other tests
    enable_jitter : boolean := true;
    runner_cfg : string
  );
end entity;

architecture tb of tb_keep_remover is

  constant bytes_per_word : positive := data_width / 8;
  constant bytes_per_atom : positive := strobe_unit_width / 8;
  constant atoms_per_word : positive := data_width / strobe_unit_width;

  signal clk : std_ulogic := '0';
  constant clk_period : time := 10 ns;

  signal input_ready, input_valid, input_last : std_ulogic := '0';
  signal output_ready, output_valid, output_last : std_ulogic := '0';

  signal input_data, output_data : std_ulogic_vector(data_width - 1 downto 0) := (others => '0');
  signal input_keep, output_strobe :
    std_ulogic_vector(data_width / strobe_unit_width - 1 downto 0) := (others => '0');

  constant input_data_queue, reference_data_queue : queue_t := new_queue;

  constant stall_config : stall_configuration_t := (
    stall_probability => 0.2 * to_real(enable_jitter),
    min_stall_cycles => 1,
    max_stall_cycles => 4
  );

  shared variable rnd : RandomPType;
  signal num_output_packets_checked : natural := 0;

begin

  test_runner_watchdog(runner, 100 us);
  clk <= not clk after clk_period / 2;


  ------------------------------------------------------------------------------
  main : process

    variable num_output_packets_expected : natural := 0;

    procedure run_test_packet is
      variable packet_length_atoms, packet_length_bytes : positive := 1;
      variable data_in, reference_data_out : integer_array_t := null_integer_array;
    begin
      -- Random length. We want to run just a few words, since we want to exercise
      -- the 'last' behavior a lot.
      packet_length_atoms := rnd.RandInt(1, 3 * atoms_per_word);

      -- Number of bytes must be a whole number of atoms for strobing to make sense
      packet_length_bytes := packet_length_atoms * bytes_per_atom;

      random_integer_array(
        rnd => rnd,
        integer_array => data_in,
        width => packet_length_bytes,
        bits_per_word => 8,
        is_signed => false
      );
      reference_data_out := copy(data_in);

      push_ref(input_data_queue, data_in);
      push_ref(reference_data_queue, reference_data_out);

      num_output_packets_expected := num_output_packets_expected + 1;
    end procedure;

    procedure wait_until_done is
    begin
      wait until
        is_empty(input_data_queue)
        and is_empty(reference_data_queue)
        and num_output_packets_checked = num_output_packets_expected
        and rising_edge(clk);
    end procedure;

  begin
    test_runner_setup(runner, runner_cfg);
    rnd.InitSeed(seed);

    if run("test_data") then
      for packet_idx in 0 to 500 loop
        run_test_packet;
      end loop;

    elsif run("test_full_throughput") then
      -- This test will have no jitter/stall in the AXI-Stream master/slave, but random input
      -- strobe. A checker process asserts that 'input_ready' is always one.
      for packet_idx in 0 to 500 loop
        run_test_packet;
      end loop;

    end if;

    wait_until_done;

    test_runner_cleanup(runner);
  end process;


  ------------------------------------------------------------------------------
  input_block : block
    signal data_is_valid : std_ulogic := '0';
  begin

    ------------------------------------------------------------------------------
    stimuli : process
      variable input_bytes : integer_array_t := null_integer_array;
      variable num_input_bytes : positive := 1;

      variable data_value : natural := 0;
      variable array_byte_idx, byte_lane_idx : natural := 0;

      impure function get_num_bytes_this_word return natural is
        variable num_atoms_this_word : natural range 0 to atoms_per_word := 0;
        variable num_bytes_left : natural := 0;
        variable result : natural range 0 to bytes_per_word := 0;
      begin
        -- Random number of atoms per word, which result in strobing
        num_atoms_this_word := rnd.RandInt(0, atoms_per_word);

        if enabled("test_full_throughput") and num_bytes_left <= bytes_per_word then
          -- The corner case which results in 'last' input padding does not achieve full
          -- throughput (see keep_remover header). So we try to not trigger that case when
          -- we are testing for full throughput.
          -- Send the last beats so that the very last beat does not fill a non-empty buffer
          -- over the line to contain more than one output beat.
          num_atoms_this_word := minimum(atoms_per_word / 2, num_atoms_this_word);
        end if;

        result := num_atoms_this_word * bytes_per_atom;

        num_bytes_left := num_input_bytes - array_byte_idx;
        result := minimum(result, num_bytes_left);

        return result;
      end function;
      variable num_bytes_this_word : natural range 0 to bytes_per_word := 0;
    begin
      while is_empty(input_data_queue) loop
        wait until rising_edge(clk);
      end loop;

      data_is_valid <= '1';

      input_bytes := pop_ref(input_data_queue);
      num_input_bytes := length(input_bytes);

      array_byte_idx := 0;
      while array_byte_idx < num_input_bytes loop
        num_bytes_this_word := get_num_bytes_this_word;

        -- Assign a random number of atoms per beat. Can be zero.
        for data_byte_idx in 0 to num_bytes_this_word - 1 loop
          byte_lane_idx := data_byte_idx mod bytes_per_word;

          data_value := get(arr=>input_bytes, idx=>array_byte_idx + data_byte_idx);
          input_data((byte_lane_idx + 1) * 8 - 1 downto byte_lane_idx * 8) <=
            std_logic_vector(to_unsigned(data_value, 8));

          -- Set atom strobe
          input_keep(byte_lane_idx / bytes_per_atom) <= '1';
        end loop;

        array_byte_idx := array_byte_idx + num_bytes_this_word;

        -- Note that this only happens on a beat that has at least one atom strobed.
        -- Can not, and may not, happen on a beat that has no atom strobed.
        input_last <= to_sl(num_bytes_this_word > 0 and array_byte_idx = num_input_bytes);

        wait until input_ready and input_valid and rising_edge(clk);

        input_data <= (others => '0');
        input_keep <= (others => '0');
        input_last <= '0';
      end loop;

      -- Deallocate after we are done with the data.
      deallocate(input_bytes);

      -- Default: Signal "not valid" to handshake BFM before next packet.
      -- If queue is not empty, it will instantly be raised again (no bubble cycle).
      data_is_valid <= '0';
    end process;


    ------------------------------------------------------------------------------
    handshake_master_inst : entity bfm.handshake_master
      generic map (
        stall_config => stall_config,
        logger_name_suffix => " - input",
        seed => seed
      )
      port map (
        clk => clk,
        --
        data_is_valid => data_is_valid,
        --
        ready => input_ready,
        valid => input_valid
      );

  end block;


  ------------------------------------------------------------------------------
  check_full_throughput : process
  begin
    wait until rising_edge(clk);

    if enabled("test_full_throughput")  then
      check_equal(input_ready, '1', "Should always be ready to accept a new input word");
    end if;
  end process;


  ------------------------------------------------------------------------------
  axi_stream_slave_inst : entity bfm.axi_stream_slave
    generic map (
      data_width => output_data'length,
      reference_data_queue => reference_data_queue,
      stall_config => stall_config,
      logger_name_suffix => " - output",
      seed => seed,
      strobe_unit_width => output_data'length / output_strobe'length
    )
    port map (
      clk => clk,
      --
      ready => output_ready,
      valid => output_valid,
      last => output_last,
      data => output_data,
      strobe => output_strobe,
      --
      num_packets_checked => num_output_packets_checked
    );


  ------------------------------------------------------------------------------
  dut : entity work.keep_remover
    generic map (
      data_width => data_width,
      strobe_unit_width => strobe_unit_width
    )
    port map (
      clk => clk,
      --
      input_ready => input_ready,
      input_valid => input_valid,
      input_last => input_last,
      input_data => input_data,
      input_keep => input_keep,
      --
      output_ready => output_ready,
      output_valid => output_valid,
      output_last => output_last,
      output_data => output_data,
      output_strobe => output_strobe
    );

end architecture;
