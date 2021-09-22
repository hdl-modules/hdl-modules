# --------------------------------------------------------------------------------------------------
# Copyright (c) Lukas Vik. All rights reserved.
#
# This file is part of the tsfpga project.
# https://tsfpga.com
# https://gitlab.com/tsfpga/tsfpga
# --------------------------------------------------------------------------------------------------

set clk_in [get_clocks -of_objects [get_ports clk_in]]
set clk_out [get_clocks -of_objects [get_ports clk_out]]
set first_resync_register [get_cells data_in_p1_reg]

if {${clk_in} != {} && ${clk_out} != {}} {
  # If we have both clocks we can set a max delay constraint in order
  # to get deterministic delay through the resync block.
  #
  # The clk_in must be present in order for the "-datapath_only" flag to work.
  # And without "-datapath_only" the constraint does not work in some cases.
  # It seems to be when a non-standard clock is used where e.g. clock jitter is unknown.
  set clk_out_period [get_property -min PERIOD ${clk_out}]
  set max_delay ${clk_out_period}

  puts "INFO tsfpga resync_level.tcl: Using ${max_delay} for max delay constraint."
  set_max_delay -datapath_only -from ${clk_in} -to ${first_resync_register} ${max_delay}
} else {
  # Could not find both clocks. Could be that clk_in is not connected, or the clocks
  # have not been created yet. In this case fall back to simple false path constraint.
  puts "WARNING tsfpga resync_level.tcl: Could not find both clocks. Setting false path constraint."
  set_false_path -setup -hold -to ${first_resync_register}
}
