Getting started
===============

The modules can be used straight away in your simulation and build project.
Start by cloning the repo:

  git clone https://github.com/hdl-modules/hdl-modules.git

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
  When using `tsfpga <https://tsfpga.com>`__, this is done with a call to
  :func:`tsfpga.module.get_modules` and appending to your current list of modules.


.. _scoped_constraints:

Scoped constraints
------------------

Many entities in this project have corresponding constraint files that must be used in
build projects for proper operation.
These are found in the ``scoped_constraints`` directory of the module, which contains
``.tcl`` files that have the same file name as the corresponding entity.

These must be loaded in Vivado with e.g.

  read_xdc -ref asynchronous_fifo /home/lukas/work/repo/hdl-modules/hdl-modules/modules/fifo/scoped_constraints/asynchronous_fifo.tcl

The constraint file being scoped means that it is applied relative to each instance of the entity.
Using this we do not have to search through the whole design hierarchically to find the signals that
we are interested in in our constraint file.

.. note::
  When using `tsfpga <https://tsfpga.com>`__, this is done automatically for build projects, since
  hdl-modules uses the recommended module structure.


Unresolved types
----------------

The modules consistently use unresolved types
(e.g. ``std_ulogic`` instead of ``std_logic``, ``u_unsigned`` instead of ``unsigned``, etc.).
This means that accidental multiple drivers of a signal will result in an error when simulating
or synthesizing the design.

Since e.g. ``std_logic`` is a sub-type of ``std_ulogic`` in VHDL-2008, it is no problem if
hdl-modules components are integrated in a code base that still uses the resolved types.
E.g. a ``std_logic`` signal can be attached to a hdl-modules port of type ``std_ulogic``
(both ``in`` and ``out``) without problem.


Feedback
--------

If you find any bugs or inconsistencies, please
`start a discussion <https://github.com/hdl-modules/hdl-modules/discussions>`__
or `create an issue <https://github.com/hdl-modules/hdl-modules/issues>`__
on GitHub.
