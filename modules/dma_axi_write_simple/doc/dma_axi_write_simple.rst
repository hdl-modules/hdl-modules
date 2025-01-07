This module contains a simplified Direct Memory Access (DMA) component for
streaming data from FPGA to DDR memory over AXI.
The implementation is optimized for

1. very low :ref:`resource usage <dma_axi_write_simple_resource_usage>`, and
2. maximum :ref:`AXI/data throughput <dma_axi_write_simple_throughput>`.

Being simplified, however, it has the following limitations:

1. Can only handle writing to continuous ring buffer space in DDR.
   Has no scatter-gather capability.
2. Does not support data strobing or narrow AXI transfers.
   All addresses must be aligned with the AXI data width.
3. Uses a static compile-time packet length, with no support for partial packets.
4. Packet length must be power of two.

These limitations and the simplicity of the design are intentional.
This is what enables the low resource usage and high throughput.


Roadmap
-------

The limitations listed above are intrinsic, with no plan for change.
There are also currently a few limitations that are planned to be fixed in the future:

1. Stream data width must be the same as AXI data width.
   This will be fixed in the future with the ``stream_data_width``
   and ``axi_data_width`` generics.
2. Has no "event aggregator" feature for the ``write_done`` interrupt bit.
   Meaning an interrupt will be generated for each burst, which can bog down the software
   if data rates are high.
   This will be implemented in the future with the
   ``write_done_aggregate_count`` and ``write_done_aggregate_ticks`` generics.
