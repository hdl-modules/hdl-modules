Breaking changes

* Use more-compact VUnit mechanism for getting random seed in BFMs.
  Removes the ``seed`` generic from

  * :ref:`bfm.handshake_master`
  * :ref:`bfm.handshake_slave`
  * :ref:`bfm.axi_stream_master`
  * :ref:`bfm.axi_stream_slave`
  * :ref:`bfm.axi_read_master`
  * :ref:`bfm.axi_write_master`
