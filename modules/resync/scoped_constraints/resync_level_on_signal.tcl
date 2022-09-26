# --------------------------------------------------------------------------------------------------
# Copyright (c) Lukas Vik. All rights reserved.
#
# This file is part of the hdl_modules project, a collection of reusable, high-quality,
# peer-reviewed VHDL building blocks.
# https://hdl-modules.com
# https://gitlab.com/tsfpga/hdl_modules
# --------------------------------------------------------------------------------------------------

set data_out [get_cells data_out_reg]
set data_in [get_nets data_in_int]

set_false_path -setup -hold -through ${data_in} -to ${data_out}
