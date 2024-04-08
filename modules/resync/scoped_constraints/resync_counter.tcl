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
set clk_in [get_clocks -of_objects [get_ports clk_in]]
set clk_out [get_clocks -of_objects [get_ports clk_out]]

if {${clk_in} != "" && ${clk_out} != ""} {
  set clk_out_period [get_property -min PERIOD ${clk_out}]
  set clk_in_period [get_property -min PERIOD ${clk_in}]
  set min_period [expr {min(${clk_in_period}, ${clk_out_period})}]
  puts "INFO hdl-modules resync_counter.tcl: Using calculated min period: ${min_period}."
} else {
  # In some cases the clock might not be created yet, most likely during synthesis.
  # Use 2 nanosecond (500 MHz) as default, which should be safe for all FPGA applications.
  # Hopefully the clocks are defined when this constraint file is applied again during
  # implementation. That would make the constraint more correct.
  set min_period 2
  puts "WARNING hdl-modules resync_counter.tcl: Could not auto detect frequencies. Using default value."
}

# Add bus skew constraint to make sure that multiple bit changes on one 'clk_in' cycle are detected
# with maximum one 'clk_out' cycle skew.
set_bus_skew -from ${stable_registers} -to ${first_resync_registers} ${min_period}

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
