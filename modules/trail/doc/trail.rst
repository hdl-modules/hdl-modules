.. figure:: trail_frame.png

TRAIL is an open-source and community-driven register bus specification for FPGA projects.
Compared to other options (AXI-Lite, Avalon-MM, Wishbone), TRAIL offers

1. lower resource usage (LUT, FF),
2. lower latency,
3. lower complexity (fewer bugs),
4. no vendor lock-in,
5. :ref:`reference designs <trail_bus_layout>` for all necessary components.



Specification
-------------

The TRAIL register bus specification is explained by the waveform example below, as well as
the :ref:`trail_definitions` and :ref:`trail_rules`.

.. wavedrom::

  {
    "signal": [
      { "name": "clk",             "wave": "p........." },
      {},
      ["operation",
        { "name": "enable",        "wave": "010...10.." },
        { "name": "address[N]",    "wave": "x6..x.4.x." },
        { "name": "write_enable",  "wave": "x6..x.4.x." },
        { "name": "write_data[M]", "wave": "x6..x.4.x." },
      ],
      {},
      ["response",
        { "name": "enable",        "wave": "0..10..10." },
        { "name": "status",        "wave": "x..7...3.." },
        { "name": "read_data[M]",  "wave": "x..7...3.." },
      ],
    ],
    "foot": {
      "text": "Typical TRAIL transactions."
    },
  }


.. _trail_definitions:

Definitions
___________

1. Each TRAIL bus instance has an intrinsic **address width** and **data width** that are specified
   at compile time.
   These are annotated "N" and "M" in the waveform above.

2. An **operation transaction** occurs when ``operation.enable`` is 1 at a rising clock edge.

3. A **response transaction** occurs when ``response.enable`` is 1 at a rising clock edge.

4. If ``write_enable`` is 1 when an operation transaction occurs, it is a **write operation**.
   Otherwise it is a **read operation**.


.. _trail_rules:

Rules
_____

1. The data width MUST be either 8, 16, 32, or 64 bits.

2. Further operation transactions MUST NOT be performed until response transactions have occurred
   for all previous operations.

3. The operation transaction payload (``address``, ``write_enable``, and ``write_data``)
   MUST be held constant until the corresponding response transaction occurs.

   a. Read operations MAY have undefined/changing ``write_data`` values.

4. The response transaction payload (``status`` and ``read_data``) MUST be held constant until
   the next operation transaction occurs.

   a. Responses to write operations MAY have undefined/changing ``read_data`` values.

5. Only word-aligned operations are supported.
   Meaning, the lowest :math:`\log_2 \left( \text{data width} / 8\right)` bits of the ``address``
   MUST be zero when an operation transaction occurs.



.. _trail_bus_layout:

Register bus layout
-------------------

The register bus layout for a typical FPGA project is shown below.

.. digraph:: my_graph

  graph [dpi=300 splines=ortho];
  rankdir="LR";

  cpu [label="AXI master\n(CPU)" shape="box"];
  cpu -> axi_to_trail [label="AXI"];

  axi_to_trail [label="axi_to_trail" shape="box"];
  axi_to_trail -> trail_splitter  [label="TRAIL"];

  trail_splitter [label="trail_splitter" shape="box" height=3];

  trail_splitter -> trail_register_file0;
  trail_register_file0 [label="trail_register_file" shape="box"];

  trail_splitter -> trail_pipeline;
  trail_pipeline [label="trail_pipeline" shape="box"];
  trail_pipeline -> trail_register_file1;
  trail_register_file1 [label="trail_register_file" shape="box"];

  trail_splitter -> trail_cdc;
  trail_cdc [label="trail_cdc" shape="box"];
  trail_cdc -> trail_register_file2;
  trail_register_file2 [label="trail_register_file" shape="box"];

  dots [shape=none label="..."];
  trail_splitter -> dots;

Reference implementations for all these bus components are provided below:

* To convert the bus format to TRAIL: :ref:`trail.axi_to_trail` (or :ref:`trail.axi_lite_to_trail`)
* To split the bus for the different modules in the system: :ref:`trail.trail_splitter`
* If there is a timing problem on the bus, a pipeline can be used: :ref:`trail.trail_pipeline`
* If the module is in another clock domain, a crossing can be used: :ref:`trail.trail_cdc`
* Generic register file that handles register values to/from the user application:
  :ref:`register_file.trail_register_file`

All the reference designs have low latency and very low resource utilization.



Simulation
__________

In order to work effectively with TRAIL we need good testbench support components:

.. digraph:: my_graph

  graph [dpi=300 splines="ortho"];
  rankdir="LR";

  trail_bfm_master [label="trail_bfm_master\n+\ntrail_protocol_checker" shape="box" height=1.5];
  trail_bfm_master -> dut [label="operation" dir="back"];
  trail_bfm_master -> dut [label="response"];

  dut [label="DUT" shape="box" width=1 height=1.5];
  dut -> trail_bfm_slave [label="operation" dir="back"];
  dut -> trail_bfm_slave [label="response"];

  trail_bfm_slave [label="trail_bfm_slave\n+\ntrail_protocol_checker" shape="box" height=1.5];

The following is provided in this library:

* Create stimuli operations and verify responses: :ref:`trail.trail_bfm_master`
* Provide responses to operations: :ref:`trail.trail_bfm_slave`
* Verify that all TRAIL rules are followed: :ref:`trail.trail_protocol_checker`
