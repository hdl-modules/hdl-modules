Added

* Add :ref:`common.handshake_mux`.

* Add :ref:`common.clean_packet_dropper`.

* Add :ref:`common.time_pkg`.

Bug fixes

* Fix bug where :ref:`fifo.fifo` in packet mode could propagate erroneous data when a packet of
  length one was written to an almost empty FIFO.

* Fix bug where :ref:`fifo.fifo` and :ref:`fifo.asynchronous_fifo` in packet mode could have bubble
  cycles in packet readout when output register was enabled.

* Fix bug where :ref:`bfm.axi_stream_master`, :ref:`bfm.axi_write_master`
  and :ref:`bfm.axi_read_master` would not drive bus with ``'X'`` when ``valid`` was low.

Breaking changes

* Rename :ref:`bfm.axi_stream_slave` port ``num_bursts_checked`` to ``num_packets_checked``.

* Rename :ref:`common.width_conversion` generic ``support_unaligned_burst_length``
  to ``support_unaligned_packet_length``.

* Remove the ``remove_strobed_out_invalid_data`` generic from :ref:`bfm.axi_stream_slave`
  and :ref:`bfm.axi_write_slave`.
  This behavior is now always enabled.

* Change to use unresolved VHDL types consistently.

  * ``std_ulogic`` instead of ``std_logic``.
  * ``std_ulogic_vector`` instead of ``std_logic_vector``.
  * ``u_signed`` instead of ``signed``.
  * ``u_unsigned`` instead of ``unsigned``.

* Move ``to_period`` and ``to_frequency_hz`` functions from :ref:`common.types_pkg`
  to :ref:`common.time_pkg`.

* Remove erroneous assignment of ``asynchronous_fifo`` port ``read_level`` when packet mode
  is enabled.

* Remove the rarely used ``axi_w_fifo`` port ``read_level`` which does not have valid value
  in all configurations.

* Remove the rarely used ``axi_write_cdc`` port ``output_data_fifo_level`` which does not have
  valid value in all configurations.
