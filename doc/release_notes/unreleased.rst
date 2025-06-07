Added

* Add support for ``wmasked`` register mode in :ref:`register_file.axi_lite_register_file`.

Fixes

* Fix ``ARREADY`` handshaking bug in :ref:`register_file.axi_lite_register_file`.
* Fix bug in :ref:`axi.axi_simple_read_crossbar`, :ref:`axi.axi_simple_write_crossbar`,
  :ref:`axi_lite.axi_lite_simple_read_crossbar` and :ref:`axi_lite.axi_lite_simple_write_crossbar`.

Breaking changes

* Use more-compact VUnit mechanism for getting random seed in BFMs.
  Removes the ``seed`` generic from

  * :ref:`bfm.handshake_master`
  * :ref:`bfm.handshake_slave`
  * :ref:`bfm.axi_stream_master`
  * :ref:`bfm.axi_stream_slave`
  * :ref:`bfm.axi_read_master`
  * :ref:`bfm.axi_write_master`
