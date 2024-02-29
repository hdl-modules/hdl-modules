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

library vunit_lib;
use vunit_lib.check_pkg.all;
use vunit_lib.run_pkg.all;

use work.lfsr_pkg.all;


entity tb_lfsr_pkg is
  generic (
    runner_cfg : string
  );
end entity;

architecture tb of tb_lfsr_pkg is

begin

  ------------------------------------------------------------------------------
  main : process
    constant taps5 : std_ulogic_vector(5 downto 1) := "10100";
    constant taps13 : std_ulogic_vector(13 downto 1) := "1000000001101";
    constant taps24 : std_ulogic_vector(24 downto 1) := "111000010000000000000000";
    constant taps59 : std_ulogic_vector(59 downto 1) := (
      "11000000000000000000011000000000000000000000000000000000000"
    );
  begin
    test_runner_setup(runner, runner_cfg);

    if run("test_get_taps_for_a_few_lengths") then
      check_equal(get_lfsr_taps(5), taps5);
      check_equal(get_lfsr_taps(13), taps13);
      check_equal(get_lfsr_taps(24), taps24);
      check_equal(get_lfsr_taps(59), taps59);

    end if;

    test_runner_cleanup(runner);
  end process;

end architecture;
