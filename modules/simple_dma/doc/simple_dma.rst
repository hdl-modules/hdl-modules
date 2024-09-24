This module contains an incredibly simplified Direct Memory Access (DMA) component for
streaming data from FPGA to DDR memory over AXI.
Being simplified, it has the following limitations:

* Can only handle writing to continuous ring buffer space in DDR.
  Has no scatter-gather capability.
* Each streaming beat becomes an AXI burst, giving poor AXI performance if
  data rate is even moderate.
* Has no data strobing support.
  All addresses must be aligned with the data width.
* Does not support narrow AXI transfers or any other funny stuff.
* Has no "event aggregator" feature for the ``write_done`` interrupt bit.
  Meaning an interrupt will be generated for each beat, which can bog down software
  if data rate is moderate.

Note that this module is controlled over the register bus.
Please see :ref:`register interface specification <simple_dma.register_interface>` for
usage instructions.
