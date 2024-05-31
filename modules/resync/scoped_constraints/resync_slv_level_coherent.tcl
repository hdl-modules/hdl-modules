# --------------------------------------------------------------------------------------------------
# Copyright (c) Lukas Vik. All rights reserved.
#
# This file is part of the hdl-modules project, a collection of reusable, high-quality,
# peer-reviewed VHDL building blocks.
# https://hdl-modules.com
# https://github.com/hdl-modules/hdl-modules
# --------------------------------------------------------------------------------------------------

set data_in_sampled [get_cells "data_in_sampled_reg*"]
set data_out [get_cells "data_out_int_reg*"]
set clk_in [get_clocks -quiet -of_objects [get_ports "clk_in"]]
set clk_out [get_clocks -quiet -of_objects [get_ports "clk_out"]]

if {${clk_in} != "" && ${clk_out} != ""} {
  set clk_in_period [get_property "PERIOD" ${clk_in}]
  set clk_out_period [get_property "PERIOD" ${clk_out}]
  set min_period [expr {min(${clk_in_period}, ${clk_out_period})}]
  puts "INFO hdl-modules resync_slv_level_coherent.tcl: Using calculated min period: ${min_period}."
} else {
  # In some cases the clock might not be created yet, most likely during synthesis.
  # Use 2 nanosecond (500 MHz) as default, which should be safe for all FPGA applications.
  # Hopefully the clocks are defined when this constraint file is applied again during
  # implementation. That would make the constraint more correct.
  set min_period 2
  puts "WARNING hdl-modules resync_slv_level_coherent.tcl: Could not find both clocks."
}

# Set max delay to impose a latency limit.
# The recommend way, according to 'set_max_delay -help', is to use '-datapath_only' when
# constraining asynchronous clock domain crossings.
# This removes any clock pessimism from the delay calculation, though, which means that in reality
# the delay can be slightly greater than one clock cycle.
# But without this flag, it works in most cases but command failure has been observed in some
# other, non-trivial, cases.
# Typically happens when a derived clock or a clock from an IP core is used.
# Hence we use the flag.
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
