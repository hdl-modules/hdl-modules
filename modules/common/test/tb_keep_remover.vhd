-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the tsfpga project.
-- https://tsfpga.com
-- https://gitlab.com/tsfpga/tsfpga
-- -------------------------------------------------------------------------------------------------

library ieee;
context ieee.ieee_std_context;

library vunit_lib;
use vunit_lib.random_pkg.all;
context vunit_lib.vc_context;
context vunit_lib.vunit_context;

library osvvm;
use osvvm.RandomPkg.all;

library bfm;

library common;
use common.types_pkg.all;


entity tb_keep_remover is
  generic (
    data_width : positive;
    strobe_unit_width : positive;
    enable_jitter : boolean := true;
    runner_cfg : string
  );
end entity;

architecture tb of tb_keep_remover is

  constant bytes_per_word : positive := data_width / 8;
  constant bytes_per_atom : positive := strobe_unit_width / 8;
  constant atoms_per_word : positive := data_width / strobe_unit_width;

  signal clk : std_logic := '0';
  constant clk_period : time := 10 ns;

  signal input_ready, input_valid, input_last : std_logic := '0';
  signal output_ready, output_valid, output_last : std_logic := '0';

  signal input_data, output_data : std_logic_vector(data_width - 1 downto 0) := (others => '0');
  signal input_keep, output_strobe :
    std_logic_vector(data_width / strobe_unit_width - 1 downto 0) := (others => '0');

  constant input_data_queue, reference_data_queue : queue_t := new_queue;

  constant stall_config : stall_config_t := (
    stall_probability => 0.2 * to_real(enable_jitter),
    min_stall_cycles => 1,
    max_stall_cycles => 4
  );

  shared variable rnd : RandomPType;
  signal num_output_bursts_checked : natural := 0;

begin

  test_runner_watchdog(runner, 100 us);
  clk <= not clk after clk_period / 2;


  ------------------------------------------------------------------------------
  main : process

    variable num_output_bursts_expected : natural := 0;

    procedure run_test_burst(fixed_length_words : natural := 0) is
      variable burst_length_atoms, burst_length_bytes : positive := 1;
      variable data_in, reference_data_out : integer_array_t := null_integer_array;
    begin
      if fixed_length_words /= 0 then
        burst_length_atoms := fixed_length_words * atoms_per_word;
      else
        -- Random length. We want to run just a few words, since we want to exercies
        -- the 'last' behavior a lot.
        burst_length_atoms := rnd.RandInt(1, 3 * atoms_per_word);
      end if;

      -- Number of bytes must be a whole number of atoms for strobing to make sense
      burst_length_bytes := burst_length_atoms * bytes_per_atom;

      random_integer_array(
        rnd => rnd,
        integer_array => data_in,
        width => burst_length_bytes,
        bits_per_word => 8,
        is_signed => false
      );
      reference_data_out := copy(data_in);

      push_ref(input_data_queue, data_in);
      push_ref(reference_data_queue, reference_data_out);

      num_output_bursts_expected := num_output_bursts_expected + 1;
    end procedure;

    procedure wait_until_done is
    begin
      wait until
        is_empty(input_data_queue)
        and is_empty(reference_data_queue)
        and num_output_bursts_checked = num_output_bursts_expected
        and rising_edge(clk);
    end procedure;

    variable start_time, time_diff : time;

  begin
    test_runner_setup(runner, runner_cfg);
    rnd.InitSeed(rnd'instance_name);

    if run("test_data") then
      for burst_idx in 0 to 500 loop
        run_test_burst;
      end loop;

      wait_until_done;

    elsif run("test_full_throughput") then
      start_time := now;

      for burst_idx in 0 to 100 loop
        run_test_burst(fixed_length_words=>10);
      end loop;
      wait_until_done;

      time_diff := now - start_time;

      -- Latency in the input queue, through the module, and the output queue. Hence the margin.
      check_relation(time_diff < (100 * 10 + 13) * clk_period);

    end if;

    test_runner_cleanup(runner);
  end process;


  ------------------------------------------------------------------------------
  input_block : block
    signal data_is_valid : std_logic := '0';
    signal input_keep_byte : std_logic_vector(input_data'length / 8 - 1 downto 0) :=
      (others => '0');
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
        if enabled("test_full_throughput") then
          -- Only full words
          num_atoms_this_word := atoms_per_word;
        else
          -- Random number of atoms per word, which result in strobing
          num_atoms_this_word := rnd.RandInt(0, atoms_per_word);
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

        wait until (input_ready and input_valid) = '1' and rising_edge(clk);

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
        logger_name_suffix => "_input",
        data_width => input_data'length
      )
      port map (
        clk => clk,
        --
        data_is_valid => data_is_valid,
        --
        ready => input_ready,
        valid => input_valid,
        last => input_last,
        data => input_data
      );

  end block;


  ------------------------------------------------------------------------------
  axi_stream_slave_inst : entity bfm.axi_stream_slave
    generic map (
      data_width_bits => output_data'length,
      reference_data_queue => reference_data_queue,
      stall_config => stall_config,
      logger_name_suffix => "_output",
      remove_strobed_out_dont_care => true,
      strobe_unit_width_bits => output_data'length / output_strobe'length
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
      num_bursts_checked => num_output_bursts_checked
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
