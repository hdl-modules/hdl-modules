Fixes

* Fix bug in :ref:`reg_file.axi_lite_reg_file` where a non-zero default value for a register of type
  ``wpulse`` or ``r_wpulse`` would only be asserted on ``regs_down`` the very first clock cycle.

Breaking changes

* Remove unused ``addr_width`` generic from :ref:`bfm.axi_read_master`
  and :ref:`bfm.axi_write_master`.
