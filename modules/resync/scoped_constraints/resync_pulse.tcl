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

# Try to find the period of the input clock.
# Use either the actual value, or a safe default value (500 MHz => 2 ns) if the clock can
# not be found at this stage.
# Could be that the clock has not been created yet, but will be in a later stage.
# Could be that some non-trivial clock is used that can not be accessed like this.
# Has been observed for example when using a clock driven by an IP core.
# These are some of the reasons that we need to have a fallback if we can not find one or both of
# the clocks.
if {${clk_in} != ""} {
  set clk_in_period [get_property "PERIOD" ${clk_in}]
  puts "INFO hdl-modules resync_pulse.tcl: Using clk_in period: ${clk_in_period}."
} else {
  set clk_in_period 2
  puts "WARNING hdl-modules resync_pulse.tcl: Could not find clk_in."
}

# Try to find output clock period in a similar way.
if {${clk_out} != ""} {
  set clk_out_period [get_property "PERIOD" ${clk_out}]
  puts "INFO hdl-modules resync_pulse.tcl: Using clk_out period: ${clk_out_period}."
} else {
  set clk_out_period 2
  puts "WARNING hdl-modules resync_pulse.tcl: Could not find clk_out."
}

set min_period [expr {min(${clk_in_period}, ${clk_out_period})}]
puts "INFO hdl-modules resync_pulse.tcl: Using calculated min period: ${min_period}."

# Constrain the level signals.
# The recommend way, according to 'set_max_delay -help', is to use '-datapath_only' when
# constraining asynchronous clock domain crossings.
# This removes any clock jitter/skew/pessimism from the delay calculation, though, which means that
# in reality the delay can be greater than one clock cycle.
# Note also, that since the updated value might not align with the output clock edge, so the time
# until the value is sampled may be two clock cycles, or even more given clock jitter, etc.
# Without the '-datapath_only' flag, it works in most cases but command failure has been observed in
# some other, non-trivial, cases.
# Typically happens when a derived clock or a clock from an IP core is used.
# Hence we must use the flag.
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
