Breaking changes

* Split ``bfm.bfm_pkg`` into

  * :ref:`bfm.stall_bfm_pkg`
  * :ref:`bfm.axi_slave_bfm_pkg`
  * :ref:`bfm.integer_array_bfm_pkg`
  * :ref:`bfm.queue_bfm_pkg`
  * :ref:`bfm.memory_bfm_pkg`.

* Change ``stall_config`` generic of

  * :ref:`bfm.handshake_master`
  * :ref:`bfm.handshake_slave`
  * :ref:`bfm.axi_stream_master`
  * :ref:`bfm.axi_stream_slave`
  * :ref:`bfm.axi_read_master`
  * :ref:`bfm.axi_write_master`

  to use type ``stall_configuration_t`` from :ref:`bfm.stall_bfm_pkg`.

Internal changes

* Optimize library and package imports in a way that decreases simulation time by 20-40% for small
  testbenches using GHDL.
