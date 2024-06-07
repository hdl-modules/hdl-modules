This module contains a large set of VHDL entities for clock domain crossing (CDC) of data in
an FPGA.
Everything in this module is properly and carefully constrained, and has a thought-out structure
to ensure stable operation.

Note that most of the entities in this module have :ref:`scoped constraint <scoped_constraints>`
files that must be used for proper operation.
This also means that certain build tool settings need to be considered for the
constraints to work.
Please see this article
`this article <https://linkedin.com/pulse/reliable-cdc-constraints-4-build-tool-settings-lukas-vik-yknsc/>`__
for details.

See :ref:`fifo.asynchronous_fifo` if you want to use asynchronous FIFO as a CDC solution.
For AXI buses, there is also :ref:`axi.axi_address_fifo`, :ref:`axi.axi_r_fifo`,
:ref:`axi.axi_w_fifo`, :ref:`axi.axi_b_fifo`, :ref:`axi.axi_read_cdc`, :ref:`axi.axi_write_cdc`.
