This module contains wrappers around the hard FIFO primitives in the Xilinx Ultrascale+ series
of devices.
Since the code depends on Xilinx primitives, the ``unisim`` library must be compiled and available
in order to simulate this module.
If this is not possible/desirable in your environment, the module can be excluded with the
``names_avoid`` argument to :py:func:`tsfpga.module.get_modules` if you are using tsfpga.
Using the Vivado simulation libraries can easily be enabled in tsfpga though, by following the
guide at :ref:`tsfpga:vivado_simlib`.
