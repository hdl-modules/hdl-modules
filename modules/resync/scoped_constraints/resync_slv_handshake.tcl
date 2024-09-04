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

set input_clk [get_clocks -quiet -of_objects [get_ports "input_clk"]]
set result_clk [get_clocks -quiet -of_objects [get_ports "result_clk"]]

if {${input_clk} != ""} {
  set input_clk_period [get_property "PERIOD" ${input_clk}]
  puts "INFO hdl-modules resync_slv_handshake.tcl: Using input_clk period: ${input_clk_period}."
} else {
  set input_clk_period 2
  puts "WARNING hdl-modules resync_slv_handshake.tcl: Could not find input_clk."
}

if {${result_clk} != ""} {
  set result_clk_period [get_property "PERIOD" ${result_clk}]
  puts "INFO hdl-modules resync_slv_handshake.tcl: Using result_clk period: ${result_clk_period}."
} else {
  set result_clk_period 2
  puts "WARNING hdl-modules resync_slv_handshake.tcl: Could not find result_clk."
}

set min_period [expr {min(${input_clk_period}, ${result_clk_period})}]
puts "INFO hdl-modules resync_slv_handshake.tcl: Using calculated min period: ${min_period}."

# Set max delay to impose a latency limit.
set input_data_sampled [get_cells "input_data_sampled_reg*"]
set result_data [get_cells "result_data_int_reg*"]
set_max_delay -datapath_only -from ${input_data_sampled} -to ${result_data} ${min_period}

# Waive "Clock enable controlled CDC structure detected" warning to make reports a little cleaner.
# The 'report_cdc' command lists all the data bits as a warning, for example
# * From: resync_slv_handshake_inst/input_data_sampled_reg[0]/C
# * To: resync_slv_handshake_inst/result_data_int_reg[0]/D
# The wildcards below aim to catch all these paths.
set cdc_from [get_pins -quiet "input_data_sampled_reg*/C"]
set cdc_to [get_pins -quiet "result_data_int_reg*/D"]
create_waiver \
  -quiet \
  -id "CDC-15" \
  -from ${cdc_from} \
  -to ${cdc_to} \
  -description "Clock Enable is part of this CDC concept, no reason to warn about it"

# Constrain the level signals. Very similar to resync_level.tcl.
set input_level_p1 [get_cells "input_level_p1_reg"]
set result_level_m1 [get_cells "result_level_m1_reg"]
set_max_delay -datapath_only -from ${input_level_p1} -to ${result_level_m1} ${min_period}

set result_level_feedback [get_cells "result_level_feedback_reg"]
set input_level_m1 [get_cells "input_level_m1_reg"]
set_max_delay -datapath_only -from ${result_level_feedback} -to ${input_level_m1} ${min_period}
