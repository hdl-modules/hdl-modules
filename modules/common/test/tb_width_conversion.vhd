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
use vunit_lib.check_pkg.all;
use vunit_lib.integer_array_pkg.all;
use vunit_lib.queue_pkg.all;
use vunit_lib.random_pkg.all;
use vunit_lib.run_pkg.all;

library bfm;
use bfm.stall_bfm_pkg.stall_configuration_t;

use work.types_pkg.all;
use work.width_conversion_pkg.all;


entity tb_width_conversion is
  generic (
    input_width : positive;
    output_width : positive;
    enable_strobe : boolean;
    enable_last : boolean;
    support_unaligned_packet_length : boolean := false;
    enable_jitter : boolean := true;
    seed : natural;
    runner_cfg : string
  );
end entity;

architecture tb of tb_width_conversion is

  -- Generic constants.
  constant input_bytes_per_beat : positive := input_width / 8;
  constant output_bytes_per_beat : positive := output_width / 8;

  constant minimum_width_bytes : positive := minimum(input_bytes_per_beat, output_bytes_per_beat);
  constant maximum_width_bytes : positive := maximum(input_bytes_per_beat, output_bytes_per_beat);

  shared variable rnd : RandomPType;

  impure function get_user_width return natural is
  begin
    -- This is the first function that is called, so we initialize the random number generator here.
    rnd.InitSeed(seed);

    return 8 * rnd.Uniform(0, 2);
  end function;
  constant user_width : natural := get_user_width;
  constant input_user_width_bytes : natural := user_width / 8;

  constant output_user_width : natural := width_conversion_output_user_width(
    input_user_width=>user_width, input_data_width=>input_width, output_data_width=>output_width
  );

  -- AXI-Stream master and slave only support strobe widths that are a multiple of 8.
  constant strobe_unit_width : positive := 8;

  -- DUT connections.
  signal clk : std_ulogic := '0';
  constant clk_period : time := 10 ns;

  signal input_ready, input_valid, input_last : std_ulogic := '0';
  signal input_data : std_ulogic_vector(input_width - 1 downto 0) := (others => '0');
  signal input_strobe : std_ulogic_vector(input_width / strobe_unit_width - 1 downto 0) := (
    others => '0'
  );
  signal input_user : std_ulogic_vector(user_width - 1 downto 0) := (others => '0');

  signal output_ready, output_valid, output_last : std_ulogic := '0';
  signal output_data : std_ulogic_vector(output_width - 1 downto 0) := (others => '0');
  signal output_strobe : std_ulogic_vector(output_width / strobe_unit_width - 1 downto 0) := (
    others => '0'
  );
  signal output_user : std_ulogic_vector(output_user_width - 1 downto 0) := (others => '0');


  -- Testbench stuff.
  constant input_data_queue, input_user_queue : queue_t := new_queue;
  constant output_data_queue, output_user_queue : queue_t := new_queue;

  constant stall_config : stall_configuration_t := (
    stall_probability => 0.2 * to_real(enable_jitter),
    min_stall_cycles => 1,
    max_stall_cycles => 4
  );

  signal num_output_packets_checked : natural := 0;

begin

  test_runner_watchdog(runner, 200 us);
  clk <= not clk after clk_period / 2;


  ------------------------------------------------------------------------------
  main : process
    variable num_output_packets_expected : natural := 0;

    procedure run_test(fixed_length_bytes : natural := 0) is
      variable packet_length_bytes : positive := 1;
      variable num_input_bytes_to_remove : natural := 0;

      procedure setup_user is
        impure function downsizing_user_output(
          user_input : integer_array_t
        ) return integer_array_t is
          constant width_ratio : natural := input_width / output_width;
          -- Number of beats. May or may not be fully strobed.
          constant packet_length_output_beats : positive := (
            (packet_length_bytes + output_bytes_per_beat - 1) / output_bytes_per_beat
          );

          variable input_beat_idx : natural := 0;

          variable result : integer_array_t := new_1d(
            length=>packet_length_output_beats * input_user_width_bytes,
            bit_width=>8,
            is_signed=>false
          );
        begin
          -- This is more complicated than a simple "duplicate" operation since
          -- when we are unaligned, the input beat might not be fully strobed, so the number of
          -- output beats is variable.
          for output_beat_idx in 0 to packet_length_output_beats - 1 loop
            input_beat_idx := output_beat_idx / width_ratio;

            for user_byte_idx in 0 to input_user_width_bytes - 1 loop
              set(
                arr=>result,
                idx=>output_beat_idx * input_user_width_bytes + user_byte_idx,
                value=>get(
                  arr=>user_input, idx=>input_beat_idx * input_user_width_bytes + user_byte_idx
                )
              );
            end loop;
          end loop;

          return result;
        end function;

        -- Number of beats. May or may not be fully strobed.
        constant packet_length_input_beats : positive := (
          (packet_length_bytes + input_bytes_per_beat - 1) / input_bytes_per_beat
        );
        -- Number of 'user' bytes to send.
        variable input_user_length_bytes : positive := (
          packet_length_input_beats * input_user_width_bytes
        );

        variable user_in, user_out : integer_array_t := null_integer_array;
      begin
        random_integer_array(
          rnd=>rnd,
          integer_array=>user_in,
          width=>input_user_length_bytes,
          bits_per_word=>8,
          is_signed=>false
        );

        if input_width < output_width then
          -- Each input beat will arrive on the output side as an atom.
          user_out := copy(user_in);
        else
          -- The user value from one input beat will be spread out over multiple output beats.
          user_out := downsizing_user_output(user_input=>user_in);
        end if;

        push_ref(input_user_queue, user_in);
        push_ref(output_user_queue, user_out);
      end procedure;

      variable data_in, data_out : integer_array_t := null_integer_array;
    begin
      if fixed_length_bytes /= 0 then
        packet_length_bytes := fixed_length_bytes;

      else
        -- Set a random length that will fill up whole input and output words
        packet_length_bytes := rnd.RandInt(1, 5) * maximum_width_bytes;

        if support_unaligned_packet_length then
          -- In this case we can un-strobe/remove more than a whole word.
          -- If upsizing, and we remove more than one whole input word, the entity will pad.
          -- If downsizing, and we remove more than one whole output word, the entity
          -- will strip.
          num_input_bytes_to_remove := rnd.RandInt(0, maximum_width_bytes - 1);

        elsif enable_strobe then
          -- Un-strobe a number of byte lanes on the last input beat.
          -- We must still be aligned in terms of number of output beats.
          num_input_bytes_to_remove := rnd.RandInt(0, minimum_width_bytes - 1);
        end if;

        packet_length_bytes := maximum(1, packet_length_bytes - num_input_bytes_to_remove);
      end if;

      random_integer_array(
        rnd => rnd,
        integer_array => data_in,
        width => packet_length_bytes,
        bits_per_word => 8,
        is_signed => false
      );
      data_out := copy(data_in);

      push_ref(input_data_queue, data_in);
      push_ref(output_data_queue, data_out);

      if user_width > 0 then
        setup_user;
      end if;

      num_output_packets_expected := num_output_packets_expected + 1;
    end procedure;

    variable start_time, time_diff : time;

    constant full_throughput_num_bytes : positive := maximum_width_bytes * 100 * 10;

    constant full_throughput_num_input_beats : positive :=
      full_throughput_num_bytes / input_bytes_per_beat;
    constant full_throughput_num_output_beats : positive :=
      full_throughput_num_bytes / output_bytes_per_beat;

    constant full_throughput_num_cycles : positive :=
      maximum(full_throughput_num_input_beats, full_throughput_num_output_beats);

    procedure wait_until_done is
    begin
      wait until
        is_empty(input_data_queue)
        and is_empty(output_data_queue)
        and num_output_packets_checked = num_output_packets_expected
        and rising_edge(clk);
      wait until rising_edge(clk);
    end procedure;

  begin
    test_runner_setup(runner, runner_cfg);

    -- Print the randomized generics.
    report "user_width = " & to_string(user_width);

    if run("test_data") then
      for idx in 0 to 100 loop
        run_test;
      end loop;

      wait_until_done;

    elsif run("test_full_throughput") then
      start_time := now;

      for idx in 0 to 10 - 1 loop
        run_test(fixed_length_bytes=>full_throughput_num_bytes / 10);
      end loop;
      wait_until_done;

      time_diff := now - start_time;
      check_relation(
        time_diff < (full_throughput_num_cycles + 4) * clk_period
      );
    end if;

    test_runner_cleanup(runner);
  end process;


  ------------------------------------------------------------------------------
  axi_stream_master_inst : entity bfm.axi_stream_master
    generic map (
      data_width => input_data'length,
      data_queue => input_data_queue,
      user_width => input_user'length,
      user_queue => input_user_queue,
      stall_config => stall_config,
      seed => seed,
      logger_name_suffix => " - input",
      strobe_unit_width => input_data'length / input_strobe'length
    )
    port map (
      clk => clk,
      --
      ready => input_ready,
      valid => input_valid,
      last => input_last,
      data => input_data,
      strobe => input_strobe,
      user => input_user
    );


  ------------------------------------------------------------------------------
  output_block : block
    signal strobe : std_ulogic_vector(output_strobe'range) := (others => '0');
  begin

    strobe <= output_strobe when enable_strobe else (others => '1');


    ------------------------------------------------------------------------------
    axi_stream_slave_inst : entity bfm.axi_stream_slave
      generic map (
        data_width => output_data'length,
        reference_data_queue => output_data_queue,
        user_width => output_user'length,
        reference_user_queue => output_user_queue,
        stall_config => stall_config,
        seed => seed,
        logger_name_suffix => " - output",
        disable_last_check => not enable_last
      )
      port map (
        clk => clk,
        --
        ready => output_ready,
        valid => output_valid,
        last => output_last,
        data => output_data,
        strobe => strobe,
        user => output_user,
        --
        num_packets_checked => num_output_packets_checked
      );

  end block;


  ------------------------------------------------------------------------------
  dut : entity work.width_conversion
    generic map (
      input_width => input_width,
      output_width => output_width,
      enable_last => enable_last,
      enable_strobe => enable_strobe,
      strobe_unit_width => strobe_unit_width,
      user_width => user_width,
      support_unaligned_packet_length => support_unaligned_packet_length
    )
    port map (
      clk => clk,
      --
      input_ready => input_ready,
      input_valid => input_valid,
      input_last => input_last and enable_last,
      input_data => input_data,
      input_strobe => input_strobe,
      input_user => input_user,
      --
      output_ready => output_ready,
      output_valid => output_valid,
      output_last => output_last,
      output_data => output_data,
      output_strobe => output_strobe,
      output_user => output_user
    );

end architecture;
