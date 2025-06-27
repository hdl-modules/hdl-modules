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
use vunit_lib.integer_array_pkg.all;
use vunit_lib.queue_pkg.all;
use vunit_lib.run_pkg.all;

library axi;
use axi.axi_pkg.all;

library axi_lite;
use axi_lite.axi_lite_pkg.all;

library bfm;
use bfm.axi_bfm_pkg.all;
use bfm.axi_stream_bfm_pkg.all;
use bfm.stall_bfm_pkg.all;


library common;
use common.types_pkg.all;

use work.trail_pkg.all;
use work.trail_sim_pkg.all;


entity tb_axi_to_trail is
  generic (
    address_width : trail_address_width_t;
    data_width : trail_data_width_t;
    test_axi_lite : boolean;
    runner_cfg : string
  );
end entity;

architecture tb of tb_axi_to_trail is

  -- Generic constants.
  constant bytes_per_beat : positive := data_width / 8;
  constant axi_id_width : natural := 4;

  -- DUT connections.
  signal clk : std_ulogic := '0';

  signal trail_operation : trail_operation_t := trail_operation_init;
  signal trail_response : trail_response_t := trail_response_init;

  signal axi_m2s : axi_m2s_t := axi_m2s_init;
  signal axi_s2m : axi_s2m_t := axi_s2m_init;

  -- Testbench stuff.
  constant axi_lite_bus_master : bus_master_t := new_bus(
    data_length => data_width, address_length => address_width
  );

  constant stall_config : stall_configuration_t := (
    stall_probability=>0.2, min_stall_cycles=>1, max_stall_cycles=>10
  );

  constant axi_write_job_queue, axi_write_data_queue, axi_read_job_queue, axi_read_data_queue :
    queue_t := new_queue;

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
      -- constant insert_strobe_error : boolean := (
      --   write_enable and rnd.DistBool(Weight=>(false=>9, true=>1))
      -- );
      -- constant insert_trail_error : boolean := rnd.DistBool(Weight=>(false=>9, true=>1));

      constant insert_strobe_error : boolean := false;
      constant insert_trail_error : boolean := false;

      constant any_axi_error : boolean := insert_address_error or insert_strobe_error;
      constant any_error : boolean := any_axi_error or insert_trail_error;

      variable trail_command : trail_bfm_command_t := trail_bfm_command_init;
      variable axi_lite_strobe : std_ulogic_vector(data_width / 8 - 1 downto 0) := (others => '1');
      variable expected_response : axi_resp_t := axi_resp_okay;

      variable axi_job : axi_master_bfm_job_t := (
        length_bytes => bytes_per_beat, expected_response=>axi_resp_okay, others => 0
      );
      variable axi_byte : integer := 0;
      -- Use signed and one more byte so we can send the 'dont care' value.
      variable axi_data : integer_array_t := new_1d(
        length=>bytes_per_beat, bit_width=>9, is_signed=>false
      );
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

      if any_error then
        expected_response := axi_resp_slverr;
      end if;

      axi_job.address := to_integer(address);
      axi_job.id := rnd.Uniform(0, 2 ** axi_id_width - 1);
      axi_job.expected_response := expected_response;

      if test_axi_lite then
        if write_enable then
          if insert_strobe_error then
            axi_lite_strobe(0) := '0';
          end if;

          -- Call is non-blocking. I.e. we will build up a queue of writes.
          write_axi_lite(
            net=>net,
            bus_handle=>axi_lite_bus_master,
            address=>std_ulogic_vector(address(address_width - 1 downto 0)),
            data=>data,
            expected_bresp=>expected_response,
            byte_enable=>axi_lite_strobe
          );
        else
          read_axi_lite(
            net=>net,
            bus_handle=>axi_lite_bus_master,
            address=>std_ulogic_vector(address(address_width - 1 downto 0)),
            data=>data,
            expected_rresp=>expected_response
          );

          if not any_error then
            check_equal(data, trail_command.data(data'range));
          end if;
        end if;
      else
        for byte_idx in 0 to bytes_per_beat - 1 loop
          if any_error and not write_enable then
            axi_byte := axi_stream_bfm_dont_care;
          else
            axi_byte := to_integer(unsigned(data(byte_idx * 8 + 7 downto byte_idx * 8)));
          end if;

          set(arr=>axi_data, idx=>byte_idx, value=>axi_byte);
        end loop;

        if write_enable then
          push_std_ulogic_vector(axi_write_job_queue, to_slv(axi_job));
          push_ref(axi_write_data_queue, axi_data);

          wait until axi_s2m.write.aw.ready and axi_m2s.write.aw.valid and rising_edge(clk);
        else
          push_std_ulogic_vector(axi_read_job_queue, to_slv(axi_job));
          push_ref(axi_read_data_queue, axi_data);

          wait until axi_s2m.read.ar.ready and axi_m2s.read.ar.valid and rising_edge(clk);
        end if;
      end if;
    end procedure;

  begin
    test_runner_setup(runner, runner_cfg);

    if run("test_random_transactions") then
      for idx in 0 to 100 - 1 loop
        test_random_transactions;

        -- report "Waiting until num_trail_expected = " & to_string(num_trail_expected);
        -- wait until num_processed = num_trail_expected;
      end loop;

      report "Waiting for done";

      wait until num_processed = num_trail_expected and rising_edge(clk);
    end if;

    test_runner_cleanup(runner);
  end process;


  ------------------------------------------------------------------------------
  trail_bfm_slave_inst : entity work.trail_bfm_slave
    generic map (
      address_width => address_width,
      data_width => data_width,
      command_queue => trail_command_queue,
      stall_config => stall_config
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
  dut_gen : if test_axi_lite generate
    signal axi_lite_m2s : axi_lite_m2s_t := axi_lite_m2s_init;
    signal axi_lite_s2m : axi_lite_s2m_t := axi_lite_s2m_init;
  begin

    ------------------------------------------------------------------------------
    axi_lite_master_inst : entity bfm.axi_lite_master
      generic map (
        bus_handle => axi_lite_bus_master
      )
      port map (
        clk => clk,
        --
        axi_lite_m2s => axi_lite_m2s,
        axi_lite_s2m => axi_lite_s2m
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


  ------------------------------------------------------------------------------
  else generate

    ------------------------------------------------------------------------------
    axi_read_master_inst : entity bfm.axi_read_master
      generic map (
        id_width => axi_id_width,
        data_width => data_width,
        job_queue => axi_read_job_queue,
        reference_data_queue => axi_read_data_queue,
        ar_stall_config => stall_config,
        r_stall_config => stall_config
      )
      port map (
        clk => clk,
        --
        axi_read_m2s => axi_m2s.read,
        axi_read_s2m => axi_s2m.read
      );


    ------------------------------------------------------------------------------
    axi_write_master_inst : entity bfm.axi_write_master
      generic map (
        id_width => axi_id_width,
        data_width => data_width,
        job_queue => axi_write_job_queue,
        data_queue => axi_write_data_queue,
        aw_stall_config => stall_config,
        w_stall_config => stall_config,
        b_stall_config => stall_config
      )
      port map (
        clk => clk,
        --
        axi_write_m2s => axi_m2s.write,
        axi_write_s2m => axi_s2m.write
      );


    ------------------------------------------------------------------------------
    dut : entity work.axi_to_trail
      generic map (
        address_width => address_width,
        data_width => data_width,
        id_width => axi_id_width
      )
      port map (
        clk => clk,
        --
        axi_m2s => axi_m2s,
        axi_s2m => axi_s2m,
        --
        trail_operation => trail_operation,
        trail_response => trail_response
      );

  end generate;

end architecture;
