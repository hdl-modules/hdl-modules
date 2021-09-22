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
context vunit_lib.vunit_context;

library osvvm;
use osvvm.RandomPkg.all;

use work.types_pkg.all;


entity tb_width_conversion is
  generic (
    input_width : positive;
    output_width : positive;
    enable_strobe : boolean;
    support_unaligned_burst_length : boolean := false;
    data_jitter : boolean := true;
    runner_cfg : string
  );
end entity;

architecture tb of tb_width_conversion is

  constant input_bytes_per_beat : positive := input_width / 8;
  constant output_bytes_per_beat : positive := output_width / 8;

  signal clk : std_logic := '0';
  constant clk_period : time := 10 ns;

  signal input_ready, input_valid, input_last : std_logic := '0';
  signal output_ready, output_valid, output_last : std_logic := '0';

  signal input_data : std_logic_vector(input_width - 1 downto 0);
  signal output_data : std_logic_vector(output_width - 1 downto 0);

  constant strobe_unit_width : positive := 8;
  signal input_strobe : std_logic_vector(input_width / strobe_unit_width - 1 downto 0) :=
    (others => '0');
  signal output_strobe : std_logic_vector(output_width / strobe_unit_width - 1 downto 0) :=
    (others => '0');

  -- If there is strobing, there will be more words, but the amount of enabled bytes will be
  -- the same in the end.
  constant num_bytes_per_test : positive := 64;
  constant num_test_loops : positive := 100;

  signal num_stimuli_done, num_data_check_done : natural := 0;

  procedure random_slv(rnd : inout RandomPType; data : out std_logic_vector) is
    variable random_sl : std_logic_vector(0 downto 0);
  begin
    -- Build up a word from LSB to MSB, which corresponds to little endian when
    -- comparing wide words with packed thin words.
    for i in 0 to data'length - 1 loop
      random_sl := rnd.RandSlv(1);
      data(i) := random_sl(0);
    end loop;
  end procedure;

begin

  test_runner_watchdog(runner, 2 ms);
  clk <= not clk after clk_period / 2;


  ------------------------------------------------------------------------------
  main : process
    variable rnd : RandomPType;

    variable start_time, time_diff : time;

  constant num_input_words_when_no_strobing : positive := num_bytes_per_test / (input_width / 8);
  constant num_output_words_when_no_strobing : integer :=
    num_input_words_when_no_strobing * input_width / output_width;
  constant num_cycles_when_no_stall_and_no_strobing : integer :=
    maximum(num_input_words_when_no_strobing, num_output_words_when_no_strobing);

  begin
    test_runner_setup(runner, runner_cfg);
    rnd.InitSeed(rnd'instance_name);

    if run("test_data") then
      wait until
        num_stimuli_done = num_test_loops
        and num_data_check_done = num_test_loops
        and rising_edge(clk);

    elsif run("test_full_throughput") then
      start_time := now;
      wait until
        num_stimuli_done = num_test_loops
        and num_data_check_done = num_test_loops
        and rising_edge(clk);
      time_diff := now - start_time;

      check_relation(
        time_diff < (num_test_loops * num_cycles_when_no_stall_and_no_strobing + 2) * clk_period
      );
    end if;

    test_runner_cleanup(runner);
  end process;


  ------------------------------------------------------------------------------
  stimuli : process
    variable rnd_jitter, rnd_data : RandomPType;
    variable input_data_v : std_logic_vector(input_data'range);

    variable num_strobes_in_word : positive := input_bytes_per_beat;
    variable num_bytes_remaining : natural := 0;

    variable num_input_words_sent, num_padding_words : natural := 0;
  begin
    rnd_jitter.InitSeed("stimuli" & rnd_jitter'instance_name);
    rnd_data.InitSeed("rnd_data");

    while num_stimuli_done < num_test_loops loop
      num_bytes_remaining := num_bytes_per_test;
      num_input_words_sent := 0;

      while num_bytes_remaining > 0 loop
        if enable_strobe then
          num_strobes_in_word :=
            minimum(rnd_jitter.RandInt(1, input_bytes_per_beat), num_bytes_remaining);

          input_strobe <= (others => '0');
          input_strobe(num_strobes_in_word - 1 downto 0) <= (others => '1');

          -- Reset the data word to zero. Only the appropriate bytes will be assigned below.
          input_data_v := (others => '0');
        end if;

        random_slv(rnd_data, input_data_v(num_strobes_in_word * 8 - 1 downto 0));

        input_valid <= '1';

        input_data <= input_data_v;
        num_bytes_remaining := num_bytes_remaining - num_strobes_in_word;

        input_last <= to_sl(num_bytes_remaining = 0);
        wait until (input_ready and input_valid) = '1' and rising_edge(clk);
        num_input_words_sent := num_input_words_sent + 1;

        if data_jitter then
          input_valid <= '0';
          for wait_cycle in 1 to rnd_jitter.FavorSmall(0, 2) loop
            wait until rising_edge(clk);
          end loop;
        end if;
      end loop;

      if output_width > input_width and not support_unaligned_burst_length then
        -- Pad so that we send the input burst length is a multiple of the output data width.
        num_padding_words := num_input_words_sent mod (output_width / input_width);

        for padding_word_idx in 1 to num_padding_words loop
          input_valid <= '1';
          input_last <= '0';
          input_data <= (others => '0');
          input_strobe <= (others => '0');
          wait until (input_ready and input_valid) = '1' and rising_edge(clk);
        end loop;
      end if;

      input_valid <= '0';
      num_stimuli_done <= num_stimuli_done + 1;
    end loop;
  end process;


  ------------------------------------------------------------------------------
  data_check : process
    variable rnd_jitter, rnd_data : RandomPType;

    variable num_bytes_remaining : natural := 0;

    variable expected_byte : std_logic_vector(8 - 1 downto 0) := (others => '0');
  begin
    rnd_jitter.InitSeed("data_check" & rnd_jitter'instance_name);
    rnd_data.InitSeed("rnd_data");

    while num_data_check_done < num_test_loops loop
      num_bytes_remaining := num_bytes_per_test;

      while num_bytes_remaining > 0 loop
        output_ready <= '1';
        wait until (output_ready and output_valid) = '1' and rising_edge(clk);

        for byte_lane_idx in 0 to output_bytes_per_beat - 1 loop
          if (not enable_strobe) or output_strobe(byte_lane_idx) = '1' then
            -- Build up the expected output data vector in same way that input data
            -- is generated above. Note that the same random seed is used.
            random_slv(rnd_data, expected_byte);
            check_equal(
              output_data((byte_lane_idx + 1) * 8 - 1 downto byte_lane_idx * 8),
              expected_byte,
              "byte_lane_idx=" & to_string(byte_lane_idx)
              & ",num_bytes_remaining=" & to_string(num_bytes_remaining)
            );

            num_bytes_remaining := num_bytes_remaining - 1;
          end if;
        end loop;

        check_equal(
          output_last,
          to_sl(num_bytes_remaining = 0),
          "num_bytes_remaining=" & to_string(num_bytes_remaining)
        );

        if data_jitter then
          output_ready <= '0';
          for wait_cycle in 1 to rnd_jitter.FavorSmall(0, 2) loop
            wait until rising_edge(clk);
          end loop;
        end if;
      end loop;

      output_ready <= '0';
      num_data_check_done <= num_data_check_done + 1;
    end loop;
  end process;


  ------------------------------------------------------------------------------
  dut : entity work.width_conversion
    generic map (
      input_width => input_width,
      output_width => output_width,
      enable_strobe => enable_strobe,
      strobe_unit_width => strobe_unit_width,
      support_unaligned_burst_length => support_unaligned_burst_length
    )
    port map (
      clk => clk,
      --
      input_ready => input_ready,
      input_valid => input_valid,
      input_last => input_last,
      input_data => input_data,
      input_strobe => input_strobe,
      --
      output_ready => output_ready,
      output_valid => output_valid,
      output_last => output_last,
      output_data => output_data,
      output_strobe => output_strobe
    );

end architecture;
