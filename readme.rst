.. image:: https://hdl-modules.com/logos/banner.png
  :alt: Project banner
  :align: center

|

.. |pic_website| image:: https://hdl-modules.com/badges/website.svg
  :alt: Website
  :target: https://hdl-modules.com

.. |pic_repository| image:: https://hdl-modules.com/badges/repository.svg
  :alt: Repository
  :target: https://github.com/hdl-modules/hdl-modules

.. |pic_chat| image:: https://hdl-modules.com/badges/chat.svg
  :alt: Chat
  :target: https://github.com/hdl-modules/hdl-modules/discussions

.. |pic_license| image:: https://hdl-modules.com/badges/license.svg
  :alt: License
  :target: https://hdl-modules.com/license_information.html

.. |pic_ci_status| image:: https://github.com/hdl-modules/hdl-modules/actions/workflows/ci.yml/badge.svg?branch=main
  :alt: CI status
  :target: https://github.com/hdl-modules/hdl-modules/actions/workflows/ci.yml

|pic_website| |pic_repository| |pic_license| |pic_chat| |pic_ci_status|

The hdl-modules project is a collection of reusable, high-quality, peer-reviewed VHDL
building blocks.
It is released as open-source project under the very permissive BSD 3-Clause License.

**See documentation on the website**: https://hdl-modules.com

The code is designed to be reusable and portable, while having a clean and intuitive interface.
Resource utilization is always critical in FPGA projects, so these modules are written to be as
efficient as possible.
Using generics to enable/disable different features and modes means that resources can be saved when
not all features are used.
Some entities are very deliberately area optimized, such as the
`FIFOs <https://hdl-modules.com/modules/fifo/fifo.html>`_, since they are used very frequently in
FPGA projects.

More important than anything, however, is the quality.
Everything in this project is peer reviewed, has good unit test coverage, and is proven in use in
real FPGA designs.
All the code is written with readability and maintainability in mind.

The following things can be found, at a glance, in the different modules:

* `axi <https://hdl-modules.com/modules/axi/axi.html>`_:
  AXI3/AXI4 Crossbars, FIFOs, CDCs, etc.

* `axi_lite <https://hdl-modules.com/modules/axi_lite/axi_lite.html>`_:
  AXI-Lite Crossbars, FIFOs, CDCs, etc.

* `bfm <https://hdl-modules.com/modules/bfm/bfm.html>`_:
  Many BFMs for simulating AXI/AXI-Lite/AXI-Stream.

* `common <https://hdl-modules.com/modules/common/common.html>`_:
  Miscellaneous, but useful, things that do not fit anywhere else.

* `fifo <https://hdl-modules.com/modules/fifo/fifo.html>`_:
  Synchronous and asynchronous FIFOs with AXI-stream-like handshake interface.

* `hard\_fifo <https://hdl-modules.com/modules/hard_fifo/hard_fifo.html>`_:
  Wrappers, with cleaner AXI-stream-like handshake interfaces, around hard FIFO primitives.

* `lfsr <https://hdl-modules.com/modules/lfsr/lfsr.html>`_:
  Maximum-length linear feedback shift registers for pseudo-random number generation.

* `math <https://hdl-modules.com/modules/math/math.html>`_:
  Some common math function implementations.

* `reg\_file <https://hdl-modules.com/modules/reg_file/reg_file.html>`_:
  A generic register file and a simulation support package for register operations.

* `resync <https://hdl-modules.com/modules/resync/resync.html>`_:
  CDC implementations for different signals and buses, along with proper constraints.

* `sine_generator <https://hdl-modules.com/modules/sine_generator/sine_generator.html>`_:
  Professional sinusoid waveform generator (or DDS, NCO).
