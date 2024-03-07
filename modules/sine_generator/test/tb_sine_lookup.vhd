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

library vunit_lib;
use vunit_lib.run_pkg.all;

library bfm;

library common;
use common.types_pkg.all;


entity tb_sine_lookup is
  generic (
    memory_address_width : positive;
    memory_data_width : positive;
    runner_cfg : string
  );
end entity;

architecture tb of tb_sine_lookup is

  -- Generic constants.
  constant phase_width : positive := memory_address_width + 2;
  constant result_width : positive := memory_data_width + 1;

  -- DUT connections.
  signal clk : std_logic := '0';

  signal input_valid, result_valid : std_ulogic := '0';
  signal input_phase : u_unsigned(phase_width - 1 downto 0) := (others => '0');
  signal result_sine, result_cosine, result_minus_sine, result_minus_cosine : u_signed(
    result_width - 1 downto 0
  ) := (others => '0');

begin

  clk <= not clk after 5 ns;

  test_runner_watchdog(runner, 1 ms);


  ------------------------------------------------------------------------------
  main : process
    type file_handle_t is file of integer;
    file sine_handle, cosine_handle, minus_sine_handle, minus_cosine_handle : file_handle_t;
  begin
    test_runner_setup(runner, runner_cfg);

    file_open(
      f=>sine_handle, external_name=>output_path(runner_cfg) & "sine.raw", open_kind=>write_mode
    );
    file_open(
      f=>cosine_handle, external_name=>output_path(runner_cfg) & "cosine.raw", open_kind=>write_mode
    );
    file_open(
      f=>minus_sine_handle,
      external_name=>output_path(runner_cfg) & "minus_sine.raw",
      open_kind=>write_mode
    );
    file_open(
      f=>minus_cosine_handle,
      external_name=>output_path(runner_cfg) & "minus_cosine.raw",
      open_kind=>write_mode
    );

    for sample_idx in 0 to 2 ** input_phase'length - 1 loop
      wait until result_valid and rising_edge(clk);

      write(f=>sine_handle, value=>to_integer(result_sine));
      write(f=>cosine_handle, value=>to_integer(result_cosine));
      write(f=>minus_sine_handle, value=>to_integer(result_minus_sine));
      write(f=>minus_cosine_handle, value=>to_integer(result_minus_cosine));
    end loop;

    file_close(f=>sine_handle);
    file_close(f=>cosine_handle);
    file_close(f=>minus_sine_handle);
    file_close(f=>minus_cosine_handle);

    test_runner_cleanup(runner);
  end process;


  ------------------------------------------------------------------------------
  count_phase : process
  begin
    wait until rising_edge(clk);

    input_phase <= input_phase + to_int(input_valid);
  end process;


  ------------------------------------------------------------------------------
  handshake_master_inst : entity bfm.handshake_master
    generic map (
      stall_config => (
        stall_probability => 0.05,
        min_stall_cycles => 1,
        max_stall_cycles => 4
      )
    )
    port map (
      clk => clk,
      --
      data_is_valid => '1',
      --
      ready => '1',
      valid => input_valid
    );


  ------------------------------------------------------------------------------
  dut : entity work.sine_lookup
    generic map (
      memory_data_width => memory_data_width,
      memory_address_width => memory_address_width,
      enable_sine => true,
      enable_cosine => true,
      enable_minus_sine => true,
      enable_minus_cosine => true
    )
    port map (
      clk => clk,
      --
      input_valid => input_valid,
      input_phase => input_phase,
      --
      result_valid => result_valid,
      result_sine => result_sine,
      result_cosine => result_cosine,
      result_minus_sine => result_minus_sine,
      result_minus_cosine => result_minus_cosine
    );

end architecture;
