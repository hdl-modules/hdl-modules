-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the tsfpga project.
-- https://tsfpga.com
-- https://gitlab.com/tsfpga/tsfpga
-- -------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

library vunit_lib;
context vunit_lib.vunit_context;
context vunit_lib.vc_context;

library osvvm;
use osvvm.RandomPkg.all;

library common;

use work.types_pkg.all;


entity tb_handshake_splitter is
  generic (
    runner_cfg : string
  );
end entity;

architecture tb of tb_handshake_splitter is

  signal clk : std_logic := '0';
  constant clk_period : time := 10 ns;

  signal input_data : std_logic_vector(8 - 1 downto 0);
  signal input_ready, input_valid : std_logic := '0';
  signal output0_ready, output0_valid, output1_ready, output1_valid : std_logic := '0';

  constant num_words : integer := 2_000;

  constant axi_stream_master : axi_stream_master_t := new_axi_stream_master(
    data_length => input_data'length,
    protocol_checker => new_axi_stream_protocol_checker(
      logger => get_logger("axi_stream_master"), data_length => input_data'length));

  signal data_check0_done, data_check1_done : boolean := false;

  shared variable rnd : RandomPType;
  signal data_queue0 : queue_t := new_queue;
  signal data_queue1 : queue_t := new_queue;

begin

  test_runner_watchdog(runner, 1 ms);
  clk <= not clk after clk_period / 2;


  ------------------------------------------------------------------------------
  main : process
    variable data : std_logic_vector(input_data'range) := (others => '0');
    variable last_dummy : std_logic := '1';
  begin
    test_runner_setup(runner, runner_cfg);
    rnd.InitSeed(rnd'instance_name);

    if run("test_data") then
      for i in 1 to num_words loop
        data := rnd.RandSlv(data'length);
        push_axi_stream(net, axi_stream_master, tdata => data, tlast => last_dummy);
        push(data_queue0, data);
        push(data_queue1, data);
      end loop;
    end if;

    wait until data_check0_done and data_check1_done;

    test_runner_cleanup(runner);
  end process;


  ------------------------------------------------------------------------------
  data_check0 : process
    variable data : std_logic_vector(input_data'range) := (others => '0');
  begin
    for i in 1 to num_words loop
      output0_ready <= '1';
      wait until (output0_ready and output0_valid) = '1' and rising_edge(clk);
      output0_ready <= '0';

      data := pop(data_queue0);
      check_equal(input_data, data);

      for jitter in 1 to rnd.RandInt(2) loop
        wait until rising_edge(clk);
      end loop;
    end loop;

    assert is_empty(data_queue0);
    data_check0_done <= true;
    wait;
  end process;


  ------------------------------------------------------------------------------
  output0_axi_stream_protocol_checker_inst : entity common.axi_stream_protocol_checker
    generic map (
      data_width => input_data'length,
      logger_name_suffix => "_output0"
    )
    port map (
      clk => clk,
      --
      ready => output0_ready,
      valid => output0_valid,
      data => input_data
    );


  ------------------------------------------------------------------------------
  data_check1 : process
    variable data : std_logic_vector(input_data'range) := (others => '0');
  begin
    for i in 1 to num_words loop
      output1_ready <= '1';
      wait until (output1_ready and output1_valid) = '1' and rising_edge(clk);
      output1_ready <= '0';

      data := pop(data_queue1);
      check_equal(input_data, data);

      for jitter in 1 to rnd.RandInt(2) loop
        wait until rising_edge(clk);
      end loop;
    end loop;

    assert is_empty(data_queue1);
    data_check1_done <= true;
    wait;
  end process;


  ------------------------------------------------------------------------------
  output1_axi_stream_protocol_checker_inst : entity common.axi_stream_protocol_checker
    generic map (
      data_width => input_data'length,
      logger_name_suffix => "_output1"
    )
    port map (
      clk => clk,
      --
      ready => output1_ready,
      valid => output1_valid,
      data => input_data
    );


  ------------------------------------------------------------------------------
  axi_stream_master_inst : entity vunit_lib.axi_stream_master
  generic map(
    master => axi_stream_master
  )
  port map(
    aclk   => clk,
    tvalid => input_valid,
    tready => input_ready,
    tdata  => input_data
  );


  ------------------------------------------------------------------------------
  dut : entity work.handshake_splitter
    port map (
      clk => clk,
      --
      input_ready => input_ready,
      input_valid => input_valid,
      --
      output0_ready => output0_ready,
      output0_valid => output0_valid,
      --
      output1_ready => output1_ready,
      output1_valid => output1_valid
    );

end architecture;
