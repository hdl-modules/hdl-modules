# --------------------------------------------------------------------------------------------------
# Copyright (c) Lukas Vik. All rights reserved.
#
# This file is part of the hdl-modules project, a collection of reusable, high-quality,
# peer-reviewed VHDL building blocks.
# https://hdl-modules.com
# https://github.com/hdl-modules/hdl-modules
# --------------------------------------------------------------------------------------------------
# Note that this file is almost identical to 'resync_slv_handshake.tcl', except for
# signal names.
# Changes/improvements should be incorporated in both files.
#
# See the file 'resync_pulse.tcl' for background on
# * Why we find the minimum period in such a clunky way.
# * Why we use 'set_max_delay' with the '-datapath_only' flag.
# --------------------------------------------------------------------------------------------------

set clk_in [get_clocks -quiet -of_objects [get_ports "clk_in"]]
set clk_out [get_clocks -quiet -of_objects [get_ports "clk_out"]]

if {${clk_in} != ""} {
  set clk_in_period [get_property "PERIOD" ${clk_in}]
  puts "INFO hdl-modules resync_slv_level_coherent.tcl: Using clk_in period: ${clk_in_period}."
} else {
  set clk_in_period 2
  puts "WARNING hdl-modules resync_slv_level_coherent.tcl: Could not find clk_in."
}

if {${clk_out} != ""} {
  set clk_out_period [get_property "PERIOD" ${clk_out}]
  puts "INFO hdl-modules resync_slv_level_coherent.tcl: Using clk_out period: ${clk_out_period}."
} else {
  set clk_out_period 2
  puts "WARNING hdl-modules resync_slv_level_coherent.tcl: Could not find clk_out."
}

set min_period [expr {min(${clk_in_period}, ${clk_out_period})}]
puts "INFO hdl-modules resync_slv_level_coherent.tcl: Using calculated min period: ${min_period}."

# Set max delay to impose a latency limit.
set data_in_sampled [get_cells "data_in_sampled_reg*"]
set data_out [get_cells "data_out_int_reg*"]
set_max_delay -datapath_only -from ${data_in_sampled} -to ${data_out} ${min_period}

# Waive "Clock enable controlled CDC structure detected" warning to make reports a little cleaner.
# The 'report_cdc' command lists all the data bits as a warning, for example
# * From: resync_slv_level_coherent_inst/data_in_sampled_reg[0]/C
# * To: resync_slv_level_coherent_inst/data_out_int_reg[0]/D
# The wildcards below aim to catch all these paths.
set cdc_from [get_pins -quiet "data_in_sampled_reg*/C"]
set cdc_to [get_pins -quiet "data_out_int_reg*/D"]
create_waiver \
  -quiet \
  -id "CDC-15" \
  -from ${cdc_from} \
  -to ${cdc_to} \
  -description "Clock Enable is part of this CDC concept, no reason to warn about it"

# Constrain the level signals. Very similar to 'resync_level.tcl'.
set input_level_not_p1 [get_cells "input_level_not_p1_reg"]
set output_level_m1 [get_cells "output_level_m1_reg"]
set_max_delay -datapath_only -from ${input_level_not_p1} -to ${output_level_m1} ${min_period}

set output_level_p1 [get_cells "output_level_p1_reg"]
set input_level_m1 [get_cells "input_level_m1_reg"]
set_max_delay -datapath_only -from ${output_level_p1} -to ${input_level_m1} ${min_period}
