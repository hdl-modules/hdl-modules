Added

* Add :ref:`module_simple_dma`.
  This module is in a beta state so expect changes in the future.
* Add :ref:`common.assign_last`.
* Add :ref:`resync.resync_rarely_valid` and :ref:`resync.resync_rarely_valid_lutram`.
* Add :ref:`resync.resync_sticky_level`.
* Add :ref:`resync.resync_twophase_lutram`.

Breaking changes

* Rename ``resync_slv_level_coherent`` to :ref:`resync.resync_twophase`.
* Rename ``resync_slv_handshake`` to :ref:`resync.resync_twophase_handshake`.

* Rename old ``reg_file`` module to :ref:`register_file <module_register_file>` and rework it.
  Note that this change is compatible with `hdl-registers <https://hdl-registers.com>`__ version
  7.0.0 and later.
  If you use hdl-registers, the changes should be transparent.
  The changes are:

  * Rename "reg" to "register", "idx" to "index", "reg_type" to "mode" for all files,
    types, constants.

  * Add ``utilized_width`` field to register definition type.

  * Optimize resource utilization of :ref:`register_file.axi_lite_register_file`.

  * Remove unused functions.
