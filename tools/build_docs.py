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
from hdl_modules.about import get_readme_rst, get_short_slogan
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

    generate_bibtex()

    generate_documentation()

    # Copy files from documentation folder to build folder
    for path in SPHINX_DOC.glob("*"):
        if path.is_file():
            shutil.copyfile(path, GENERATED_SPHINX / path.name)
        else:
            shutil.copytree(path, GENERATED_SPHINX / path.name, dirs_exist_ok=True)

    logos_path = create_directory(GENERATED_SPHINX_HTML / "logos")
    shutil.copy2(tools_env.HDL_MODULES_DOC / "logos" / "banner.png", logos_path)

    build_sphinx(build_path=GENERATED_SPHINX, output_path=GENERATED_SPHINX_HTML)

    build_information_badges()


def generate_bibtex():
    """
    Generate a BibTeX snippet for citing this project.

    Since BibTeX also uses curly braces, f-string formatting is hard here.
    Hence the string is split up.
    """
    rst_before = """\
.. code-block:: tex

  @misc{hdl_modules,
    author = {Vik, Lukas},
    title  = {{hdl\\_modules: """

    rst_after = """}},
    url    = {https://hdl-modules.com},
  }
"""

    rst = f"{rst_before}{get_short_slogan()}{rst_after}"

    create_file(GENERATED_SPHINX / "bibtex.rst", rst)


def generate_documentation():
    index_rst = f"""
{get_readme()}

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


def get_readme():
    """
    Get the complete README.rst to be used on website.

    Will also verify that readme.rst in the project root is identical.
    RST file inclusion in README.rst does not work on gitlab unfortunately, hence this
    cumbersome handling where the README is duplicated in two places.
    """
    # First, verify readme.rst in repo root
    readme_rst = get_readme_rst(include_extra_for_gitlab=True)
    if read_file(tools_env.REPO_ROOT / "readme.rst") != readme_rst:
        file_path = create_file(GENERATED_SPHINX / "readme.rst", readme_rst)
        assert (
            False
        ), f"readme.rst in repo root not correct. Compare to reference in python: {file_path}"

    return get_readme_rst(include_extra_for_website=True)


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

        Identical to the method in the super class, but also adds a link to gitlab.
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
    create_file(output_path / "repository.svg", badge_svg)

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
    create_file(output_path / "chat.svg", badge_svg)


if __name__ == "__main__":
    main()
