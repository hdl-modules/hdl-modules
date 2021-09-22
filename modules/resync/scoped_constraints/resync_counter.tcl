# --------------------------------------------------------------------------------------------------
# Copyright (c) Lukas Vik. All rights reserved.
#
# This file is part of the tsfpga project.
# https://tsfpga.com
# https://gitlab.com/tsfpga/tsfpga
# --------------------------------------------------------------------------------------------------
# Xilinx User Guide UG903 provides a good example of this type of constraints
# ------------------------------------------------------------------------------

set stable_registers [get_cells counter_in_gray_reg*]
set first_resync_registers [get_cells counter_in_gray_p1_reg*]
set clk_in [get_clocks -of_objects [get_ports clk_in]]
set clk_out [get_clocks -of_objects [get_ports clk_out]]

if {${clk_in} != {} && ${clk_out} != {}} {
  set clk_out_period [get_property -min PERIOD ${clk_out}]
  set clk_in_period [get_property -min PERIOD ${clk_in}]
  set min_period [expr {((${clk_in_period} < ${clk_out_period}) ? ${clk_in_period} : ${clk_out_period})} ]
  puts "INFO tsfpga resync_counter.tcl: Using min period ${min_period}"
} else {
  # In some cases the clock might not be created yet, most likely during synthesis.
  # Use 2 nanosecond (500 MHz) as default, which should be safe for all FPGA applications.
  # Hopefully the clocks are defined when this constraint file is applied again during
  # implementation. That would make the constraint more correct.
  set min_period 2
  puts "WARNING tsfpga resync_counter.tcl: Could not auto detect frequencies. Using default value."
}

# Add bus skew constraint to make sure that multiple bit changes on one clk_in cycle are detected
# with maximum one clk_out cycle skew.
set_bus_skew -from ${stable_registers} -to ${first_resync_registers} ${min_period}

# Set max delay to impose a latency limit
set_max_delay -datapath_only -from ${stable_registers} -to ${first_resync_registers} ${min_period}
