# --------------------------------------------------------------------------------------------------
# Copyright (c) Lukas Vik. All rights reserved.
#
# This file is part of the hdl-modules project, a collection of reusable, high-quality,
# peer-reviewed VHDL building blocks.
# https://hdl-modules.com
# https://github.com/hdl-modules/hdl-modules
# --------------------------------------------------------------------------------------------------

set clk_in [get_clocks -quiet -of_objects [get_ports "clk_in"]]
set clk_out [get_clocks -quiet -of_objects [get_ports "clk_out"]]

if {${clk_in} != ""} {
  set clk_in_period [get_property "PERIOD" ${clk_in}]
  puts "INFO hdl-modules resync_pulse.tcl: Using clk_in period: ${clk_in_period}."
} else {
  set clk_in_period 2
  puts "WARNING hdl-modules resync_pulse.tcl: Could not find clk_in."
}

if {${clk_out} != ""} {
  set clk_out_period [get_property "PERIOD" ${clk_out}]
  puts "INFO hdl-modules resync_pulse.tcl: Using clk_out period: ${clk_out_period}."
} else {
  set clk_out_period 2
  puts "WARNING hdl-modules resync_pulse.tcl: Could not find clk_out."
}

set min_period [expr {min(${clk_in_period}, ${clk_out_period})}]
puts "INFO hdl-modules resync_pulse.tcl: Using calculated min period: ${min_period}."

# Constrain the level signals. Very similar to resync_level.tcl.
set level_in [get_cells "level_in_reg"]
set level_out_m1 [get_cells "level_out_m1_reg"]
set_max_delay -datapath_only -from ${level_in} -to ${level_out_m1} ${min_period}

set level_out [get_cells "level_out_reg"]
set level_out_feedback_m1 [get_cells -quiet "level_out_feedback_m1_reg"]
if {${level_out_feedback_m1} != ""} {
  # Note that feedback path is optional.
  puts "INFO hdl-modules resync_pulse.tcl: Applying constraint to feedback path."
  set_max_delay -datapath_only -from ${level_out} -to ${level_out_feedback_m1} ${min_period}
} else {
  puts "INFO hdl-modules resync_pulse.tcl: No feedback path found."
}
