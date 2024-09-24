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
use vunit_lib.check_pkg.all;
use vunit_lib.integer_array_pkg.all;
use vunit_lib.queue_pkg.all;
use vunit_lib.random_pkg.all;
use vunit_lib.run_pkg.all;

library bfm;
use bfm.stall_bfm_pkg.stall_configuration_t;

library common;
use common.types_pkg.all;

use work.simple_ring_buffer_manager_pkg.all;


entity tb_simple_ring_buffer_manager is
  generic (
    segment_length_bytes : positive;
    buffer_size_segments : positive;
    seed : natural;
    runner_cfg : string
  );
end entity;

architecture tb of tb_simple_ring_buffer_manager is

  -- Generic constants.
  constant address_width : positive := 32;

  shared variable rnd : RandomPType;
  constant buffer_size_bytes : positive := buffer_size_segments * segment_length_bytes;

  -- DUT connections.
  signal clk : std_ulogic := '0';
  constant clk_period : time := 10 ns;

  signal enable : std_ulogic := '0';

  signal buffer_start_address, buffer_end_address, buffer_written_address, buffer_read_address :
    u_unsigned(address_width - 1 downto 0) := (others => '0');

  signal segment_ready, segment_valid : std_ulogic := '0';
  signal segment_address : u_unsigned(address_width - 1 downto 0) := (others => '0');

  signal segment_written : std_ulogic := '0';

  signal status : simple_ring_buffer_manager_status_t := (
    simple_ring_buffer_manager_status_idle_no_error
  );

  -- Testbench stuff.
  signal num_served, num_written, num_processed : natural := 0;

begin

  test_runner_watchdog(runner, 2 ms);
  clk <= not clk after clk_period / 2;


  ------------------------------------------------------------------------------
  main : process
    variable start_address : natural := 0;

    procedure run_test is
      variable write_address, read_address : natural := 0;
      variable num_bytes, num_segments : natural := 0;
    begin
      -- Make the buffer loop around a number of times.
      while num_processed < 5 * buffer_size_segments loop
        wait until buffer_written_address /= buffer_read_address and rising_edge(clk);

        for wait_idx in 1 to rnd.Uniform(0, 20) loop
          wait until rising_edge(clk);
        end loop;

        write_address := to_integer(buffer_written_address);
        read_address := to_integer(buffer_read_address);

        num_bytes := (write_address - read_address) mod buffer_size_bytes;
        num_segments := num_bytes / segment_length_bytes;

        for segment_idx in 0 to num_segments - 1 loop
          read_address := read_address + segment_length_bytes;

          if read_address >= buffer_end_address then
            read_address := to_integer(buffer_start_address);
          end if;
        end loop;

        num_processed <= num_processed + num_segments;
        buffer_read_address <= to_unsigned(read_address, buffer_read_address'length);
      end loop;
    end procedure;

  begin
    test_runner_setup(runner, runner_cfg);
    rnd.InitSeed(seed);

    start_address := rnd.Uniform(0, 10) * segment_length_bytes;

    buffer_start_address <= to_unsigned(start_address, address_width);
    buffer_end_address <= to_unsigned(start_address + buffer_size_bytes, buffer_end_address'length);
    buffer_read_address <= to_unsigned(start_address, buffer_read_address'length);

    assert status = simple_ring_buffer_manager_status_idle_no_error;

    if run("test_random_addresses") then
      enable <= '1';
      wait until status = simple_ring_buffer_manager_status_busy_no_error and rising_edge(clk);

      run_test;

    elsif run("test_invalid_addresses") then
      assert segment_length_bytes > 1 report "can not be unaligned if length is one byte";

      buffer_start_address <= to_unsigned(3, address_width);
      wait until status = (
        idle=>'1',
        start_address_unaligned=>'1',
        end_address_unaligned=>'0',
        read_address_unaligned=>'0'
      ) and rising_edge(clk);

      buffer_end_address <= to_unsigned(2, address_width);
      wait until status = (
        idle=>'1',
        start_address_unaligned=>'1',
        end_address_unaligned=>'1',
        read_address_unaligned=>'0'
      ) and rising_edge(clk);

      buffer_read_address <= to_unsigned(3, address_width);
      wait until status = (
        idle=>'1',
        start_address_unaligned=>'1',
        end_address_unaligned=>'1',
        read_address_unaligned=>'1'
      ) and rising_edge(clk);

    end if;

    test_runner_cleanup(runner);
  end process;


  ------------------------------------------------------------------------------
  check_segment : process
    variable expected : natural := 0;
  begin
    wait until (segment_ready and segment_valid) = '1' and rising_edge(clk);

    expected := (
      to_integer(buffer_start_address)
      + (num_served mod buffer_size_segments) * segment_length_bytes
    );

    check_equal(segment_address, expected, "num_served: " & to_string(num_served));

    num_served <= num_served + 1;
  end process;


  ------------------------------------------------------------------------------
  process_segment : process
  begin
    wait until num_served /= num_written and rising_edge(clk);

    for wait_idx in 1 to rnd.Uniform(0, 20) loop
      wait until rising_edge(clk);
    end loop;

    segment_written <= '1';
    wait until rising_edge(clk);
    segment_written <= '0';

    num_written <= num_written + 1;
  end process;


  ------------------------------------------------------------------------------
  check_within_range : process
  begin
    wait until segment_valid = '1' and rising_edge(clk);

    check_relation(num_served >= num_written);
    check_relation(num_written >= num_processed);
    check_relation(
      num_served < num_processed + buffer_size_segments,
      "num_served: " & to_string(num_served) & ", num_written: " & to_string(num_written)
    );
  end process;


  ------------------------------------------------------------------------------
  handshake_slave_inst : entity bfm.handshake_slave
    generic map(
      stall_config => (
        stall_probability => 0.3,
        min_stall_cycles => 1,
        max_stall_cycles => 20
      ),
      seed => seed,
      logger_name_suffix => " - segment"
    )
    port map(
      clk => clk,
      --
      ready => segment_ready,
      valid => segment_valid
    );


  ------------------------------------------------------------------------------
  axi_stream_protocol_checker_inst : entity common.axi_stream_protocol_checker
    generic map (
      data_width => segment_address'length,
      logger_name_suffix => " - segment"
    )
    port map (
      clk => clk,
      --
      ready => segment_ready,
      valid => segment_valid,
      data => std_ulogic_vector(segment_address)
    );


  ------------------------------------------------------------------------------
  dut : entity work.simple_ring_buffer_manager
    generic map (
      address_width => address_width,
      segment_length_bytes => segment_length_bytes
    )
    port map (
      clk => clk,
      --
      enable => enable,
      --
      buffer_start_address => buffer_start_address,
      buffer_end_address => buffer_end_address,
      buffer_written_address => buffer_written_address,
      buffer_read_address => buffer_read_address,
      --
      segment_ready => segment_ready,
      segment_valid => segment_valid,
      segment_address => segment_address,
      --
      segment_written => segment_written,
      --
      status => status
    );

end architecture;
