# --------------------------------------------------------------------------------------------------
# Copyright (c) Lukas Vik. All rights reserved.
#
# This file is part of the hdl-modules project, a collection of reusable, high-quality,
# peer-reviewed VHDL building blocks.
# https://hdl-modules.com
# https://github.com/hdl-modules/hdl-modules
# --------------------------------------------------------------------------------------------------
# See this article for background and discussion about these constraints:
# https://www.linkedin.com/pulse/reliable-cdc-constraints-2-counters-fifos-lukas-vik-ist5c
# Also AMD document UG903 provides some examples.
# --------------------------------------------------------------------------------------------------

set stable_registers [get_cells counter_in_gray_reg*]
set first_resync_registers [get_cells counter_in_gray_p1_reg*]

# Try to find the period of the input clock.
# Use either the actual value, or a safe default value (500 MHz => 2 ns) if the clock can
# not be found at this stage.
set clk_in [get_clocks -of_objects [get_ports clk_in]]
if {${clk_in} != ""} {
  set clk_in_period [get_property -min PERIOD ${clk_in}]
  puts "INFO hdl-modules resync_counter.tcl: Using clk_in period: ${clk_in_period}."
} else {
  set clk_in_period 2
  puts "WARNING hdl-modules resync_counter.tcl: Could not find clk_in."
}

# Add intra-word skew constraint so that when a value is sampled in the output domain, a maximum of
# one bit might be in a transitioning state.
set_bus_skew -from ${stable_registers} -to ${first_resync_registers} ${clk_in_period}

# Try to find output clock period in a similar way.
set clk_out [get_clocks -of_objects [get_ports clk_out]]
if {${clk_out} != ""} {
  set clk_out_period [get_property -min PERIOD ${clk_out}]
  puts "INFO hdl-modules resync_counter.tcl: Using clk_out period: ${clk_out_period}."
} else {
  set clk_out_period 2
  puts "WARNING hdl-modules resync_counter.tcl: Could not find clk_out."
}

set min_period [expr {min(${clk_in_period}, ${clk_out_period})}]

# Set max delay to impose a latency limit.
# The recommend way, according to 'set_max_delay -help', is to use '-datapath_only' when
# constraining asynchronous clock domain crossings.
# This removes any clock pessimism from the delay calculation, though, which means that in reality
# the delay can be slightly greater than one clock cycle.
# But without this flag, it works in most cases but command failure has been observed in some
# other, non-trivial, cases.
# Typically happens when a derived clock or a clock from an IP core is used.
# Hence we use the flag.
set_max_delay -datapath_only -from ${stable_registers} -to ${first_resync_registers} ${min_period}
