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

library osvvm;
use osvvm.RandomPkg.RandomPType;

library common;
use common.types_pkg.all;

use work.lfsr_pkg.all;


entity tb_lfsr is
  generic (
    output_width : positive;
    desired_lfsr_length : positive;
    seed : natural;
    runner_cfg : string
  );
end entity;

architecture tb of tb_lfsr is

  shared variable rnd : RandomPType;

  -- Generic constants
  constant calculated_lfsr_length : positive := get_required_lfsr_length(
    shift_count=>output_width, minimum_length=>desired_lfsr_length
  );

  impure function get_lfsr_seed return std_ulogic_vector is
    constant all_zeros : std_ulogic_vector(calculated_lfsr_length downto 1) := (others => '0');

    variable result : std_ulogic_vector(all_zeros'range) := all_zeros;
  begin
    -- This is the first function that is called, so we initialize the random number
    -- generator here.
    rnd.InitSeed(seed);

    while result = all_zeros loop
      result := rnd.RandSlv(result'length);
    end loop;

    return result;
  end function;
  constant lfsr_seed : std_ulogic_vector(calculated_lfsr_length downto 1) := get_lfsr_seed;

  -- DUT connections.
  signal clk : std_logic := '0';

  -- Change the bit indexes here, but does not really matter.
  -- We are testing for the randomness and uniqueness of words, so the bit indexes themselves
  -- are not important.
  signal output : std_ulogic_vector(output_width - 1 downto 0) := (others => '0');

  -- Testbench stuff.
  constant clk_period : time := 5 ns;

  constant num_unique_lfsr_states : positive := 2 ** calculated_lfsr_length - 1;
  constant num_samples : positive := num_unique_lfsr_states;

begin

  clk <= not clk after clk_period / 2;

  test_runner_watchdog(runner, (num_samples + 20) * clk_period);


  ------------------------------------------------------------------------------
  main : process
    type file_handle_t is file of integer;
    file file_handle : file_handle_t;
  begin
    test_runner_setup(runner, runner_cfg);

    report "lfsr_seed = " & to_string(lfsr_seed);

    if output_width = 1 then
      assert calculated_lfsr_length = desired_lfsr_length;
    else
      assert calculated_lfsr_length > output_width;
    end if;

    file_open(
      f=>file_handle,
      external_name=>output_path(runner_cfg) & "simulation_data.raw",
      open_kind=>write_mode
    );

    for sample_idx in 0 to num_samples - 1 loop
      wait until rising_edge(clk);
      write(f=>file_handle, value=>to_integer(unsigned(output)));
    end loop;

    file_close(f=>file_handle);

    test_runner_cleanup(runner);
  end process;


  ------------------------------------------------------------------------------
  dut_gen : if output'length = 1 generate

    ------------------------------------------------------------------------------
    dut : entity work.lfsr_fibonacci_single
      generic map (
        lfsr_length => desired_lfsr_length,
        seed => lfsr_seed
      )
      port map (
        clk => clk,
        --
        output => output(0)
      );

  else generate

    ------------------------------------------------------------------------------
    dut : entity work.lfsr_fibonacci_multi
      generic map (
        output_width => output_width,
        seed => lfsr_seed
      )
      port map (
        clk => clk,
        --
        output => output
      );

  end generate;

end architecture;
