This module contains an open-source Direct Memory Access (DMA) component for
streaming data from FPGA to DDR memory over AXI.
Sometimes called "AXI DMA S2MM".
The implementation is optimized for

1. very low :ref:`resource usage <dma_axi_write_simple_resource_usage>`, and
2. maximum :ref:`AXI/data throughput <dma_axi_write_simple_throughput>`.

Being simplified, however, it has the following limitations:

1. Can only write to continuous ring buffer space in DDR.
   No scatter-gather support.
2. Does not support data strobing or narrow AXI transfers.
   All addresses must be aligned with the AXI data width.
3. Uses a static compile-time packet length, with no support for partial packets.
4. Packet length must be power of two.

These limitations and the simplicity of the design are intentional.
This is what enables the low resource usage and high throughput.


.. _dma_axi_write_simple_cpp:

C++ driver
----------

There is a complete C++ driver available in the
`cpp sub-folder <https://github.com/hdl-modules/hdl-modules/tree/main/modules/dma_axi_write_simple/cpp>`__
in the repository.
The class provides a convenient API for setting up the module and receiving stream data from
the FPGA.
It supports an interrupt-based as well as a polling-based workflow.
See the header file for documentation.


Simulate and build FPGA with register artifacts
-----------------------------------------------

This module is controlled over a register bus, with code generated by
`hdl-registers <https://hdl-registers.com>`_.
See :ref:`dma_axi_write_simple.register_interface` for register documentation.

Generated register code artifacts are not checked in to the repository.
The recommended way to use hdl-modules is with `tsfpga <https://tsfpga.com>`__
(see :ref:`getting_started`), in which case register code is always generated and kept up to date
automatically.
This is by far the most convenient and portable solution.

If you dont't want to use tsfpga, you can integrate hdl-registers code generation in your
build/simulation flow or use the hard coded artifacts below (not recommended).


Hard coded artifacts
____________________

Not recommended, but if you don't want to use tsfpga or hdl-registers,
these generated VHDL artifacts can be included in the ``dma_axi_write_simple`` library
for simulation and synthesis:

1. :download:`regs_src/dma_axi_write_simple_regs_pkg.vhd <vhdl/dma_axi_write_simple_regs_pkg.vhd>`
2. :download:`regs_src/dma_axi_write_simple_register_record_pkg.vhd <vhdl/dma_axi_write_simple_register_record_pkg.vhd>`
3. :download:`regs_src/dma_axi_write_simple_register_file_axi_lite.vhd <vhdl/dma_axi_write_simple_register_file_axi_lite.vhd>`
4. :download:`regs_sim/dma_axi_write_simple_register_read_write_pkg.vhd <vhdl/dma_axi_write_simple_register_read_write_pkg.vhd>`

The first few are source files that shall be included in your simulation as well build project.
The last one is a simulation file that shall be included only in your simulation project.
These generated C++ artifacts can be used to control the module from software:

1. :download:`include/i_dma_axi_write_simple.h <cpp/include/i_dma_axi_write_simple.h>`
2. :download:`include/dma_axi_write_simple.h <cpp/include/dma_axi_write_simple.h>`
3. :download:`dma_axi_write_simple.cpp <cpp/dma_axi_write_simple.cpp>`

.. warning::
   When copy-pasting generated artifacts, there is a large risk that things go out of sync when
   e.g. versions are bumped.
   An automated solution with :ref:`tsfpga <getting_started>` is highly recommended.
