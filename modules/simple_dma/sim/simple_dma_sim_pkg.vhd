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

library vunit_lib;
use vunit_lib.check_pkg.all;
use vunit_lib.com_types_pkg.network_t;
use vunit_lib.integer_array_pkg.all;
use vunit_lib.memory_pkg.all;

library common;
use common.addr_pkg.all;

use work.simple_dma_regs_pkg.all;
use work.simple_dma_register_read_write_pkg.all;


package simple_dma_sim_pkg is

  procedure run_simple_dma_test(
    signal net : inout network_t;
    reference_data : in integer_array_t;
    buffer_size_bytes : in positive;
    buffer_alignment : in positive;
    memory : in memory_t;
    regs_base_address : in addr_t := (others => '0')
  );

end package;

package body simple_dma_sim_pkg is

  procedure run_simple_dma_test(
    signal net : inout network_t;
    reference_data : in integer_array_t;
    buffer_size_bytes : in positive;
    buffer_alignment : in positive;
    memory : in memory_t;
    regs_base_address : in addr_t := (others => '0')
  ) is
    variable buf : buffer_t := null_buffer;
    constant test_data_num_bytes : positive := length(reference_data);

    variable write_address, read_address, num_bytes_checked : natural := 0;
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
      name=>"simple_dma_test_buffer",
      alignment=>buffer_alignment,
      permissions=>write_only
    );

    write_simple_dma_buffer_start_address(
      net=>net, value=>base_address(buf), base_address=>regs_base_address
    );
    write_simple_dma_buffer_end_address(
      net=>net, value=>last_address(buf) + 1, base_address=>regs_base_address
    );
    write_simple_dma_buffer_read_address(
      net=>net, value=>base_address(buf), base_address=>regs_base_address
    );
    read_address := base_address(buf);

    write_simple_dma_config(net=>net, value=>(enable=>'1'), base_address=>regs_base_address);

    while num_bytes_checked /= test_data_num_bytes loop
      read_simple_dma_buffer_written_address(
        net=>net, value=>write_address, base_address=>regs_base_address
      );

      while write_address /= read_address loop
        check_equal(
          read_byte(memory=>memory, address=>read_address),
          get(arr=>reference_data, idx=>num_bytes_checked),
          "num_bytes_checked: "
          & to_string(num_bytes_checked)
          & ", read_address: " & to_string(read_address)
        );

        num_bytes_checked := num_bytes_checked + 1;

        if read_address = last_address(buf) then
          read_address := base_address(buf);
        else
          read_address := read_address + 1;
        end if;
      end loop;

      write_simple_dma_buffer_read_address(
        net=>net, value=>read_address, base_address=>regs_base_address
      );
    end loop;
  end procedure;

end package body;
