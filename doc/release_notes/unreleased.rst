Fixes

* Fix bug in :ref:`reg_file.axi_lite_reg_file` where a non-zero default value for a register of type
  ``wpulse`` or ``r_wpulse`` would only be asserted on ``regs_down`` the very first clock cycle.

* Fix bug where :ref:`axi.axi_read_throttle` could lower ``ARVALID`` without an AR transaction
  having occurred.

Breaking changes

* Remove unused ``addr_width`` generic from :ref:`bfm.axi_read_master`
  and :ref:`bfm.axi_write_master`.

* Rename :ref:`axi.axi_lite_mux` generic ``slave_addrs`` to ``base_addresses`` and change type
  to ``addr_vec_t``, i.e. a list of base addresses.
  Same for :ref:`axi.axi_lite_to_vec` generic ``axi_lite_slaves``.
  The address mask is now calculated internally.

* Rename optional :ref:`bfm.axi_write_master` generic ``set_axi3_w_id`` to ``enable_axi3``.
