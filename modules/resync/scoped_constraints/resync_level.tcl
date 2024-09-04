# --------------------------------------------------------------------------------------------------
# Copyright (c) Lukas Vik. All rights reserved.
#
# This file is part of the hdl-modules project, a collection of reusable, high-quality,
# peer-reviewed VHDL building blocks.
# https://hdl-modules.com
# https://github.com/hdl-modules/hdl-modules
# --------------------------------------------------------------------------------------------------
# See this article for background and discussion about these constraints:
# https://www.linkedin.com/pulse/reliable-cdc-constraints-1-lukas-vik-copcf/
# Also AMD document UG903 provides some background.
#
# See the file 'resync_pulse.tcl' for background on
# * Why we find the minimum period in such a clunky way.
# * Why we use 'set_max_delay' with the '-datapath_only' flag.
# --------------------------------------------------------------------------------------------------

set clk_in [get_clocks -quiet -of_objects [get_ports "clk_in"]]
set clk_out [get_clocks -quiet -of_objects [get_ports "clk_out"]]
set first_resync_register [get_cells "data_in_p1_reg"]

if {${clk_in} != "" && ${clk_out} != ""} {
  # If we have both clocks we can set a max delay constraint in order
  # to get deterministic delay through the resync block.
  set clk_in_period [get_property "PERIOD" ${clk_in}]
  set clk_out_period [get_property "PERIOD" ${clk_out}]
  set min_period [expr {min(${clk_in_period}, ${clk_out_period})}]

  puts "INFO hdl-modules resync_level.tcl: Using clk_in period: ${clk_in_period}."
  puts "INFO hdl-modules resync_level.tcl: Using clk_out period: ${clk_out_period}."
  puts "INFO hdl-modules resync_level.tcl: Using calculated max delay: ${min_period}."

  # A more elegant way of deriving the driver of the input to the CDC would be to use e.g.
  #   set timing_path [lindex [get_timing_paths -to "${first_resync_register}/D" -nworst 1] 0]
  #   set clk_in [get_property "STARTPOINT_CLOCK" ${timing_path}]
  #   set data_in_driver [get_property "STARTPOINT_PIN" ${timing_path}]
  # There some examples of this on Xilinx website.
  # This way we could use the 'set_max_delay' constraint even when the user does not assign the
  # 'clk_in' port, by programmatically finding the driver of the net.
  # However, the 'get_timing_paths' command does not seem to work at all when called from a
  # scoped constraint script.
  # It just gives a critical warning.
  # If we did this as a traditional TCL constraint script instead, it would work.
  # But that comes with it's drawbacks, namely it would be harder to find our cells in the
  # whole design hierarchy.
  set_max_delay -datapath_only -from ${clk_in} -to ${first_resync_register} ${min_period}
} else {
  # Could not find both clocks.
  # Could be that 'clk_in' is not connected, or the clocks have not been created yet.
  # See also 'resync_pulse.tcl' for some background on when this can happen.
  # In this case, fall back to simple false path constraint.
  puts "WARNING hdl-modules resync_level.tcl: Could not find both clocks."
  set_false_path -setup -hold -to ${first_resync_register}
}
