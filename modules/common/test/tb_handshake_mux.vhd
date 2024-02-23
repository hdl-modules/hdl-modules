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
use bfm.queue_bfm_pkg.get_new_queues;

use work.types_pkg.all;


entity tb_handshake_mux is
  generic (
    seed : natural;
    runner_cfg : string
  );
end entity;

architecture tb of tb_handshake_mux is

  -- Generics
  constant data_width : positive := 32;
  constant bytes_per_beat : positive := data_width / 8;

  constant num_inputs : positive := 4;

  -- DUT connections
  signal clk : std_ulogic := '0';
  constant clk_period : time := 10 ns;

  signal input_ready, input_valid, input_last : std_ulogic_vector(0 to num_inputs - 1) :=
    (others => '0');
  signal input_data : slv_vec_t(input_valid'range)(data_width - 1 downto 0) :=
    (others => (others => '0'));
  signal input_strobe : slv_vec_t(input_valid'range)(data_width / 8 - 1 downto 0) :=
    (others => (others => '0'));

  signal result_ready, result_valid, result_last : std_ulogic := '0';
  signal result_data : std_ulogic_vector(data_width - 1 downto 0) := (others => '0');
  signal result_strobe : std_ulogic_vector(data_width / 8 - 1 downto 0) := (others => '0');
  signal result_id : natural range input_valid'range := 0;

  -- Testbench stuff
  constant stall_config : stall_configuration_t := (
    stall_probability => 0.2,
    min_stall_cycles => 1,
    max_stall_cycles => 3
  );

  constant input_data_queues, data_reference_queues : queue_vec_t(
    input_valid'range
  ) := get_new_queues(input_valid'length);

  signal num_packets_checked : natural_vec_t(input_valid'range) := (others => 0);

begin

  test_runner_watchdog(runner, 100 us);
  clk <= not clk after clk_period / 2;


  ------------------------------------------------------------------------------
  main : process
    variable rnd : RandomPType;

    variable num_tests : natural_vec_t(input_valid'range) := (others => 0);

    procedure send_random is
      constant input_idx : natural := rnd.Uniform(0, input_valid'high);

      constant packet_length_bytes : natural := rnd.Uniform(1, 5 * bytes_per_beat);

      variable data, data_copy : integer_array_t := null_integer_array;
    begin
      random_integer_array(
        rnd => rnd,
        integer_array => data,
        width => packet_length_bytes,
        bits_per_word => 8,
        is_signed => false
      );
      data_copy := copy(data);

      push_ref(input_data_queues(input_idx), data);
      push_ref(data_reference_queues(input_idx), data_copy);

      num_tests(input_idx) := num_tests(input_idx) + 1;
    end procedure;

  begin
    test_runner_setup(runner, runner_cfg);
    rnd.InitSeed(seed);

    if run("test_random_data") then
      for test_idx in 0 to 50 loop
        send_random;
      end loop;
    end if;

    wait until num_packets_checked = num_tests and rising_edge(clk);

    test_runner_cleanup(runner);
  end process;


  ------------------------------------------------------------------------------
  bfm_block : block
    signal bfm_result_ready, bfm_result_valid : std_ulogic_vector(input_valid'range) :=
      (others => '0');
  begin

    ------------------------------------------------------------------------------
    bfm_gen : for input_idx in input_valid'range generate

      ------------------------------------------------------------------------------
      axi_stream_master_inst : entity bfm.axi_stream_master
        generic map (
          data_width => input_data(input_idx)'length,
          data_queue => input_data_queues(input_idx),
          stall_config => stall_config,
          seed => seed,
          logger_name_suffix => " - input #" & to_string(input_idx)
        )
        port map (
          clk => clk,
          --
          ready => input_ready(input_idx),
          valid => input_valid(input_idx),
          last => input_last(input_idx),
          data => input_data(input_idx),
          strobe => input_strobe(input_idx)
        );


      ------------------------------------------------------------------------------
      axi_stream_slave_inst : entity bfm.axi_stream_slave
        generic map (
          data_width => result_data'length,
          reference_data_queue => data_reference_queues(input_idx),
          stall_config => stall_config,
          seed => seed,
          logger_name_suffix => " - result"
        )
        port map (
          clk => clk,
          --
          ready => bfm_result_ready(input_idx),
          valid => bfm_result_valid(input_idx),
          last => result_last,
          data => result_data,
          strobe => result_strobe,
          --
          num_packets_checked => num_packets_checked(input_idx)
        );

    end generate;


    ------------------------------------------------------------------------------
    -- Assign handshaking signals to/from the BFM that corresponds to the result ID.
    -- Due to the arbitration we do not know in what order the input packets will be passed on.
    -- Hence there must be one reference queue for each input.
    assign_handshake : process(all)
    begin
      result_ready <= bfm_result_ready(result_id);

      bfm_result_valid <= (others => '0');
      bfm_result_valid(result_id) <= result_valid;
    end process;

  end block;


  ------------------------------------------------------------------------------
  dut : entity work.handshake_mux
    generic map(
      data_width => data_width,
      num_inputs => num_inputs
    )
    port map(
      clk => clk,
      --
      input_ready => input_ready,
      input_valid => input_valid,
      input_last => input_last,
      input_data => input_data,
      input_strobe => input_strobe,
      --
      result_ready => result_ready,
      result_valid => result_valid,
      result_last => result_last,
      result_data => result_data,
      result_strobe => result_strobe,
      result_id => result_id
    );

end architecture;
