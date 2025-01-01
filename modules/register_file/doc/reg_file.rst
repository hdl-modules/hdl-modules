The hdl-modules project contains many components that together form everything you need to set up a
register bus.
Below is a diagram of the typical layout for a register bus.

.. digraph:: my_graph

  graph [ dpi = 300 splines=ortho ];
  rankdir="LR";

  cpu [ label="AXI master\n(CPU)" shape=box ];
  cpu -> axi_to_axi_lite [label="AXI"];

  axi_to_axi_lite [ label="axi_to_axi_lite" shape=box ];
  axi_to_axi_lite -> axi_lite_mux  [label="AXI-Lite" ];

  axi_lite_mux [ label="axi_lite_mux" shape=box height=3.5 ];

  axi_lite_mux -> axi_lite_register_file0;
  axi_lite_register_file0 [ label="axi_lite_register_file" shape=box ];

  axi_lite_mux -> axi_lite_register_file1;
  axi_lite_register_file1 [ label="axi_lite_register_file" shape=box ];

  axi_lite_mux -> axi_lite_cdc2;
  axi_lite_cdc2 [ label="axi_lite_cdc" shape=box ];
  axi_lite_cdc2 -> axi_lite_register_file2;
  axi_lite_register_file2 [ label="axi_lite_register_file" shape=box ];

  axi_lite_mux -> axi_lite_cdc3;
  axi_lite_cdc3 [ label="axi_lite_cdc" shape=box ];
  axi_lite_cdc3 -> axi_lite_register_file3;
  axi_lite_register_file3 [ label="axi_lite_register_file" shape=box ];

  dots [ shape=none label="..."];
  axi_lite_mux -> dots;

In hdl-modules, the register bus used is is AXI-Lite.
In cases where a module uses a different clock than the AXI master (CPU), the bus must
be resynchronized.
This makes sure that each module's register values are always in the clock domain where they
are used.
This means that the module design does not have to worry about metastability, vector coherency,
pulse resynchronization, etc.

* :ref:`axi_lite.axi_to_axi_lite` is a simple protocol converter between AXI and AXI-Lite.
  It does not perform any burst splitting or handling of write strobes, but instead assumes the
  master to be well behaved.
  If this is not the case, AXI slave error (``SLVERR``) will be sent on the response
  channel (``R``/``B``).

* :ref:`axi_lite.axi_lite_mux` is a 1-to-N AXI-Lite multiplexer that operates based on base
  addresses specified via a generic.
  If the address requested by the master does not match any slave, AXI decode error (``DECERR``)
  will be sent on the response channel (``R``/``B``).
  There will still be proper AXI handshaking done, so the master will not be stalled.

* :ref:`axi_lite.axi_lite_cdc` is an asynchronous FIFO-based clock domain crossing (CDC) for
  AXI-Lite buses.
  It must be used in the cases where the ``axi_lite_register_file`` (i.e. your module) is in a different
  clock domain than the CPU AXI master.

* :ref:`reg_file.axi_lite_register_file` is a generic, parameterizable, register file for AXI-Lite
  register buses.
  It is parameterizable via a generic that sets the list of registers, with their modes and their
  default values.
  If the address requested by the master does not match any register, or there is a
  mode mismatch (e.g. write to a read-only register), AXI slave error (``SLVERR``) will be sent on
  the response channel (``R``/``B``).

Note that there is also a convenience wrapper :ref:`axi_lite.axi_to_axi_lite_vec` that instantiates
:ref:`axi_lite.axi_to_axi_lite`, :ref:`axi_lite.axi_lite_mux` and any necessary
:ref:`axi_lite.axi_lite_cdc` based on the appropriate generics.

