-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the hdl-modules project, a collection of reusable, high-quality,
-- peer-reviewed VHDL building blocks.
-- https://hdl-modules.com
-- https://github.com/hdl-modules/hdl-modules
-- -------------------------------------------------------------------------------------------------
-- Generic interrupt register for producing a sticky interrupt bit.
--
-- Each bit in ``status`` is raised, and kept high, if the corresponding bit in ``sources``
-- is ever ``'1'``. A ``status`` bit is cleared to zero if the corresponding
-- ``clear`` bit is ever asserted.
--
-- The ``trigger`` pin is asserted if any bit is ``'1'`` in both ``status`` and ``mask``.
-- I.e. ``status`` always shows the sticky interrupt value, but the ``trigger`` pin is only asserted
-- if the bit is also ``mask`` ed.
--
-- Clearing all asserted ``status`` bits, or ``mask`` ing out all bits, will also clear ``trigger``.
-- -------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library reg_file;
use reg_file.reg_file_pkg.all;


entity interrupt_register is
  port (
    clk : in std_ulogic;
    --# {{}}
    sources : in reg_t := (others => '0');
    mask : in reg_t := (others => '1');
    clear : in reg_t := (others => '0');
    --# {{}}
    status : out reg_t := (others => '0');
    trigger : out std_ulogic := '0'
  );
end entity;

architecture a of interrupt_register is
begin

  ------------------------------------------------------------------------------
  main : process
    variable status_next : reg_t := (others => '0');
  begin
    wait until rising_edge(clk);

    for idx in sources'range loop
      if clear(idx) then
        status_next(idx) := '0';
      elsif sources(idx) then
        status_next(idx) := '1';
      else
        status_next(idx) := status(idx);
      end if;
    end loop;

    trigger <= or (status_next and mask);

    status <= status_next;
  end process;

end architecture;
