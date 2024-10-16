This module contains an incredibly simplified Direct Memory Access (DMA) component for
streaming data from FPGA to DDR memory over AXI.
Being simplified, it has the following limitations:

* Can only handle writing to continuous ring buffer space in DDR.
  Has no scatter-gather capability.
* Does not support data strobing or narrow AXI transfers.
  All addresses must be aligned with the AXI data width.
* Each streaming beat becomes an AXI burst, giving poor AXI performance if data rate is high.
  This will be fixed in the future with the ``packet_length_beats`` generic.
* Stream data width must be the same as AXI data width.
  This will be fixed in the future with the ``stream_data_width``
  and ``axi_data_width`` generics.
* Has no "event aggregator" feature for the ``write_done`` interrupt bit.
  Meaning an interrupt will be generated for each beat, which can bog down software
  if data rate is high.
  This will be implemented in the future with the
  ``write_done_aggregate_count`` and ``write_done_aggregate_ticks`` generics.
