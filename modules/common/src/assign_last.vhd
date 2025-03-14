-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the hdl-modules project, a collection of reusable, high-quality,
-- peer-reviewed VHDL building blocks.
-- https://hdl-modules.com
-- https://github.com/hdl-modules/hdl-modules
-- -------------------------------------------------------------------------------------------------
-- Calculate the ``last`` indicator for an AXI-Stream-like handshaking data flow.
-- Can be used to enable packet-based processing from a data source that does not provide
-- a ``last`` signal.
--
-- The packet length is specified at compile-time using the ``packet_length_beats`` generic.
-- ``last`` will be asserted every ``packet_length_beats``'th beat that passes.
--
-- This entity shall be instantiated in parallel with the data bus.
-- The ``ready`` and ``valid`` ports must be assigned combinatorially.
-- The ``last`` shall be assigned combinatorially alongside the ``ready`` and ``valid`` signals
-- that go towards the data sink.
--
-- .. note::
--   This entity also produces a ``first`` signal.
--   This is not part of the AXI-Stream specification, nor is it commonly used.
--   But it might be useful in some cases.
--   Feel free to ignore it.
-- -------------------------------------------------------------------------------------------------

library ieee;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;

library common;
use common.types_pkg.all;

library math;
use math.math_pkg.all;


entity assign_last is
  generic (
    packet_length_beats : positive;
    -- If you are using a device that can cheaply pack shift registers
    -- (such as the SRLs in AMD/Xilinx FPGAs), setting the shift register length here can
    -- drastically reduce the resource usage.
    -- For AMD/Xilinx 7-series and UltraScale(+) devices, it should be set to 33.
    shift_register_length : positive := 1
  );
  port (
    clk : in std_ulogic;
    --# {{}}
    ready : in std_ulogic;
    valid : in std_ulogic;
    last : out std_ulogic := '0';
    first : out std_ulogic := '1'
  );
end entity;

architecture a of assign_last is

  signal count_enable : std_ulogic := '0';

begin

  ------------------------------------------------------------------------------
  packet_length_gen : if packet_length_beats = 1 generate

    last <= '1';
    first <= '1';


  ------------------------------------------------------------------------------
  else generate

    ------------------------------------------------------------------------------
    main : process
    begin
      wait until rising_edge(clk);

      if count_enable then
        first <= last;
      end if;
    end process;

    count_enable <= ready and valid;


    ------------------------------------------------------------------------------
    periodic_pulser_inst : entity common.periodic_pulser
      generic map (
        period => packet_length_beats,
        shift_register_length => shift_register_length,
        widen_pulse_before => true
      )
      port map (
        clk => clk,
        --
        count_enable => count_enable,
        pulse => last
      );

  end generate;

end architecture;
