Added

* Add :ref:`common.handshake_pipeline` generic ``pipeline_data_signals`` with default value
  ``true``, and implement mode that pipelines control signals but not data.
* Add :ref:`fifo.fifo` and :ref:`fifo.asynchronous_fifo` generic ``enable_output_register``,
  which adds a pipeline stage for RAM output data.

Bug fixes

* Fix full throughput in :ref:`common.keep_remover` when not all input lanes are strobed.

Breaking changes

* Change :ref:`common.handshake_pipeline` and :ref:`axi.axi_lite_pipeline` generics
  ``allow_poor_input_ready_timing`` with default value ``false`` to ``pipeline_control_signals``
  with default value ``True``.

* Rename :ref:`bfm.axi_stream_slave` and :ref:`bfm.handshake_slave` generic
  ``remove_strobed_out_dont_care`` to ``remove_strobed_out_invalid_data``.

* Drive output signals with ``'X'`` per default when ``valid`` is low
  in :ref:`bfm.axi_stream_master`.

* Remove default value for ``id_width`` generic, which could potentially hide errors, in
  :ref:`bfm.axi_slave`, :ref:`bfm.axi_read_slave` and :ref:`bfm.axi_write_slave`.
  Now the user has to set an explicit value for every instance.
