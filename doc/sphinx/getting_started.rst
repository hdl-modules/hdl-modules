.. _getting_started:

Getting started
===============

The modules can be used straight away in your simulation and build project.
Start by cloning the repo:

  git clone https://github.com/hdl-modules/hdl-modules.git

To checkout a stable release version, choose one of the :ref:`tags <release_notes>`.

If you are using a Python-based simulation/build flow, using hdl-modules with
`tsfpga <https://tsfpga.com>`_ (see `installation <https://tsfpga.com/installation>`_)
is highly recommended.
It is easier, more compact and more portable than handling the source code manually.


.. _dependency_vunit:

Dependencies
------------

The :ref:`module_bfm` as well as all testbenches in this project depend on the VHDL components in
`VUnit <https://vunit.github.io/>`__ version 5.0.0 or greater.
This VUnit version is currently in a pre-release state and can be installed with e.g.
``python -m pip install vunit-hdl==5.0.0.dev5`` or by cloning the
`repository <https://github.com/VUnit/vunit>`__.

Feel free to exclude the :ref:`module_bfm` if you do not use VUnit.
If that module as well as the testbenches are excluded, no dependencies are required.


Source code
-----------

When using `tsfpga <https://tsfpga.com>`__, simply call the function
`get_hdl_modules() <https://github.com/hdl-modules/hdl-modules/blob/main/hdl_modules/__init__.py#L28>`_
and add to your list of modules.
Note that you must add the hdl-modules repository to your Python path to call this function,
either by using ``sys.path.append(...)`` or by setting the ``PYTHONPATH`` environment variable.

You can now use e.g.
:py:meth:`get_synthesis_files() <tsfpga.module.BaseModule.get_synthesis_files>`,
:py:meth:`get_simulation_files() <tsfpga.module.BaseModule.get_simulation_files>`
and :py:class:`library_name <tsfpga.module.BaseModule>` just like with any other module.
Note that you probably want to set the ``include_tests`` argument to ``False`` when
calling :py:meth:`get_simulation_files() <tsfpga.module.BaseModule.get_simulation_files>`,
so you are not running testbenches unnecessarily.

Manual workflow
_______________

When not using tsfpga, source code must be added manually to your build/simulation project.

Synthesizable source code is found in the ``src`` folder of each module.
These files should be added to your simulation and build project.
The library name is the same as the module name.

Testbenches are found in the ``test`` folder of each module.
Simulation code (BFMs) is found in the ``sim`` folder of each module.
The simulation code should be added to your simulation project but not your build project.

All files must be handled as VHDL-2008.



.. _scoped_constraints:

Scoped constraints
------------------

When using `tsfpga <https://tsfpga.com>`__, scoped constraint files are loaded automatically
to the build project and correct settings are applied.

Background
__________

Many entities in this project have corresponding constraint files that must be used in
build projects for proper operation.
These are found in the ``scoped_constraints`` directory of the module, which contains
``.tcl`` files that have the same file name as the corresponding entity.

A constraint files being "scoped" means that it is applied relative to each instance of an entity.
Using this, we do not have to search through the whole design hierarchy to find the signals that
we are interested in.

Manual workflow
_______________

When not using tsfpga, scoped constraint files must be loaded in Vivado with e.g.

  read_xdc -ref asynchronous_fifo /home/lukas/work/repo/hdl-modules/hdl-modules/modules/fifo/scoped_constraints/asynchronous_fifo.tcl

.. warning::
  In order for constraints to be applied and actually have an effect there are many
  build tool settings that need to be set correctly.
  See
  `this article <https://linkedin.com/pulse/reliable-cdc-constraints-4-build-tool-settings-lukas-vik-yknsc/>`__
  for more information.
  This is done automatically when using `tsfpga <https://tsfpga.com>`__.



Register interfaces
-------------------

Some modules in this project are controlled over a register bus and use
`hdl-registers <https://hdl-registers.com>`__ to generate register interface code.
For example :ref:`module_dma_axi_write_simple`.
When using `tsfpga <https://tsfpga.com>`__, register HDL code is automatically generated
and kept up to date in both simulation and build flow.

Manual workflow
_______________

When not using tsfpga, :ref:`VHDL code generation <generator_vhdl>` from
hdl-registers must be integrated in your simulation and build flow.
In order to access the registers on a target device,
:ref:`C <generator_c>` or :ref:`C++ <generator_cpp>`
code generation must probably be integrated in your FPGA/software build flow.


Feedback
--------

If you find any bugs or inconsistencies in this project, please
`start a discussion <https://github.com/hdl-modules/hdl-modules/discussions>`__
or `create an issue <https://github.com/hdl-modules/hdl-modules/issues>`__
on GitHub.
