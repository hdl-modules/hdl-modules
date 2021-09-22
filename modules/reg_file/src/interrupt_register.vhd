-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the tsfpga project.
-- https://tsfpga.com
-- https://gitlab.com/tsfpga/tsfpga
-- -------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library reg_file;
use reg_file.reg_file_pkg.all;


entity interrupt_register is
  port (
    clk : in std_logic;

    sources : in reg_t := (others => '0');
    mask : in reg_t := (others => '1');
    clear : in reg_t := (others => '0');

    status : out reg_t := (others => '0');
    trigger : out std_logic := '0'
  );
end entity;

architecture a of interrupt_register is
begin

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
