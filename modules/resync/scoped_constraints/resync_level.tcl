# --------------------------------------------------------------------------------------------------
# Copyright (c) Lukas Vik. All rights reserved.
#
# This file is part of the hdl-modules project, a collection of reusable, high-quality,
# peer-reviewed VHDL building blocks.
# https://hdl-modules.com
# https://github.com/hdl-modules/hdl-modules
# --------------------------------------------------------------------------------------------------

set clk_in [get_clocks -of_objects [get_ports clk_in]]
set clk_out [get_clocks -of_objects [get_ports clk_out]]
set first_resync_register [get_cells data_in_p1_reg]

if {${clk_in} != "" && ${clk_out} != ""} {
  # If we have both clocks we can set a max delay constraint in order
  # to get deterministic delay through the resync block.
  set max_delay [get_property PERIOD ${clk_out}]
  puts "INFO tsfpga resync_level.tcl: Using calculated value ${max_delay} for constraint."

  # The recommend way, according to 'set_max_delay -help', is to use '-datapath_only' when
  # constraining asynchronous clock domain crossings.
  # This removes any clock pessimism from the delay calculation, though, which means that in reality
  # the delay can be slightly greater than one clock cycle.
  # But without this flag, it works in most cases but command failure has been observed in some
  # other, non-trivial, cases.
  # Typically happens when a derived clock or a clock from an IP core is used.
  # Hence we use the flag.
  #
  # A more elegant way of deriving the driver of the input to the CDC would be to use e.g.
  #   set timing_path [lindex [get_timing_paths -to "${first_resync_register}/D" -nworst 1] 0]
  #   set clk_in [get_property STARTPOINT_CLOCK ${timing_path}]
  #   set data_in_driver [get_property STARTPOINT_PIN ${timing_path}]
  # There some examples of this on Xilinx website.
  # This way we could use the 'set_max_delay' constraint even when the user does not assign the
  # 'clk_in' port, by programmatically finding the driver of the net.
  # However, the 'get_timing_paths' command does not seem to work at all when called from a
  # scoped constraint script.
  # It just gives a critical warning.
  # If we did this as a traditional TCL constraint script instead, it would work.
  # But that comes with it's drawbacks, namely it would be harder to find our cells in the
  # whole design hierarchy.
  set_max_delay -datapath_only -from ${clk_in} -to ${first_resync_register} ${max_delay}
} else {
  # Could not find both clocks.
  # Could be that 'clk_in' is not connected, or the clocks have not been created yet.
  # In this case, fall back to simple false path constraint.
  puts "WARNING tsfpga resync_level.tcl: Could not find both clocks. Setting false path constraint."
  set_false_path -setup -hold -to ${first_resync_register}
}
