Added

* Add ``common.handshake_pipeline`` generic ``pipeline_data_signals`` with default value ``true``, and implement mode that pipelines control signals but not data.

Bug fixes

* Fix full throughput in ``common.keep_remover`` when not all input lanes are strobed.

Breaking changes

* Change ``common.handshake_pipeline`` generic ``allow_poor_input_ready_timing`` with default value ``false`` to ``pipeline_control_signals`` with default value ``True``.
