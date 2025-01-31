-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the hdl-modules project, a collection of reusable, high-quality,
-- peer-reviewed VHDL building blocks.
-- https://hdl-modules.com
-- https://github.com/hdl-modules/hdl-modules
-- -------------------------------------------------------------------------------------------------
-- Package with types and constants for :ref:`ring_buffer.ring_buffer_write_simple`.
-- -------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;


package ring_buffer_write_simple_pkg is

  type ring_buffer_write_simple_status_t is record
    idle : std_ulogic;
    start_address_unaligned : std_ulogic;
    end_address_unaligned : std_ulogic;
    read_address_unaligned : std_ulogic;
  end record;

  constant ring_buffer_write_simple_status_idle_no_error : ring_buffer_write_simple_status_t
    := (
    idle=>'1',
    start_address_unaligned=>'0',
    end_address_unaligned=>'0',
    read_address_unaligned=>'0'
  );

  constant ring_buffer_write_simple_status_busy_no_error : ring_buffer_write_simple_status_t
    := (
    idle=>'0',
    start_address_unaligned=>'0',
    end_address_unaligned=>'0',
    read_address_unaligned=>'0'
  );

end package;
