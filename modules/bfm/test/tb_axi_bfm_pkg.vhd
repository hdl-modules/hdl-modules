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

library osvvm;
use osvvm.RandomPkg.RandomPType;

library vunit_lib;
use vunit_lib.check_pkg.all;
use vunit_lib.run_pkg.all;

use work.axi_bfm_pkg.all;


entity tb_axi_bfm_pkg is
  generic (
    seed : natural;
    runner_cfg : string
  );
end entity;

architecture tb of tb_axi_bfm_pkg is

begin

  ------------------------------------------------------------------------------
  main : process

    variable rnd : RandomPType;

    variable job, job_converted : axi_master_bfm_job_t := axi_master_bfm_job_init;
    variable job_slv : std_ulogic_vector(axi_master_bfm_job_size - 1 downto 0) := (others => '0');

  begin
    test_runner_setup(runner, runner_cfg);
    rnd.InitSeed(seed);

    if run("test_axi_master_bfm_job_conversion") then
      job.address := rnd.RandInt(natural'high);
      job.length_bytes := rnd.RandInt(positive'low, positive'high);
      job.id := rnd.RandInt(natural'high);

      job_slv := to_slv(job);

      job_converted := to_axi_bfm_job(job_slv);

      assert job_converted = job;

    elsif run("test_byte_length_that_does_not_cross_4k") then
      check_equal(
        get_byte_length_that_does_not_cross_4k(address=>4090, length_bytes=>30),
        6
      );

      check_equal(
        get_byte_length_that_does_not_cross_4k(address=>8190, length_bytes=>30),
        2
      );

      check_equal(
        get_byte_length_that_does_not_cross_4k(address=>4096, length_bytes=>3),
        3
      );

    end if;

    test_runner_cleanup(runner);
  end process;

end architecture;
