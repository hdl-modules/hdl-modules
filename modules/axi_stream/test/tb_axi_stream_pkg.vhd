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
use vunit_lib.check_pkg.all;
use vunit_lib.run_pkg.all;

library osvvm;
use osvvm.RandomPkg.RandomPType;

use work.axi_stream_pkg.all;


entity tb_axi_stream_pkg is
  generic (
    data_width : positive range 1 to axi_stream_data_sz;
    user_width : natural range 0 to axi_stream_user_sz;
    runner_cfg : string
  );
end entity;

architecture tb of tb_axi_stream_pkg is
begin

  main : process
    variable rnd : RandomPType;

    procedure test_slv_conversion(iteration : natural) is
      constant offset_max : integer := 73;

      variable data : axi_stream_m2s_t := axi_stream_m2s_init;
      variable data_converted : std_ulogic_vector(
        axi_stream_m2s_sz(data_width=>data_width, user_width=>user_width) - 1 downto 0) :=
        (others => '0');
      variable data_slv : std_ulogic_vector(data_converted'high + offset_max downto 0) :=
        (others => '0');

      variable hi, lo : integer := 0;
    begin
      -- Slice slv input, to make sure that ranges don't have to be down to 0
      lo := iteration mod offset_max;

      hi := data_converted'high + lo;
      data_slv(hi downto lo) := rnd.RandSLV(data_converted'length);
      data := to_axi_stream_m2s(
        data_slv(hi downto lo),
        data_width=>data_width,
        user_width=>user_width,
        valid => '1');
      data_converted := to_slv(data, data_width=>data_width, user_width=>user_width);

      check_equal(data_converted, data_slv(hi downto lo));

    end procedure;

  begin
    test_runner_setup(runner, runner_cfg);
    rnd.InitSeed(rnd'instance_name);

    if run("test_slv_conversion") then

      for iteration in 0 to 1000 loop
        -- Loop a couple of times to get good random coverage
        test_slv_conversion(iteration);
      end loop;

    end if;

    test_runner_cleanup(runner);
  end process;

end architecture;
