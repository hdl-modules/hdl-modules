# --------------------------------------------------------------------------------------------------
# Copyright (c) Lukas Vik. All rights reserved.
#
# This file is part of the hdl-modules project, a collection of reusable, high-quality,
# peer-reviewed VHDL building blocks.
# https://hdl-modules.com
# https://github.com/hdl-modules/hdl-modules
# --------------------------------------------------------------------------------------------------


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
    RST file inclusion in README.rst does not work on github unfortunately, hence this
    cumbersome handling where the README is duplicated in two places.

    The arguments control some extra text that is included. This is mainly links to the
    other places where you can find information on the project (website, github).

    Arguments:
        include_extra_for_github (bool): Include the extra text that shall be included in the
            github README.
        include_extra_for_website (bool): Include the extra text that shall be included in the
            website main page.
    """
    if include_extra_for_github:
        readme_rst = ""
        extra_rst = "**See documentation on the website**: https://hdl-modules.com\n"

    elif include_extra_for_website:
        # The website needs the initial heading, in order for the landing page to get
        # the correct title.
        # Github readme does not need this initial heading, it just makes it more clunky.
        readme_rst = """\
About hdl-modules
=================

"""
        extra_rst = """\
This website contains human-readable documentation of the modules.
To check out the source code, go to the
`GitHub page <https://github.com/hdl-modules/hdl-modules>`__.
"""

    else:
        readme_rst = ""
        extra_rst = ""

    readme_rst += f"""\
.. image:: https://hdl-modules.com//logos/banner.png
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

.. |pic_ci_status| image:: https://github.com/hdl-modules/hdl-modules/actions/workflows/ci.yml/\
badge.svg?branch=main
  :alt: CI status
  :target: https://github.com/hdl-modules/hdl-modules/actions/workflows/ci.yml

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
`FIFOs <https://hdl-modules.com/modules/fifo/fifo.html>`__, since they are used very frequently in
FPGA projects.

More important than anything, however, is the quality.
Everything in this project is peer reviewed, has good unit test coverage, and is proven in use in
real FPGA designs.
All the code is written with readability and maintainability in mind.

The following things can be found, at a glance, in the different modules:

* Crossbars, FIFOs, CDCs, etc., for AXI/AXI-Lite/AXI-Stream in the
  `axi module <https://hdl-modules.com/modules/axi/axi.html>`__.

* Many BFMs for simulating AXI/AXI-Lite/AXI-Stream in the
  `bfm module <https://hdl-modules.com/modules/bfm/bfm.html>`__.

* Some miscellaneous, but useful, things that do not fit anywhere else in the
  `common module <https://hdl-modules.com/modules/common/common.html>`__.

* Synchronous and asynchronous FIFOs with AXI-stream-like handshake interface in the
  `fifo module <https://hdl-modules.com/modules/fifo/fifo.html>`__.

* Wrappers, with cleaner AXI-stream-like handshake interfaces, around hard FIFO primitives in the
  `hard_fifo module <https://hdl-modules.com/modules/hard_fifo/hard_fifo.html>`__.

* Some common math function implementations in the
  `math module <https://hdl-modules.com/modules/math/math.html>`__.

* A generic register file, as well as a simulation package with register BFM operations, in the
  `reg_file module <https://hdl-modules.com/modules/reg_file/reg_file.html>`__.

* Resynchronization implementations for different signals and buses, along with proper constraints,
  in the `resync module <https://hdl-modules.com/modules/resync/resync.html>`__.
"""

    return readme_rst
