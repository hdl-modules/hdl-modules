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
#
# See the file 'resync_pulse.tcl' for background on
# * Why we find the minimum period in such a clunky way.
# * Why we use 'set_max_delay' with the '-datapath_only' flag.
# --------------------------------------------------------------------------------------------------

set stable_registers [get_cells "counter_in_gray_reg*"]
set first_resync_registers [get_cells "counter_in_gray_p1_reg*"]

# Try to find the period of the input clock.
# Use either the actual value, or a safe default value (500 MHz => 2 ns) if the clock can
# not be found at this stage.
set clk_in [get_clocks -quiet -of_objects [get_ports "clk_in"]]
if {${clk_in} != ""} {
  set clk_in_period [get_property "PERIOD" ${clk_in}]
  puts "INFO hdl-modules resync_counter.tcl: Using clk_in period: ${clk_in_period}."
} else {
  set clk_in_period 2
  puts "WARNING hdl-modules resync_counter.tcl: Could not find clk_in."
}

# Add intra-word skew constraint so that when a value is sampled in the output domain, a maximum of
# one bit might be in a transitioning state.
set_bus_skew -from ${stable_registers} -to ${first_resync_registers} ${clk_in_period}

# Try to find output clock period in a similar way.
set clk_out [get_clocks -quiet -of_objects [get_ports "clk_out"]]
if {${clk_out} != ""} {
  set clk_out_period [get_property "PERIOD" ${clk_out}]
  puts "INFO hdl-modules resync_counter.tcl: Using clk_out period: ${clk_out_period}."
} else {
  set clk_out_period 2
  puts "WARNING hdl-modules resync_counter.tcl: Could not find clk_out."
}

set min_period [expr {min(${clk_in_period}, ${clk_out_period})}]

# Set max delay to impose a latency limit.
set_max_delay -datapath_only -from ${stable_registers} -to ${first_resync_registers} ${min_period}

# Waive "Multi-bit synchronized with ASYNC_REG property" warning to make reports a little cleaner.
# The 'report_cdc' command lists all the data bits as a warning, for example
# * From: resync_counter_inst/counter_in_gray_reg[0]/C
# * To: resync_counter_inst/counter_in_gray_p1_reg[0]/D
# The wildcards below aim to catch all these paths.
set cdc_from [get_pins -quiet "counter_in_gray_reg*/C"]
set cdc_to [get_pins -quiet "counter_in_gray_p1_reg*/D"]
create_waiver \
  -quiet \
  -id "CDC-6" \
  -from ${cdc_from} \
  -to ${cdc_to} \
  -description "Multi-bit resynchronization safe since Grey code and proper constraints are used"
