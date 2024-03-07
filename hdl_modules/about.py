# --------------------------------------------------------------------------------------------------
# Copyright (c) Lukas Vik. All rights reserved.
#
# This file is part of the hdl-modules project, a collection of reusable, high-quality,
# peer-reviewed VHDL building blocks.
# https://hdl-modules.com
# https://github.com/hdl-modules/hdl-modules
# --------------------------------------------------------------------------------------------------


REPOSITORY_URL = "https://github.com/hdl-modules/hdl-modules"
WEBSITE_URL = "https://hdl-modules.com"


def get_short_slogan() -> str:
    """
    Short slogan used in e.g. Python documentation.

    Note that this slogan should be the same as the one used in the readme and on the website below.
    The difference is capitalization and whether the project name is included.
    """
    result = "A collection of reusable, high-quality, peer-reviewed VHDL building blocks"
    return result


def get_readme_rst(
    include_extra_for_github: bool = False, include_extra_for_website: bool = False
) -> str:
    """
    Get the complete README.rst (to be used on website).
    RST file inclusion in README.rst does not work on GitHub unfortunately, hence this
    cumbersome handling where the README is duplicated in two places.

    The arguments control some extra text that is included. This is mainly links to the
    other places where you can find information on the project (website, GitHub).

    Arguments:
        include_extra_for_github (bool): Include the extra text that shall be included in the
            GitHub README.
        include_extra_for_website (bool): Include the extra text that shall be included in the
            website main page.
    """
    if include_extra_for_github:
        readme_rst = ""
        extra_rst = f"**See documentation on the website**: {WEBSITE_URL}\n"

    elif include_extra_for_website:
        # The website needs the initial heading, in order for the landing page to get
        # the correct title.
        # GitHub readme does not need this initial heading, it just makes it more clunky.
        readme_rst = """\
About hdl-modules
=================

"""
        extra_rst = f"""\
This website contains human-readable documentation of the modules.
To check out the source code, go to the
`GitHub page <{REPOSITORY_URL}>`_.
"""

    else:
        readme_rst = ""
        extra_rst = ""

    readme_rst += f"""\
.. image:: {WEBSITE_URL}/logos/banner.png
  :alt: Project banner
  :align: center

|

.. |pic_website| image:: {WEBSITE_URL}/badges/website.svg
  :alt: Website
  :target: {WEBSITE_URL}

.. |pic_repository| image:: {WEBSITE_URL}/badges/repository.svg
  :alt: Repository
  :target: {REPOSITORY_URL}

.. |pic_chat| image:: {WEBSITE_URL}/badges/chat.svg
  :alt: Chat
  :target: {REPOSITORY_URL}/discussions

.. |pic_license| image:: {WEBSITE_URL}/badges/license.svg
  :alt: License
  :target: {WEBSITE_URL}/license_information.html

.. |pic_ci_status| image:: {REPOSITORY_URL}/actions/workflows/ci.yml/badge.svg?branch=main
  :alt: CI status
  :target: {REPOSITORY_URL}/actions/workflows/ci.yml

|pic_website| |pic_repository| |pic_license| |pic_chat| |pic_ci_status|

The hdl-modules project is a collection of reusable, high-quality, peer-reviewed VHDL
building blocks.
It is released as open-source project under the very permissive BSD 3-Clause License.

{extra_rst}
The code is designed to be reusable and portable, while having a clean and intuitive interface.
Resource utilization is always critical in FPGA projects, so these modules are written to be as
efficient as possible.
Using generics to enable/disable different features and modes means that resources can be saved when
not all features are used.
Some entities are very deliberately area optimized, such as the
`FIFOs <{WEBSITE_URL}/modules/fifo/fifo.html>`_, since they are used very frequently in
FPGA projects.

More important than anything, however, is the quality.
Everything in this project is peer reviewed, has good unit test coverage, and is proven in use in
real FPGA designs.
All the code is written with readability and maintainability in mind.

The following things can be found, at a glance, in the different modules:

* `axi <{WEBSITE_URL}/modules/axi/axi.html>`_:
  AXI3/AXI4 Crossbars, FIFOs, CDCs, etc.

* `axi_lite <{WEBSITE_URL}/modules/axi_lite/axi_lite.html>`_:
  AXI-Lite Crossbars, FIFOs, CDCs, etc.

* `bfm <{WEBSITE_URL}/modules/bfm/bfm.html>`_:
  Many BFMs for simulating AXI/AXI-Lite/AXI-Stream.

* `common <{WEBSITE_URL}/modules/common/common.html>`_:
  Miscellaneous, but useful, things that do not fit anywhere else.

* `fifo <{WEBSITE_URL}/modules/fifo/fifo.html>`_:
  Synchronous and asynchronous FIFOs with AXI-stream-like handshake interface.

* `hard\\_fifo <{WEBSITE_URL}/modules/hard_fifo/hard_fifo.html>`_:
  Wrappers, with cleaner AXI-stream-like handshake interfaces, around hard FIFO primitives.

* `lfsr <{WEBSITE_URL}/modules/lfsr/lfsr.html>`_:
  Maximum-length linear feedback shift registers for pseudo-random number generation.

* `math <{WEBSITE_URL}/modules/math/math.html>`_:
  Some common math function implementations.

* `reg\\_file <{WEBSITE_URL}/modules/reg_file/reg_file.html>`_:
  A generic register file and a simulation support package for register operations.

* `resync <{WEBSITE_URL}/modules/resync/resync.html>`_:
  Resynchronization implementations for different signals and buses, along with proper constraints.

* `sine_generator <{WEBSITE_URL}/modules/sine_generator/sine_generator.html>`_:
  Professional sinusoid waveform generator (or DDS, NCO).
"""

    return readme_rst
