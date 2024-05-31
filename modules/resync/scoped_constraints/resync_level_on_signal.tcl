# --------------------------------------------------------------------------------------------------
# Copyright (c) Lukas Vik. All rights reserved.
#
# This file is part of the hdl-modules project, a collection of reusable, high-quality,
# peer-reviewed VHDL building blocks.
# https://hdl-modules.com
# https://github.com/hdl-modules/hdl-modules
# --------------------------------------------------------------------------------------------------

set data_in [get_nets "data_in_int"]
set data_out [get_cells "data_out_reg"]

set_false_path -setup -hold -through ${data_in} -to ${data_out}

# Waive
# * "Clock enable controlled CDC structure detected", and
# * "MUX hold controlled CDC structure detected"
# warnings to make reports a little cleaner.
# Either one can appear for this CDC.
# The 'report_cdc' command lists the resync bit as a warning, for example
# * From: data_in_reg[0]/C
# * To: data_out_reg[0]/D
# The wildcards below aim to catch all these paths.
# We can not find the 'from' pin using 'get_pins' since it is not present within this entity
# (there is no register on the input).
# So instead we use the wildcard.
set cdc_from "*PIN"
set cdc_to [get_pins -quiet "data_out_reg*/D"]
create_waiver \
  -quiet \
  -id "CDC-15" \
  -from ${cdc_from} \
  -to ${cdc_to} \
  -description "Does not matter if we use CE/MUX since data is guaranteed stable when sampled"
create_waiver \
  -quiet \
  -id "CDC-17" \
  -from ${cdc_from} \
  -to ${cdc_to} \
  -description "Does not matter if we use CE/MUX since data is guaranteed stable when sampled"
