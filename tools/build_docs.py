# --------------------------------------------------------------------------------------------------
# Copyright (c) Lukas Vik. All rights reserved.
#
# This file is part of the hdl_modules project.
# https://hdl-modules.com
# https://gitlab.com/tsfpga/hdl_modules
# --------------------------------------------------------------------------------------------------

import shutil

from pybadges import badge

import hdl_modules_tools_env

from tsfpga.module import get_modules
from tsfpga.module_documentation import ModuleDocumentation
from tsfpga.system_utils import create_directory, create_file, read_file
from tsfpga.tools.sphinx_doc import build_sphinx, generate_release_notes

GENERATED_SPHINX = hdl_modules_tools_env.HDL_MODULES_GENERATED / "sphinx_rst"
GENERATED_SPHINX_HTML = hdl_modules_tools_env.HDL_MODULES_GENERATED / "sphinx_html"
SPHINX_DOC = hdl_modules_tools_env.HDL_MODULES_DOC / "sphinx"


def main():
    rst = generate_release_notes(
        repo_root=hdl_modules_tools_env.REPO_ROOT,
        release_notes_directory=hdl_modules_tools_env.HDL_MODULES_DOC / "release_notes",
        project_name="hdl_modules",
    )
    create_file(GENERATED_SPHINX / "generated_release_notes.rst", rst)

    generate_documentation()

    # Copy files from documentation folder to build folder
    for name in [
        "conf.py",
        "contributing.rst",
        "license_information.rst",
        "release_notes.rst",
        "robots.txt",
        "css",
    ]:
        source = SPHINX_DOC / name

        if source.is_file():
            shutil.copyfile(source, GENERATED_SPHINX / name)
        else:
            shutil.copytree(source, GENERATED_SPHINX / name, dirs_exist_ok=True)

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
  :caption: HDL modules
  :hidden:

"""

    modules = get_modules(modules_folders=[hdl_modules_tools_env.HDL_MODULES_DIRECTORY])

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
        ModuleDocumentation(module).create_rst_document(
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

    def get_rst(include_link):
        extra_rst = (
            "**See documentation on the website**: https://hdl-modules.com\n"
            if include_link
            else ""
        )
        readme_rst = f"""\
About ``hdl_modules``
=====================

|pic_website| |pic_gitlab| |pic_gitter| |pic_license|

.. |pic_website| image:: https://hdl-modules.com/badges/website.svg
  :alt: Website
  :target: https://hdl-modules.com

.. |pic_gitlab| image:: https://hdl-modules.com/badges/gitlab.svg
  :alt: Gitlab
  :target: https://gitlab.com/tsfpga/hdl_modules

.. |pic_gitter| image:: https://badges.gitter.im/owner/repo.png
  :alt: Gitter
  :target: https://gitter.im/tsfpga/tsfpga

.. |pic_license| image:: https://hdl-modules.com/badges/license.svg
  :alt: License
  :target: https://hdl-modules.com/license_information.html

The hdl_modules project is a collection of reusable, high-quality, peer reviewed VHDL
building blocks.
It is released under the permissive BSD 3-Clause License.

{extra_rst}
The code is designed to be reusable and portable, while having a clean and intuitive interface.
Resource utilization is always critical in FPGA projects, so these modules are written to be as
efficient as possible.
Using generics to enable/disable different features and modes means that resources can be saved when
not all features are used.
Some entities are very deliberately area optimized, such as the :ref:`FIFOs <module_fifo>`, since
they are used very frequently in FPGA projects.

More important than anything, however, is the quality.
Everything in this project is peer reviewed, has good unit test coverage, and is proven in use in
real FPGA designs.
All the code is written with readability and maintainability in mind.

The following things can be found, at a glance, in the different modules:

* Crossbars, FIFOs, CDCs, etc., for AXI/AXI-Lite/AXI-Stream in the :ref:`axi module <module_axi>`.

* Many BFMs for AXI/AXI-Lite/AXI-Stream in the :ref:`bfm module <module_bfm>`.

* Some miscellaneous, but useful, things that do not fit anywhere else in the
  :ref:`common module <module_common>`.

* Synchronous and asynchronous FIFOs with AXI-stream-like handshake interface in the
  :ref:`fifo module <module_fifo>`.

* Wrappers, with cleaner AXI-stream-like handshake interfaces, around hard FIFO primitives in the
  :ref:`hard_fifo module <module_hard_fifo>`.

* Some common math function implementations in the :ref:`math module <module_math>`.

* A general register file, as well as a simulation package with register BFM operations,
  in the :ref:`reg_file module <module_reg_file>`.

* Resynchronization implementations for different signals and buses, along with proper constraints,
  in the :ref:`resync module <module_resync>`.
"""

        return readme_rst

    # First, verify readme.rst in repo root
    readme_rst = get_rst(include_link=True)
    if read_file(hdl_modules_tools_env.REPO_ROOT / "readme.rst") != readme_rst:
        file_path = create_file(GENERATED_SPHINX / "readme.rst", readme_rst)
        assert (
            False
        ), f"readme.rst in repo root not correct. Compare to reference in python: {file_path}"

    # Link shall not be included in the text that goes on the website
    return get_rst(include_link=False)


def build_information_badges():
    output_path = create_directory(GENERATED_SPHINX_HTML / "badges")

    badge_svg = badge(left_text="license", right_text="BSD 3-Clause", right_color="blue")
    create_file(output_path / "license.svg", badge_svg)

    badge_svg = badge(
        left_text="",
        right_text="tsfpga/hdl_modules",
        left_color="grey",
        right_color="grey",
        logo="https://about.gitlab.com/images/press/press-kit-icon.svg",
        embed_logo=True,
    )
    create_file(output_path / "gitlab.svg", badge_svg)

    badge_svg = badge(
        left_text="",
        right_text="hdl-modules.com",
        left_color="grey",
        right_color="grey",
        logo="https://design.firefox.com/product-identity/firefox/firefox/firefox-logo.svg",
        embed_logo=True,
    )
    create_file(output_path / "website.svg", badge_svg)


if __name__ == "__main__":
    main()
