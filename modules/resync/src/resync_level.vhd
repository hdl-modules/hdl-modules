-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the tsfpga project.
-- https://tsfpga.com
-- https://gitlab.com/tsfpga/tsfpga
-- -------------------------------------------------------------------------------------------------
-- Resync a single bit from one clock domain to another.
--
-- The two registers will be placed in the same slice, in order to minimize
-- MTBF. This guarantees proper resynchronization of semi static "level" type
-- signals without meta stability on rising/falling edges. It can not handle
-- "pulse" type signals. Pulses can be missed and single-cycle pulse behaviour
-- will not work.
--
-- The clk_in port does not necessarily have to be set. But if you want to have
-- a deterministic latency through the resync block (via a set_max_delay
-- constraint) it has to be set. If not, a simple set_false_path constraint will
-- be used and the latency can be arbitrary, depending on the placer/router.
--
-- There is an option to include a register on the input side before the async_reg flip-flop chain.
-- This option is to prevent sampling of data when the input is in a transient "glitch" state, which
-- can occur if it is driven by a LUT as opposed to a flip-flop. If the input is already driven by
-- a flip-flop, you can safely set the generic to 'false' in order to save resources.
-- Note that this is a separate issue from meta-stability.
-- When this option is enabled, the 'clk_in' port must be driven with the correct clock.
--
-- Some motivation why this is needed:
-- While LUTs are designed to be glitch-free in order to save switching power, this can only be
-- achieved as long as only one LUT input value changes state. (See e.g. this thread:
-- https://forums.xilinx.com/t5/Other-FPGA-Architecture/Interior-switching-of-LUT5-SRAM/td-p/835012)
-- When more than one input changes state per clock cycle, glitches will almost ceratinly appear on
-- the LUT output before reaching its steady state.
-- This is partly due to difference in propagation delay between the inputs, and partly due to
-- the electrical structure of a LUT. In a regular synchronous design, the Vivado timing engine
-- guarantees that all these glitches have been resolved and LUT output has reached its
-- steady state before the value is sampled by a FF. When the value is fed to our async_reg FF
-- chain however there is no control over this, and we may very well sample an erroneous
-- glitch value.
-- So given this knowledge the rule of thumb is to always drive resync_level input by a FF.
-- However since LUTs are glitch-free in some scenarios, exceptions can be made if we are sure
-- of what we are doing. For example if the value is inverted in a LUT before being fed to
-- resync_level, then that is a scenario where we do not actually need the extra FF.
-- -------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

library common;
use common.attribute_pkg.all;


entity resync_level is
  generic (
    -- Enable or disable a register on the input side before the async_reg flip-flip chain.
    -- Must be used if the input can contain glitches. See header for more details.
    -- The 'clk_in' port must be assigned if this generic is set to 'true'.
    enable_input_register : boolean;
    -- Initial value for the ouput that will be set for a few cycles before the first input
    -- value has propagated.
    default_value : std_logic := '0'
  );
  port (
    clk_in : in std_logic := '-';
    data_in : in std_logic;

    clk_out : in std_logic;
    data_out : out std_logic
  );
end entity;

architecture a of resync_level is
  signal data_in_int, data_in_p1, data_out_int : std_logic := default_value;

  attribute async_reg of data_in_p1 : signal is "true";
  attribute async_reg of data_out_int : signal is "true";
begin

  -- This check will trigger in simulation, but will probably not work in synthesis
  assert clk_in /= '-' or not enable_input_register
    report "Must assign clock when using input register"
    severity failure;

  data_out <= data_out_int;


  ------------------------------------------------------------------------------
  assign_input : if enable_input_register generate

    ------------------------------------------------------------------------------
    input_register : process
    begin
      wait until rising_edge(clk_in);

      data_in_int <= data_in;
    end process;

  else generate

    data_in_int <= data_in;

  end generate;


  ------------------------------------------------------------------------------
  main : process
  begin
    wait until rising_edge(clk_out);
    data_out_int <= data_in_p1;
    data_in_p1 <= data_in_int;
  end process;

end architecture;
