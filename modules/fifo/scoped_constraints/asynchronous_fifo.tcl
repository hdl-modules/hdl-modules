# --------------------------------------------------------------------------------------------------
# Copyright (c) Lukas Vik. All rights reserved.
#
# This file is part of the hdl-modules project, a collection of reusable, high-quality,
# peer-reviewed VHDL building blocks.
# https://hdl-modules.com
# https://github.com/hdl-modules/hdl-modules
# --------------------------------------------------------------------------------------------------

set clk_write [get_clocks -of_objects [get_ports clk_write]]
set read_data [get_cells memory.memory_read_data_reg*]

# These registers exist as FFs when the RAM is implemented as distributed RAM (LUTRAM).
# In this case there is a timing path from write clock to the read data registers which
# can be safely ignored in order for timing to pass.
# If the RAM is implemented as BRAM, the read data registers are internal in the BRAM primitive.
# See some old discussion in https://gitlab.com/tsfpga/tsfpga/merge_requests/20
# This is also discussed in AMD UG903 and in various places in the forum.
# In recent Vivado versions (at least 2023.2), the cells show up even when the RAM is implemented as
# BRAM, but the constraint has no effect.
# Hence it seems safe to apply it always.
if {${read_data} != "" && ${clk_write} != ""} {
  puts "INFO hdl-modules asynchronous_fifo.tcl: Setting false path to read data registers."
  set_false_path -setup -hold -from ${clk_write} -to ${read_data}
}
