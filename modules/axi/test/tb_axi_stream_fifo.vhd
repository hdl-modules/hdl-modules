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
use vunit_lib.memory_pkg.all;
context vunit_lib.vunit_context;
context vunit_lib.vc_context;

library osvvm;
use osvvm.RandomPkg.all;

use work.axi_stream_pkg.all;


entity tb_axi_stream_fifo is
  generic (
    depth : natural;
    asynchronous : boolean := false;
    runner_cfg : string
  );
end entity;

architecture tb of tb_axi_stream_fifo is

  constant data_width : integer := 32;
  constant user_width : integer := 16;

  constant clk_fast_period : time := 3 ns;
  constant clk_slow_period : time := 7 ns;

  signal clk_input, clk_output : std_logic := '0';

  signal input_m2s, output_m2s : axi_stream_m2s_t := axi_stream_m2s_init;
  signal input_s2m, output_s2m : axi_stream_s2m_t := axi_stream_s2m_init;

begin

  test_runner_watchdog(runner, 1 ms);

  clk_input_gen : if asynchronous generate
    clk_input <= not clk_input after clk_slow_period / 2;
    clk_output <= not clk_output after clk_fast_period / 2;
  else generate
    clk_input <= not clk_input after clk_fast_period / 2;
    clk_output <= not clk_output after clk_fast_period / 2;
  end generate;

  ------------------------------------------------------------------------------
  main : process
    variable rnd : RandomPType;
    variable data : std_logic_vector(data_width - 1 downto 0);
    variable user : std_logic_vector(user_width - 1 downto 0);
  begin
    test_runner_setup(runner, runner_cfg);
    rnd.InitSeed(rnd'instance_name);

    if run("test_single_transaction") then
      data := rnd.RandSlv(data'length);
      user := rnd.RandSlv(user'length);

      input_m2s.data(data'range) <= data;
      input_m2s.user(user'range) <= user;
      input_m2s.valid <= '1';

      wait until rising_edge(clk_input) and input_s2m.ready = '1';
      input_m2s.valid <= '0';
      output_s2m.ready <= '1';

      wait until rising_edge(clk_output) and output_m2s.valid = '1';
      check_equal(output_m2s.data(data'range), data);
      check_equal(output_m2s.user(user'range), user);

    end if;

    test_runner_cleanup(runner);
  end process;

  ------------------------------------------------------------------------------
  axi_stream_fifo_inst : entity work.axi_stream_fifo
    generic map (
      data_width => data_width,
      user_width => user_width,
      asynchronous => asynchronous,
      depth => depth
    )
    port map (
      clk => clk_input,
      --
      input_m2s => input_m2s,
      input_s2m => input_s2m,
      --
      output_m2s => output_m2s,
      output_s2m => output_s2m,
      --
      clk_output => clk_output
    );

end architecture;
