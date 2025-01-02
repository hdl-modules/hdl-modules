This module contains a simplified Direct Memory Access (DMA) component for
streaming data from FPGA to DDR memory over AXI.
The implementation is optimized for

* very low :ref:`resource usage <simple_dma_resource_usage>`, and
* maximum :ref:`AXI/data throughput <simple_dma_throughput>`.

Being simplified, however, it has the following limitations:

* Can only handle writing to continuous ring buffer space in DDR.
  Has no scatter-gather capability.
* Does not support data strobing or narrow AXI transfers.
  All addresses must be aligned with the AXI data width.
* Uses a static compile-time packet length, with no support for partial packets.

These limitations and the simplicity of the design are intentional.
This is what enables the low resource usage and high throughput.

The limitations listed above are intrinsic, with no plan for change.
There are also currently a few limitations that are planned to be fixed in the future:

* Stream data width must be the same as AXI data width.
  This will be fixed in the future with the ``stream_data_width``
  and ``axi_data_width`` generics.
* Has no "event aggregator" feature for the ``write_done`` interrupt bit.
  Meaning an interrupt will be generated for each burst, which can bog down the software
  if data rates are high.
  This will be implemented in the future with the
  ``write_done_aggregate_count`` and ``write_done_aggregate_ticks`` generics.
