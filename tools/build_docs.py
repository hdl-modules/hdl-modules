# --------------------------------------------------------------------------------------------------
# Copyright (c) Lukas Vik. All rights reserved.
#
# This file is part of the hdl-modules project, a collection of reusable, high-quality,
# peer-reviewed VHDL building blocks.
# https://hdl-modules.com
# https://github.com/hdl-modules/hdl-modules
# --------------------------------------------------------------------------------------------------

# Standard libraries
import shutil
import sys
from pathlib import Path
from typing import TYPE_CHECKING

# Do PYTHONPATH insert() instead of append() to prefer any local repo checkout over any pip install
REPO_ROOT = Path(__file__).parent.parent.resolve()
sys.path.insert(0, str(REPO_ROOT))

# Import before others since it modifies PYTHONPATH. pylint: disable=unused-import
import tools.tools_pythonpath  # noqa: F401

# Third party libraries
from pybadges import badge
from tsfpga import TSFPGA_DOC
from tsfpga.module import get_modules
from tsfpga.module_documentation import ModuleDocumentation
from tsfpga.system_utils import create_directory, create_file, read_file
from tsfpga.tools.sphinx_doc import build_sphinx, generate_release_notes

# First party libraries
from hdl_modules import REPO_ROOT
from hdl_modules.about import REPOSITORY_URL, WEBSITE_URL, get_readme_rst, get_short_slogan
from tools import tools_env

if TYPE_CHECKING:
    # Third party libraries
    from tsfpga.module import BaseModule

GENERATED_SPHINX = tools_env.HDL_MODULES_GENERATED / "sphinx_rst"
GENERATED_SPHINX_HTML = tools_env.HDL_MODULES_GENERATED / "sphinx_html"
SPHINX_DOC = tools_env.HDL_MODULES_DOC / "sphinx"

BADGE_COLOR_LEFT = "#32383f"
BADGE_COLOR_RIGHT = "#2db84d"


def main() -> None:
    generate_and_create_release_notes()

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


def generate_and_create_release_notes() -> None:
    release_notes_rst = generate_release_notes(
        repo_root=tools_env.REPO_ROOT,
        release_notes_directory=tools_env.HDL_MODULES_DOC / "release_notes",
        project_name="hdl-modules",
    )

    rst = f"""
Release notes
=============

Release history and changelog for the ``hdl-modules`` project.

{release_notes_rst}
"""

    create_file(GENERATED_SPHINX / "release_notes.rst", rst)


def generate_bibtex() -> None:
    """
    Generate a BibTeX snippet for citing this project.

    Since BibTeX also uses curly braces, f-string formatting is hard here.
    Hence the string is split up.
    """
    rst_before = """\
.. code-block:: tex

  @misc{hdl-modules,
    author = {Vik, Lukas},
    title  = {{hdl-modules: """

    rst_after = f"""}}}},
    url    = {{{WEBSITE_URL}}},
  }}
"""

    rst = f"{rst_before}{get_short_slogan()}{rst_after}"

    create_file(GENERATED_SPHINX / "bibtex.rst", rst)


def generate_documentation() -> None:
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
    def sort_key(module: "BaseModule") -> str:
        return module.name

    modules_sorted: list["BaseModule"] = sorted(modules, key=sort_key)

    for module in modules_sorted:
        index_rst += f"  modules/{module.name}/{module.name}\n"

        output_path = GENERATED_SPHINX / "modules" / module.name

        # Exclude the "rtl/" folder within each module from documentation.
        # With our chosen module structure we only place netlist build wrappers there, which we
        # do not want included in the documentation.
        ModuleDocumentation(
            module=module,
            repository_url=f"{REPOSITORY_URL}/tree/main/{module.path.relative_to(REPO_ROOT)}",
            repository_name="GitHub",
        ).create_rst_document(output_path=output_path, exclude_module_folders=["rtl"])

        # Copy further files from the modules' "doc" folder that might be included.
        # For example an image in the "doc" folder might be included in the document.
        module_doc_folder = module.path / "doc"
        module_doc_rst = module_doc_folder / f"{module.name}.rst"

        for doc_file in module_doc_folder.glob("*"):
            if doc_file.is_file() and doc_file != module_doc_rst:
                shutil.copy(doc_file, output_path)

        # Copy image files that may or may not be used in the module documentation.
        for image_file in (TSFPGA_DOC / "symbols").glob("*.png"):
            shutil.copyfile(image_file, output_path / image_file.name)

    create_file(GENERATED_SPHINX / "index.rst", index_rst)


def get_readme() -> str:
    """
    Get the complete README.rst to be used on website.

    Will also verify that readme.rst in the project root is identical.
    RST file inclusion in README.rst does not work on GitHub unfortunately, hence this
    cumbersome handling where the README is duplicated in two places.
    """
    # First, verify readme.rst in repo root
    readme_rst = get_readme_rst(include_extra_for_github=True)
    if read_file(tools_env.REPO_ROOT / "readme.rst") != readme_rst:
        file_path = create_file(GENERATED_SPHINX / "readme.txt", readme_rst)
        assert (
            False
        ), f"readme.rst in repo root not correct. Compare to reference in python: {file_path}"

    return get_readme_rst(include_extra_for_website=True)


def build_information_badges() -> None:
    output_path = create_directory(GENERATED_SPHINX_HTML / "badges")

    badge_svg = badge(
        left_text="license",
        right_text="BSD 3-Clause",
        left_color=BADGE_COLOR_LEFT,
        right_color=BADGE_COLOR_RIGHT,
        logo=str(tools_env.HDL_MODULES_DOC / "logos" / "third_party" / "law.svg"),
        embed_logo=True,
    )
    create_file(output_path / "license.svg", badge_svg)

    badge_svg = badge(
        left_text="github",
        right_text="hdl-modules/hdl-modules",
        left_color=BADGE_COLOR_LEFT,
        right_color=BADGE_COLOR_RIGHT,
        logo=str(tools_env.HDL_MODULES_DOC / "logos" / "third_party" / "github.svg"),
        embed_logo=True,
    )
    create_file(output_path / "repository.svg", badge_svg)

    badge_svg = badge(
        left_text="website",
        right_text="hdl-modules.com",
        left_color=BADGE_COLOR_LEFT,
        right_color=BADGE_COLOR_RIGHT,
        logo=str(tools_env.HDL_MODULES_DOC / "logos" / "third_party" / "firefox.svg"),
        embed_logo=True,
    )
    create_file(output_path / "website.svg", badge_svg)

    badge_svg = badge(
        left_text="chat",
        right_text="GitHub Discussions",
        left_color=BADGE_COLOR_LEFT,
        right_color=BADGE_COLOR_RIGHT,
        logo=str(tools_env.HDL_MODULES_DOC / "logos" / "third_party" / "discussions.svg"),
        embed_logo=True,
    )
    create_file(output_path / "chat.svg", badge_svg)


if __name__ == "__main__":
    main()
