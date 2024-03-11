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
use common.time_pkg.to_period;
use common.types_pkg.all;

use work.sine_generator_pkg.all;


entity tb_sine_generator is
  generic (
    clk_frequency_hz : positive;
    sine_frequency_hz : positive;
    memory_address_width : positive;
    phase_fractional_width : natural := 0;
    enable_sine : boolean := true;
    enable_cosine : boolean := false;
    enable_phase_dithering : boolean;
    enable_first_order_taylor : boolean;
    num_samples : positive;
    runner_cfg : string
  );
end entity;

architecture tb of tb_sine_generator is

  -- Generic constants.
  constant memory_data_width : positive := 18 + 13 * to_int(enable_first_order_taylor) ;

  -- DUT connections.
  signal clk : std_logic := '0';

  signal input_valid, result_valid : std_ulogic := '0';

  constant phase_width : positive := get_phase_width(
    memory_address_width=>memory_address_width, phase_fractional_width=>phase_fractional_width
  );
  signal input_phase_increment : u_unsigned(phase_width - 1 downto 0) := get_phase_increment(
    clk_frequency_hz => clk_frequency_hz,
    sine_frequency_hz => sine_frequency_hz,
    phase_width => phase_width
  );

  signal result_sine, result_cosine : u_signed(memory_data_width + 1 - 1 downto 0) := (
    others => '0'
  );

  -- Testbench stuff.
  constant clk_period : time := to_period(frequency_hz=>clk_frequency_hz);

begin

  clk <= not clk after clk_period / 2;

  test_runner_watchdog(runner, 10 ms);


  ------------------------------------------------------------------------------
  main : process
    type file_handle_t is file of integer;
    file sine_file_handle, cosine_file_handle : file_handle_t;
  begin
    test_runner_setup(runner, runner_cfg);

    report "input_phase_increment = " & to_string(input_phase_increment);

    if enable_sine then
      file_open(
        f=>sine_file_handle,
        external_name=>output_path(runner_cfg) & "sine.raw",
        open_kind=>write_mode
      );
    end if;
    if enable_cosine then
      file_open(
        f=>cosine_file_handle,
        external_name=>output_path(runner_cfg) & "cosine.raw",
        open_kind=>write_mode
      );
    end if;

    assert result_sine'length <= 32
      report "Can not cast to integer " & to_string(result_sine'length);

    for sample_idx in 0 to num_samples - 1 loop
      wait until result_valid and rising_edge(clk);

      if enable_sine then
        write(f=>sine_file_handle, value=>to_integer(result_sine));
      end if;
      if enable_cosine then
        write(f=>cosine_file_handle, value=>to_integer(result_cosine));
      end if;
    end loop;

    if enable_sine then
      file_close(f=>sine_file_handle);
    end if;
    if enable_cosine then
      file_close(f=>cosine_file_handle);
    end if;

    test_runner_cleanup(runner);
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
      valid => input_valid
    );


  ------------------------------------------------------------------------------
  dut : entity work.sine_generator
    generic map (
      memory_data_width => memory_data_width,
      memory_address_width => memory_address_width,
      phase_fractional_width => phase_fractional_width,
      enable_sine => enable_sine,
      enable_cosine => enable_cosine,
      enable_phase_dithering => enable_phase_dithering,
      enable_first_order_taylor => enable_first_order_taylor
    )
    port map (
      clk => clk,
      --
      input_valid => input_valid,
      input_phase_increment => input_phase_increment,
      --
      result_valid => result_valid,
      result_sine => result_sine,
      result_cosine => result_cosine
    );

end architecture;
