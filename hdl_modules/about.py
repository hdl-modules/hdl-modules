# --------------------------------------------------------------------------------------------------
# Copyright (c) Lukas Vik. All rights reserved.
#
# This file is part of the hdl_modules project, a collection of reusable, high-quality,
# peer-reviewed VHDL building blocks.
# https://hdl-modules.com
# https://gitlab.com/hdl_modules/hdl_modules
# --------------------------------------------------------------------------------------------------


def get_short_slogan():
    """
    Short slogan used in e.g. Python documentation.

    Note that this slogan should be the same as the one used in the readme and on the website below.
    The difference is capitalization and whether the project name is included.
    """
    result = "A collection of reusable, high-quality, peer-reviewed VHDL building blocks"
    return result


def get_readme_rst(include_extra_for_gitlab=False, include_extra_for_website=False):
    """
    Get the complete README.rst (to be used on website).
    RST file inclusion in README.rst does not work on gitlab unfortunately, hence this
    cumbersome handling where the README is duplicated in two places.

    The arguments control some extra text that is included. This is mainly links to the
    other places where you can find information on the project (website, gitlab).

    Arguments:
        include_extra_for_gitlab (bool): Include the extra text that shall be included in the
            gitlab README.
        include_extra_for_website (bool): Include the extra text that shall be included in the
            website main page.
    """
    if include_extra_for_gitlab:
        readme_rst = ""
        extra_rst = "**See documentation on the website**: https://hdl-modules.com\n"

    elif include_extra_for_website:
        # The website needs the initial heading, in order for the landing page to get
        # the correct title.
        # Gitlab readme does not need this initial heading, it just makes it more clunky.
        readme_rst = """\
About hdl_modules
=================

"""
        extra_rst = """\
This website contains human-readable documentation of the modules.
To check out the source code, go to the
`gitlab page <https://gitlab.com/hdl_modules/hdl_modules>`__.
"""

    else:
        readme_rst = ""
        extra_rst = ""

    readme_rst += f"""\
|pic_website| |pic_gitlab| |pic_gitter| |pic_license|

.. |pic_website| image:: https://hdl-modules.com/badges/website.svg
  :alt: Website
  :target: https://hdl-modules.com

.. |pic_gitlab| image:: https://hdl-modules.com/badges/gitlab.svg
  :alt: Gitlab
  :target: https://gitlab.com/hdl_modules/hdl_modules

.. |pic_gitter| image:: https://hdl-modules.com/badges/gitter.svg
  :alt: Gitter
  :target: https://app.gitter.im/#/room/#60a276916da03739847cca54:gitter.im

.. |pic_license| image:: https://hdl-modules.com/badges/license.svg
  :alt: License
  :target: https://hdl-modules.com/license_information.html

The hdl_modules project is a collection of reusable, high-quality, peer-reviewed VHDL
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