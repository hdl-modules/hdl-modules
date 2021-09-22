-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the tsfpga project.
-- https://tsfpga.com
-- https://gitlab.com/tsfpga/tsfpga
-- -------------------------------------------------------------------------------------------------
-- Measure the switching rate of an unknown clock by using a freerunning reference clock of
-- known frequency.
--
-- The frequency of target_clock is given by
--   target_tick_count * reference_clock_frequency / 2 ** resolution_bits
--
-- The target_tick_count value is updated every 2 ** resolution_bits cycles. It is invalid for
-- 2 * 2 ** resolution_bits cycles in the beginning as reference_clock starts switching,
-- but after that it is always valid.
--
-- For the calculation to work, target_clock must be no more than 2 ** (max_relation_bits - 1) times
-- faster than reference_clock.
-- -------------------------------------------------------------------------------------------------

library ieee;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;

library math;
use math.math_pkg.all;

library resync;


entity clock_counter is
  generic (
    resolution_bits : positive;
    max_relation_bits : positive;
    -- The shift register length is device specific.
    -- For Xilinx ultrascale and 7 series devices, it should be set to 32
    shift_register_length : integer := 32
  );
  port (
    target_clock : in std_logic;
    --
    reference_clock : in std_logic;
    target_tick_count : out unsigned(resolution_bits + max_relation_bits - 1 downto 0) :=
      (others => '0')
  );
end entity;

architecture a of clock_counter is

  signal tick_count, tick_count_resync, tick_count_resync_previous :
    unsigned(target_tick_count'range) := (others => '0');

  signal reference_tick : std_logic := '0';

begin

  ------------------------------------------------------------------------------
  increment : process
  begin
    wait until rising_edge(target_clock);
    tick_count <= tick_count + 1;
  end process;


  ------------------------------------------------------------------------------
  resync_counter_inst : entity resync.resync_counter
    generic map (
      width => tick_count'length
    )
    port map (
      clk_in => target_clock,
      counter_in => tick_count,
      --
      clk_out => reference_clock,
      counter_out => tick_count_resync
    );


  ------------------------------------------------------------------------------
  periodic_pulse_inst : entity work.periodic_pulser
    generic map (
      period => 2 ** resolution_bits,
      shift_register_length => shift_register_length
    )
    port map (
      clk => reference_clock,
      count_enable => '1',
      pulse => reference_tick
    );


  ------------------------------------------------------------------------------
  assign_result : process
  begin
    wait until rising_edge(reference_clock);

    if reference_tick then
      target_tick_count <= tick_count_resync - tick_count_resync_previous;
      tick_count_resync_previous <= tick_count_resync;
    end if;
  end process;

end architecture;
