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
