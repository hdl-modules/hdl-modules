Getting started
===============

The modules can be used straight away in your simulation and build project.
Start by cloning the repo:

  git clone https://gitlab.com/tsfpga/hdl_modules.git

If you want a stable release you can checkout one of the tags.


Source code
-----------

Synthesizable source code is found in the ``src`` folder of each module.
These files should be added to your simulation and build project.
The library name is the same as the module name.

Test code is found in the ``test`` folder of each module.
Simulation code (BFMs) is found in the ``sim`` folder of each module.
The simulation code should be added to your simulation project.

All files must be handled as VHDL-2008.

.. note::
  When using tsfpga, this is done with a call to :func:`tsfpga.module.get_modules` and appending
  to your current list of modules.



Scoped constraints
------------------

Many entities in this project have corresponding constraint files that must be used in build projects
for proper operation.
These are found in the ``scoped_constraints`` directory of the module, which contains ``.tcl`` files
that have the same file name as the corresponding entity.

These must be loaded in Vivado with e.g.

  read_xdc -ref asynchronous_fifo /home/lukas/work/repo/tsfpga/hdl_modules/modules/fifo/scoped_constraints/asynchronous_fifo.tcl

The constraint file being scoped means that it is applied relative to each instance of the entity.
Using this we do not have to search through the whole design hierarchically to find the signals that
we are interested in in our constraint file.

.. note::
  When using tsfpga, this is done automatically for build projects, since
  hdl_modules uses the recommended module structure.


Feedback
--------

If you find any bugs or inconsistencies, please write in the
`gitter channel <https://gitter.im/tsfpga/tsfpga>`__
or create an `issue on gitlab <https://gitlab.com/tsfpga/hdl_modules/-/issues>`__.