# --------------------------------------------------------------------------------------------------
# Copyright (c) Lukas Vik. All rights reserved.
#
# This file is part of the tsfpga project.
# https://tsfpga.com
# https://gitlab.com/tsfpga/tsfpga
# --------------------------------------------------------------------------------------------------

set read_data [get_cells memory.memory_read_data_reg*]
if {${read_data} != {}} {
  # These registers exist when the RAM is implemented as distributed RAM.
  # In this case there is a timing path from write clock to the read data registers which
  # can be safely ignored in order for timing to pass.
  # See discussion in https://gitlab.com/tsfpga/tsfpga/merge_requests/20
  set clk_write [get_clocks -of_objects [get_ports clk_write]]
  if {${clk_write} == {}} {
    puts "WARNING tsfpga asynchronous_fifo.tcl: Could not find clock to constrain DistRAM."
    # In some cases the clock might not be created yet, most likely during synthesis.
    # Hopefully it will be defined when this constraint file is applied again during
    # implementation. If not the build should fail timing.
  } else {
    puts "INFO tsfpga asynchronous_fifo.tcl: Setting false path from write clock to read data registers."
    set_false_path -setup -hold -from ${clk_write} -to ${read_data}
  }
}
