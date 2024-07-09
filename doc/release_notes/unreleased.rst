Added

* Add :ref:`resync.resync_slv_handshake`.
* Add ``enable_iob`` generic to :ref:`common.debounce`.

Bug fixes

* Respect the ``include_unisim`` flag in ``module_hard_fifo.get_simulation_files`` method.
* Ensure deterministic latency of :ref:`resync.resync_pulse`,
  :ref:`resync.resync_slv_level_coherent`, and :ref:`common.debounce`.

Other changes

* Waive irrelevant Vivado CDC warnings to make reports more clean.
