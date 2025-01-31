# --------------------------------------------------------------------------------------------------
# Copyright (c) Lukas Vik. All rights reserved.
#
# This file is part of the hdl-modules project, a collection of reusable, high-quality,
# peer-reviewed VHDL building blocks.
# https://hdl-modules.com
# https://github.com/hdl-modules/hdl-modules
# --------------------------------------------------------------------------------------------------
# See the file 'resync_pulse.tcl' for background on
# * Why we find the minimum period in such a clunky way.
# * Why we use 'set_max_delay' with the '-datapath_only' flag.
# --------------------------------------------------------------------------------------------------

set clk_in [get_clocks -quiet -of_objects [get_ports "clk_in"]]
set clk_out [get_clocks -quiet -of_objects [get_ports "clk_out"]]

if {${clk_in} != ""} {
  set clk_in_period [get_property "PERIOD" ${clk_in}]
  puts "INFO hdl-modules resync_twophase_lutram.tcl: Using clk_in period: ${clk_in_period}."
} else {
  set clk_in_period 2
  puts "WARNING hdl-modules resync_twophase_lutram.tcl: Could not find clk_in."
}

if {${clk_out} != ""} {
  set clk_out_period [get_property "PERIOD" ${clk_out}]
  puts "INFO hdl-modules resync_twophase_lutram.tcl: Using clk_out period: ${clk_out_period}."
} else {
  set clk_out_period 2
  puts "WARNING hdl-modules resync_twophase_lutram.tcl: Could not find clk_out."
}

set min_period [expr {min(${clk_in_period}, ${clk_out_period})}]
puts "INFO hdl-modules resync_twophase_lutram.tcl: Using calculated min period: ${min_period}."

# Constrain the level signals. Very similar to 'resync_level.tcl'.
set input_level_not_p1 [get_cells "input_level_not_p1_reg"]
set output_level_m1 [get_cells "output_level_m1_reg"]
set_max_delay -datapath_only -from ${input_level_not_p1} -to ${output_level_m1} ${min_period}

set output_level_p1 [get_cells "output_level_p1_reg"]
set input_level_m1 [get_cells "input_level_m1_reg"]
set_max_delay -datapath_only -from ${output_level_p1} -to ${input_level_m1} ${min_period}

# TODO verify that it is constrained by the output_clock still.....
set read_data [get_nets "read_data*"]
set_false_path -setup -hold -from ${clk_in} -through ${read_data}

# Waive "Unknown 1-bit CDC circuit" and "LUTRAM read/write potential collision" warnings to make
# reports a little cleaner.
# The 'report_cdc' command lists all the data bits as a warning, for example
# * From: resync_twophase_lutram_inst/memory_reg_0_1_0_0/DP/CLK
# * To: resync_twophase_lutram_inst/assign_output.data_out_reg[8]/D
# Note however that the 'to' pin might be outside of this entity if no output register is used.
# The wildcards below aim to catch all these paths.
set cdc_from [get_pins -quiet "memory_reg*/*/CLK"]
set cdc_to "*PIN"

create_waiver \
  -quiet \
  -id "CDC-1" \
  -from ${cdc_from} \
  -to ${cdc_to} \
  -description "CDC circuit is intentional and well designed"

create_waiver \
  -quiet \
  -id "CDC-26" \
  -from ${cdc_from} \
  -to ${cdc_to} \
  -description "Read/write pointer logic guarantees no collision"
