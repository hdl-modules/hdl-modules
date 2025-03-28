-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the hdl-modules project, a collection of reusable, high-quality,
-- peer-reviewed VHDL building blocks.
-- https://hdl-modules.com
-- https://github.com/hdl-modules/hdl-modules
-- -------------------------------------------------------------------------------------------------
-- Package with functions to simulate and check the DMA functionality.
-- -------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

library osvvm;
use osvvm.RandomPkg.RandomPType;

library vunit_lib;
use vunit_lib.check_pkg.all;
use vunit_lib.com_types_pkg.network_t;
use vunit_lib.integer_array_pkg.all;
use vunit_lib.memory_pkg.all;
use vunit_lib.queue_pkg.all;

library common;
use common.addr_pkg.all;

use work.dma_axi_write_simple_regs_pkg.all;
use work.dma_axi_write_simple_register_read_write_pkg.all;


package dma_axi_write_simple_sim_pkg is

  -- Run a test where the data written to memory by the DUT is pushed byte-by-byte to a queue.
  -- No verification of data is done, so that must be done outside of the procedure.
  procedure run_dma_axi_write_simple_test(
    rnd : inout RandomPType;
    signal net : inout network_t;
    constant receive_num_bytes : positive;
    constant receive_data_queue : queue_t;
    buffer_size_bytes : in positive;
    packet_length_bytes : in positive;
    memory : in memory_t;
    regs_base_address : in addr_t := (others => '0')
  );

  -- Run a test where the data written to memory by the DUT is verified byte-by-byte to
  -- reference data.
  procedure run_dma_axi_write_simple_test(
    rnd : inout RandomPType;
    signal net : inout network_t;
    reference_data : in integer_array_t;
    buffer_size_bytes : in positive;
    packet_length_bytes : in positive;
    memory : in memory_t;
    regs_base_address : in addr_t := (others => '0')
  );

end package;

package body dma_axi_write_simple_sim_pkg is

  procedure run_dma_axi_write_simple_test(
    rnd : inout RandomPType;
    signal net : inout network_t;
    constant receive_num_bytes : positive;
    constant receive_data_queue : queue_t;
    buffer_size_bytes : in positive;
    packet_length_bytes : in positive;
    memory : in memory_t;
    regs_base_address : in addr_t := (others => '0')
  ) is
    variable buf : buffer_t := null_buffer;

    variable written_address, read_address, num_bytes_pushed : natural := 0;
  begin
    buf := allocate(
      memory => memory,
      num_bytes => 3,
      name=>"padding so we start on non-zero address",
      permissions=>no_access
    );
    buf := allocate(
      memory => memory,
      num_bytes => buffer_size_bytes,
      name=>"dma_axi_write_simple_test_buffer",
      alignment=>packet_length_bytes,
      permissions=>write_only
    );

    write_dma_axi_write_simple_buffer_start_address(
      net=>net, value=>base_address(buf), base_address=>regs_base_address
    );
    write_dma_axi_write_simple_buffer_end_address(
      net=>net, value=>last_address(buf) + 1, base_address=>regs_base_address
    );
    write_dma_axi_write_simple_buffer_read_address(
      net=>net, value=>base_address(buf), base_address=>regs_base_address
    );
    read_address := base_address(buf);

    write_dma_axi_write_simple_config(
      net=>net, value=>(enable=>'1'), base_address=>regs_base_address
    );

    while num_bytes_pushed /= receive_num_bytes loop
      read_dma_axi_write_simple_buffer_written_address(
        net=>net, value=>written_address, base_address=>regs_base_address
      );

      while written_address /= read_address loop
        -- At a 12.5% probability, stop consuming before we have consumed all data that is
        -- actually available.
        -- Will result in writing back a 'read' address that is not equal to the 'written' address.
        if rnd.Uniform(1, 8) /= 8 then
          for memory_word_idx in 0 to packet_length_bytes - 1 loop
            push(receive_data_queue, read_byte(memory=>memory, address=>read_address));

            if read_address = last_address(buf) then
              read_address := base_address(buf);
            else
              read_address := read_address + 1;
            end if;
          end loop;

          num_bytes_pushed := num_bytes_pushed + packet_length_bytes;
        end if;
      end loop;

      -- Write the address for all data that has been consumed.
      -- Note that there is a possibility that we might not have consumed any data at all.
      write_dma_axi_write_simple_buffer_read_address(
        net=>net, value=>read_address, base_address=>regs_base_address
      );

      -- When debugging the module, the test code above can be quite dangerous and hard to analyze.
      -- Especially if the DUT is writing faulty addresses, there is a high chance that we end up
      -- in an endless loop and overflow the queue.
      -- When the simulator overflows like that, there is no wave file generated so it can not
      -- be debugged.
      -- In that case, the easiest solution to look at the waves is to comment out the loop
      -- and register write above, and instead use only the register write below.
      -- It will simply let all data be written to memory without checking/blocking anything.
      -- write_dma_axi_write_simple_buffer_read_address(
      --   net=>net, value=>written_address, base_address=>regs_base_address
      -- );
    end loop;
  end procedure;


  procedure run_dma_axi_write_simple_test(
    rnd : inout RandomPType;
    signal net : inout network_t;
    reference_data : in integer_array_t;
    buffer_size_bytes : in positive;
    packet_length_bytes : in positive;
    memory : in memory_t;
    regs_base_address : in addr_t := (others => '0')
  ) is
    constant receive_num_bytes : positive := length(reference_data);
    constant receive_data_queue : queue_t := new_queue;
  begin
    run_dma_axi_write_simple_test(
      rnd=>rnd,
      net=>net,
      receive_num_bytes=>receive_num_bytes,
      receive_data_queue=>receive_data_queue,
      buffer_size_bytes=>buffer_size_bytes,
      packet_length_bytes=>packet_length_bytes,
      memory=>memory,
      regs_base_address=>regs_base_address
    );

    for check_byte_idx in 0 to receive_num_bytes - 1 loop
      check_equal(
        pop_integer(receive_data_queue),
        get(arr=>reference_data, idx=>check_byte_idx),
        "check_byte_idx: "
        & to_string(check_byte_idx)
      );
    end loop;

    check_true(is_empty(receive_data_queue), "Got more data than expected");
  end procedure;

end package body;
