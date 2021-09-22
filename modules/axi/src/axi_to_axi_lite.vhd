-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the tsfpga project.
-- https://tsfpga.com
-- https://gitlab.com/tsfpga/tsfpga
-- -------------------------------------------------------------------------------------------------
-- Convert AXI transfers to AXI-Lite transfers.
--
-- This module does not handle conversion of non-well behaved AXI transfers.
-- Burst length has to be one and size must be the width of the bus. If these
-- conditions are not met, the read/write response will signal SLVERR.
--
-- This module will throttle the AXI bus so that there is never more that one
-- outstanding transaction (read and write separate). While the AXI-Lite standard
-- does allow for outstanding bursts, some Xilinx cores, namely the PCIe DMA bridge
-- does not play well with it.
-- -------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library common;
use common.types_pkg.all;

library math;
use math.math_pkg.all;

use work.axi_pkg.all;
use work.axi_lite_pkg.all;


entity axi_to_axi_lite is
  generic (
    data_width : integer
  );
  port (
    clk : in std_logic;

    axi_m2s : in axi_m2s_t := axi_m2s_init;
    axi_s2m : out axi_s2m_t := axi_s2m_init;

    axi_lite_m2s : out axi_lite_m2s_t := axi_lite_m2s_init;
    axi_lite_s2m : in axi_lite_s2m_t := axi_lite_s2m_init
  );
end entity;

architecture a of axi_to_axi_lite is

  constant len : integer := 0;
  constant size : integer := log2(data_width / 8);

  signal read_id, write_id : unsigned(axi_m2s.read.ar.id'range) := (others => '0');

  subtype data_rng is integer range data_width - 1 downto 0;
  subtype strb_rng is integer range data_width / 8 - 1 downto 0;

  signal read_error, write_error : boolean := false;

  signal ar_done, aw_done, w_done : std_logic := '0';

begin

  ------------------------------------------------------------------------------
  axi_lite_m2s.read.ar.valid <= axi_m2s.read.ar.valid and not ar_done;
  axi_lite_m2s.read.ar.addr <= axi_m2s.read.ar.addr;

  axi_s2m.read.ar.ready <= axi_lite_s2m.read.ar.ready and not ar_done;

  axi_lite_m2s.read.r.ready <= axi_m2s.read.r.ready;

  axi_s2m.read.r.valid <= axi_lite_s2m.read.r.valid;
  axi_s2m.read.r.id <= read_id;
  axi_s2m.read.r.data(data_rng) <= axi_lite_s2m.read.r.data(data_rng);
  axi_s2m.read.r.resp <= axi_resp_slverr when read_error else axi_lite_s2m.read.r.resp;
  axi_s2m.read.r.last <= '1';


  ------------------------------------------------------------------------------
  axi_lite_m2s.write.aw.valid <= axi_m2s.write.aw.valid and not aw_done;
  axi_lite_m2s.write.aw.addr <= axi_m2s.write.aw.addr;

  axi_s2m.write.aw.ready <= axi_lite_s2m.write.aw.ready and not aw_done;

  axi_lite_m2s.write.w.valid <= axi_m2s.write.w.valid and not w_done;
  axi_lite_m2s.write.w.data(data_rng) <= axi_m2s.write.w.data(data_rng);
  axi_lite_m2s.write.w.strb(strb_rng) <= axi_m2s.write.w.strb(strb_rng);

  axi_s2m.write.w.ready <= axi_lite_s2m.write.w.ready and not w_done;


  ------------------------------------------------------------------------------
  axi_lite_m2s.write.b.ready <= axi_m2s.write.b.ready;

  axi_s2m.write.b.valid <= axi_lite_s2m.write.b.valid;
  axi_s2m.write.b.id <= write_id;
  axi_s2m.write.b.resp <= axi_resp_slverr when write_error else axi_lite_s2m.write.b.resp;


  ------------------------------------------------------------------------------
  mirror_id : process
  begin
    wait until rising_edge(clk);

    -- Save the ID's so they can be returned in the read/write response transaction.

    if axi_s2m.read.ar.ready and axi_m2s.read.ar.valid then
      read_id <= axi_m2s.read.ar.id;
      ar_done <= '1';
    end if;

    if axi_m2s.read.r.ready and axi_s2m.read.r.valid then
      ar_done <= '0';
    end if;

    if axi_s2m.write.aw.ready and axi_m2s.write.aw.valid then
      write_id <= axi_m2s.write.aw.id;
      aw_done <= '1';
    end if;

    if axi_s2m.write.w.ready and axi_m2s.write.w.valid then
      w_done <= '1';
    end if;

    if axi_m2s.write.b.ready and axi_s2m.write.b.valid then
      aw_done <= '0';
      w_done <= '0';
    end if;
  end process;


  ------------------------------------------------------------------------------
  check_for_bus_error : process
  begin
    wait until rising_edge(clk);

    -- If an error occurs the bus will return an error. The bus will be unlocked for any
    -- upcoming transactions, if the SW can handle it.

    if axi_m2s.write.aw.valid and axi_s2m.write.aw.ready then
      if to_integer(unsigned(axi_m2s.write.aw.len)) /= len or to_integer(unsigned(axi_m2s.write.aw.size)) /= size then
        write_error <= true;
      else
        write_error <= false;
      end if;
    end if;

    if axi_m2s.read.ar.valid and axi_s2m.read.ar.ready then
      if to_integer(unsigned(axi_m2s.read.ar.len)) /= len or to_integer(unsigned(axi_m2s.read.ar.size)) /= size then
        read_error <= true;
      else
        read_error <= false;
      end if;
    end if;
  end process;

end architecture;
