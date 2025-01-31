# --------------------------------------------------------------------------------------------------
# Copyright (c) Lukas Vik. All rights reserved.
#
# This file is part of the hdl-modules project, a collection of reusable, high-quality,
# peer-reviewed VHDL building blocks.
# https://hdl-modules.com
# https://github.com/hdl-modules/hdl-modules
# --------------------------------------------------------------------------------------------------
# See this article for background and discussion about these constraints:
# https://www.linkedin.com/pulse/reliable-cdc-constraints-5-asynchronous-fifo-lukas-vik-snlgf/
# See also the file 'resync_counter.tcl' and this article
# https://www.linkedin.com/pulse/reliable-cdc-constraints-2-counters-fifos-lukas-vik-ist5c/
# for details on how the address counters are CDC'd.
# --------------------------------------------------------------------------------------------------

set clk_write [get_clocks -quiet -of_objects [get_ports "clk_write"]]
set read_data [
  get_cells \
    -quiet \
    -filter {PRIMITIVE_GROUP==FLOP_LATCH || PRIMITIVE_GROUP==REGISTER} \
    "memory.memory_read_data_reg*"
]

# These registers exist as FFs when the RAM is implemented as distributed RAM (LUTRAM).
# In this case there is a timing path from write clock to the read data registers which
# can be safely ignored in order for timing to pass.
# If the RAM is instead implemented as BRAM, the read data registers are internal in the
# BRAM primitive.
# This is also discussed in AMD UG903 and in various places in the forum.
# In recent Vivado versions (at least 2023.2), the cells show up even when the RAM is implemented as
# BRAM, hence why we filter for the primitive type.
if {${read_data} != "" && ${clk_write} != ""} {
  puts "INFO hdl-modules asynchronous_fifo.tcl: Setting false path to read data registers."
  set_false_path -setup -hold -from ${clk_write} -to ${read_data}

  # Waive "LUTRAM read/write potential collision" warning to make reports a little cleaner.
  # The 'report_cdc' command lists all the data bits as a warning, for example
  # * From: asynchronous_fifo_inst/memory.mem_reg_0_15_0_5/RAMA_D1/CLK
  # * To: asynchronous_fifo_inst/memory.memory_read_data_reg[0]
  # The wildcards below aim to catch all these paths.
  set cdc_from [get_pins -quiet "memory.mem_reg*/*/CLK"]
  set cdc_to [get_pins -quiet "memory.memory_read_data_reg*/D"]
  create_waiver \
    -quiet \
    -id "CDC-26" \
    -from ${cdc_from} \
    -to ${cdc_to} \
    -description "Read/write pointer logic guarantees no collision"
}
