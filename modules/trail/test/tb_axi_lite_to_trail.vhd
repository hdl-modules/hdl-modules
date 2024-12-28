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
use vunit_lib.axi_lite_master_pkg.all;
use vunit_lib.bus_master_pkg.all;
use vunit_lib.check_pkg.all;
use vunit_lib.com_pkg.net;
use vunit_lib.queue_pkg.all;
use vunit_lib.run_pkg.all;

library axi;
use axi.axi_pkg.all;

library axi_lite;
use axi_lite.axi_lite_pkg.all;

library bfm;
use bfm.stall_bfm_pkg.all;

library common;
use common.types_pkg.all;

use work.trail_pkg.all;
use work.trail_sim_pkg.all;


entity tb_axi_lite_to_trail is
  generic (
    address_width : trail_address_width_t;
    data_width : trail_data_width_t;
    seed : natural;
    runner_cfg : string
  );
end entity;

architecture tb of tb_axi_lite_to_trail is

  -- DUT connections.
  signal clk : std_ulogic := '0';

  signal axi_lite_m2s : axi_lite_m2s_t := axi_lite_m2s_init;
  signal axi_lite_s2m : axi_lite_s2m_t := axi_lite_s2m_init;

  signal trail_operation : trail_operation_t := trail_operation_init;
  signal trail_response : trail_response_t := trail_response_init;

  -- Testbench stuff.
  constant axi_lite_master : bus_master_t := new_bus(
    data_length => data_width,
    address_length => address_width
  );

  constant stall_config : stall_configuration_t := (
    stall_probability=>0.2, min_stall_cycles=>1, max_stall_cycles=>10
  );

  constant trail_command_queue : queue_t := new_queue;

  signal num_processed : natural := 0;

begin

  clk <= not clk after 5 ns;
  test_runner_watchdog(runner, 100 us);


  ------------------------------------------------------------------------------
  main : process

    variable rnd : RandomPType;

    variable num_trail_expected : natural := 0;

    procedure test_random_transactions is
      constant write_enable : boolean := rnd.RandBool;
      variable address : u_unsigned(address_width - 1 downto 0) := (others => '0');
      variable data : std_ulogic_vector(data_width - 1 downto 0) := rnd.RandSlv(data_width);

      constant insert_address_error : boolean := rnd.DistBool(Weight=>(false=>9, true=>1));
      constant insert_strobe_error : boolean := (
        write_enable and rnd.DistBool(Weight=>(false=>9, true=>1))
      );
      constant insert_trail_error : boolean := rnd.DistBool(Weight=>(false=>9, true=>1));

      constant any_axi_error : boolean := insert_address_error or insert_strobe_error;
      constant any_error : boolean := any_axi_error or insert_trail_error;

      variable trail_command : trail_bfm_command_t := trail_bfm_command_init;
      variable strobe : std_ulogic_vector(data_width / 8 - 1 downto 0) := (others => '1');
      variable expected_response : axi_resp_t := axi_resp_okay;
    begin
      get_random_trail_address(
        address_width=>address_width, data_width=>data_width, rnd=>rnd, address=>address
      );

      trail_command.write_enable := to_sl(write_enable);
      trail_command.address(address'range) := address;
      trail_command.data(data'range) := data;
      trail_command.expect_error := to_sl(insert_trail_error);

      if not any_axi_error then
        push(trail_command_queue, to_slv(trail_command));
        num_trail_expected := num_trail_expected + 1;
      end if;

      if insert_address_error then
        address := address + 1;
      end if;

      if insert_strobe_error then
        strobe(0) := '0';
      end if;

      if any_error then
        expected_response := axi_resp_slverr;
      end if;

      if write_enable then
        -- Call is non-blocking. I.e. we will build up a queue of writes.
        write_axi_lite(
          net=>net,
          bus_handle=>axi_lite_master,
          address=>std_ulogic_vector(address(address_width - 1 downto 0)),
          data=>data,
          expected_bresp=>expected_response,
          byte_enable=>strobe
        );
      else
        read_axi_lite(
          net=>net,
          bus_handle=>axi_lite_master,
          address=>std_ulogic_vector(address(address_width - 1 downto 0)),
          data=>data,
          expected_rresp=>expected_response
        );

        if not any_error then
          check_equal(data, trail_command.data(data'range));
        end if;
      end if;
    end procedure;

  begin
    test_runner_setup(runner, runner_cfg);

    if run("test_random_transactions") then
      for idx in 0 to 100 - 1 loop
        test_random_transactions;
      end loop;

      wait until num_processed = num_trail_expected and rising_edge(clk);
    end if;

    test_runner_cleanup(runner);
  end process;


  ------------------------------------------------------------------------------
  axi_lite_master_inst : entity bfm.axi_lite_master
    generic map (
      bus_handle => axi_lite_master
    )
    port map (
      clk => clk,
      --
      axi_lite_m2s => axi_lite_m2s,
      axi_lite_s2m => axi_lite_s2m
    );


  ------------------------------------------------------------------------------
  trail_bfm_slave_inst : entity work.trail_bfm_slave
    generic map (
      address_width => address_width,
      data_width => data_width,
      command_queue => trail_command_queue,
      stall_config => stall_config,
      seed => seed
    )
    port map (
      clk => clk,
      --
      trail_operation => trail_operation,
      trail_response => trail_response,
      --
      num_processed => num_processed
    );


  ------------------------------------------------------------------------------
  dut : entity work.axi_lite_to_trail
    generic map (
      address_width => address_width,
      data_width => data_width
    )
    port map (
      clk => clk,
      --
      axi_lite_m2s => axi_lite_m2s,
      axi_lite_s2m => axi_lite_s2m,
      --
      trail_operation => trail_operation,
      trail_response => trail_response
    );

end architecture;
