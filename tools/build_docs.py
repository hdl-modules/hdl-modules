# --------------------------------------------------------------------------------------------------
# Copyright (c) Lukas Vik. All rights reserved.
#
# This file is part of the hdl_modules project, a collection of reusable, high-quality,
# peer-reviewed VHDL building blocks.
# https://hdl-modules.com
# https://gitlab.com/hdl_modules/hdl_modules
# --------------------------------------------------------------------------------------------------

# Standard libraries
import shutil
import sys
from pathlib import Path

# Do PYTHONPATH insert() instead of append() to prefer any local repo checkout over any pip install
REPO_ROOT = Path(__file__).parent.parent.resolve()
sys.path.insert(0, str(REPO_ROOT))

# Import before others since it modifies PYTHONPATH. pylint: disable=unused-import
import tools.tools_pythonpath  # noqa: F401

# Third party libraries
from pybadges import badge
from tsfpga.module import get_modules
from tsfpga.module_documentation import ModuleDocumentation
from tsfpga.system_utils import create_directory, create_file, read_file
from tsfpga.tools.sphinx_doc import build_sphinx, generate_release_notes
from tsfpga.vhdl_file_documentation import VhdlFileDocumentation

# First party libraries
from tools import tools_env

GENERATED_SPHINX = tools_env.HDL_MODULES_GENERATED / "sphinx_rst"
GENERATED_SPHINX_HTML = tools_env.HDL_MODULES_GENERATED / "sphinx_html"
SPHINX_DOC = tools_env.HDL_MODULES_DOC / "sphinx"


def main():
    rst = generate_release_notes(
        repo_root=tools_env.REPO_ROOT,
        release_notes_directory=tools_env.HDL_MODULES_DOC / "release_notes",
        project_name="hdl_modules",
    )
    create_file(GENERATED_SPHINX / "generated_release_notes.rst", rst)

    generate_documentation()

    # Copy files from documentation folder to build folder
    for path in SPHINX_DOC.glob("*"):
        if path.is_file():
            shutil.copyfile(path, GENERATED_SPHINX / path.name)
        else:
            shutil.copytree(path, GENERATED_SPHINX / path.name, dirs_exist_ok=True)

    build_sphinx(build_path=GENERATED_SPHINX, output_path=GENERATED_SPHINX_HTML)

    build_information_badges()


def generate_documentation():
    index_rst = f"""
{get_readme_rst()}

.. toctree::
  :caption: About
  :hidden:

  license_information
  contributing
  release_notes


.. toctree::
  :caption: User guide
  :hidden:

  getting_started


.. toctree::
  :caption: Modules
  :hidden:

"""

    modules = get_modules(modules_folders=[tools_env.HDL_MODULES_DIRECTORY])

    # Sort by module name
    def sort_key(module):
        return module.name

    modules = sorted(modules, key=sort_key)

    for module in modules:
        index_rst += f"  modules/{module.name}/{module.name}\n"

        output_path = GENERATED_SPHINX / "modules" / module.name

        # Exclude the "rtl/" folder within each module from documentation.
        # With our chosen module structure we only place netlist build wrappers there, which we
        # do not want included in the documentation.
        HdlModulesModuleDocumentation(module).create_rst_document(
            output_path=output_path, exclude_module_folders=["rtl"]
        )

        # Copy further files from the modules' "doc" folder that might be included.
        # For example an image in the "doc" folder might be included in the document.
        module_doc_folder = module.path / "doc"
        module_doc_rst = module_doc_folder / f"{module.name}.rst"

        for doc_file in module_doc_folder.glob("*"):
            if doc_file.is_file() and doc_file != module_doc_rst:
                shutil.copy(doc_file, output_path)

    create_file(GENERATED_SPHINX / "index.rst", index_rst)


def get_readme_rst():
    """
    Get the complete README.rst to be used on website.

    Will also verify that readme.rst in the project root is identical.
    RST file inclusion in README.rst does not work on gitlab unfortunately, hence this
    cumbersome handling where the README is duplicated in two places.
    """

    def get_rst(include_link_to_website=False, include_link_to_gitlab=False):
        if include_link_to_website:
            extra_rst = "**See documentation on the website**: https://hdl-modules.com\n"
        elif include_link_to_gitlab:
            extra_rst = """\
This website contains human-readable documentation of the modules.
To check out the source code, go to the
`gitlab page <https://gitlab.com/hdl_modules/hdl_modules>`__.
"""
        else:
            extra_rst = ""

        readme_rst = f"""\
About hdl_modules
=================

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
It is released as open source project under the very permissive BSD 3-Clause License.

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

    # First, verify readme.rst in repo root. The text shall link to the website.
    readme_rst = get_rst(include_link_to_website=True)
    if read_file(tools_env.REPO_ROOT / "readme.rst") != readme_rst:
        file_path = create_file(GENERATED_SPHINX / "readme.rst", readme_rst)
        assert (
            False
        ), f"readme.rst in repo root not correct. Compare to reference in python: {file_path}"

    # Text that goes on website shall include link to gitlab.
    return get_rst(include_link_to_gitlab=True)


class HdlModulesModuleDocumentation(ModuleDocumentation):
    """
    Custom documentation class for this project, overrides methods where we want to change
    the behavior.
    """

    def _get_vhdl_file_rst(
        self, vhdl_file_path, heading_character, heading_character_2, netlist_builds
    ):
        """
        Get reStructuredText documentation for a VHDL file.

        Identical to the method in the parent class, but also adds a link to gitlab.
        """
        vhdl_file_documentation = VhdlFileDocumentation(vhdl_file_path)

        file_rst = vhdl_file_documentation.get_header_rst()
        file_rst = "" if file_rst is None else file_rst

        symbolator_rst = self._get_symbolator_rst(vhdl_file_documentation)
        symbolator_rst = "" if symbolator_rst is None else symbolator_rst

        resource_utilization_rst = self._get_resource_utilization_rst(
            vhdl_file_path=vhdl_file_path,
            heading_character=heading_character_2,
            netlist_builds=netlist_builds,
        )

        entity_name = vhdl_file_path.stem
        heading = f"{vhdl_file_path.name}"
        heading_underline = heading_character * len(heading)

        base_url = "https://gitlab.com/hdl_modules/hdl_modules/-/tree/main/modules"
        relative_path = f"{self._module.name}/{vhdl_file_path.parent.name}/{vhdl_file_path.name}"

        rst = f"""
.. _{self._module.name}.{entity_name}:

{heading}
{heading_underline}

`View source code on gitlab.com <{base_url}/{relative_path}>`__.

{symbolator_rst}

{file_rst}

{resource_utilization_rst}
"""

        return rst


def build_information_badges():
    output_path = create_directory(GENERATED_SPHINX_HTML / "badges")

    badge_svg = badge(left_text="license", right_text="BSD 3-Clause", right_color="blue")
    create_file(output_path / "license.svg", badge_svg)

    badge_svg = badge(
        left_text="",
        right_text="hdl_modules/hdl_modules",
        left_color="grey",
        right_color="grey",
        logo=str(tools_env.HDL_MODULES_DOC / "logos" / "third_party" / "gitlab.svg"),
        embed_logo=True,
    )
    create_file(output_path / "gitlab.svg", badge_svg)

    badge_svg = badge(
        left_text="",
        right_text="hdl-modules.com",
        left_color="grey",
        right_color="grey",
        logo=str(tools_env.HDL_MODULES_DOC / "logos" / "third_party" / "firefox.svg"),
        embed_logo=True,
    )
    create_file(output_path / "website.svg", badge_svg)

    badge_svg = badge(
        left_text="chat",
        right_text="on gitter",
        left_color="#5a5a5a",
        right_color="#41ab8b",
    )
    create_file(output_path / "gitter.svg", badge_svg)


if __name__ == "__main__":
    main()
