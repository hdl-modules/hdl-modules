# --------------------------------------------------------------------------------------------------
# Copyright (c) Lukas Vik. All rights reserved.
#
# This file is part of the tsfpga project.
# https://tsfpga.com
# https://gitlab.com/tsfpga/tsfpga
# --------------------------------------------------------------------------------------------------

set data_in_sampled [get_cells data_in_sampled_reg*]
set data_out [get_cells data_out_int_reg*]
set clk_in [get_clocks -of_objects [get_ports clk_in]]
set clk_out [get_clocks -of_objects [get_ports clk_out]]

if {${clk_in} != {} && ${clk_out} != {}} {
  set clk_out_period [get_property -min PERIOD ${clk_out}]
  set clk_in_period [get_property -min PERIOD ${clk_in}]
  set min_period [expr {((${clk_in_period} < ${clk_out_period}) ? ${clk_in_period} : ${clk_out_period})} ]
  puts "INFO tsfpga resync_slv_level_coherent.tcl: Using min period ${min_period}"
} else {
  # In some cases the clock might not be created yet, most likely during synthesis.
  # Use 2 nanosecond (500 MHz) as default, which should be safe for all FPGA applications.
  # Hopefully the clocks are defined when this constraint file is applied again during
  # implementation. That would make the constraint more correct.
  set min_period 2
  puts "WARNING tsfpga resync_slv_level_coherent.tcl: Could not auto detect frequencies. Using default value."
}

# Set max delay to impose a latency limit
set_max_delay -datapath_only -from ${data_in_sampled} -to ${data_out} ${min_period}
