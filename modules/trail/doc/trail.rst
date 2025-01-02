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
   These are annotated "N" and "M" in the example waveform above.

2. An operation transaction occurs when ``operation.enable`` is **1** at a rising clock edge.

3. A response transaction occurs when ``response.enable`` is **1** at a rising clock edge.

4. If ``write_enable`` is **1** when an operation transaction occurs, it is a **write** operation.
   Otherwise it is a **read** operation.


.. _trail_rules:

Rules
_____

1. The **data width** MUST be a positive power-of-two-multiple of 8.

2. Further operation transactions MUST NOT be performed until response transactions have occurred
   for all previous operations.

3. The operation payload (``address``, ``write_enable``, and ``write_data``) MUST hold valid values
   from the point where ``operation.enable`` is asserted until the point where a
   response transaction occurs.

   a. **Read** operations MAY have undefined ``write_data`` values.

4. The response payload (``status`` and ``read_data``) MUST hold valid values from the point where
   ``response.enable`` is asserted until the point where the next operation transaction occurs.

   a. Responses to **write** operations MAY have undefined ``read_data`` values.

5. Only word-aligned operations are supported.
   Meaning, the lowest :math:`\log_2 \left( \text{data width} / 8\right)` bits of the ``address``
   MUST be zero when an operation transaction occurs.
