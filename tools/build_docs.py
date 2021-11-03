# --------------------------------------------------------------------------------------------------
# Copyright (c) Lukas Vik. All rights reserved.
#
# This file is part of the hdl_modules project.
# https://hdl-modules.com
# https://gitlab.com/tsfpga/hdl_modules
# --------------------------------------------------------------------------------------------------

from pybadges import badge

import hdl_modules_tools_env

from tsfpga.module import get_modules
from tsfpga.module_documentation import ModuleDocumentation
from tsfpga.system_utils import create_directory, create_file, read_file
from tsfpga.tools.sphinx_doc import build_sphinx, generate_release_notes

GENERATED_SPHINX = hdl_modules_tools_env.HDL_MODULES_GENERATED / "sphinx"
GENERATED_SPHINX_HTML = hdl_modules_tools_env.HDL_MODULES_GENERATED / "sphinx_html"
SPHINX_DOC = hdl_modules_tools_env.HDL_MODULES_DOC / "sphinx"


def main():
    rst = generate_release_notes(
        repo_root=hdl_modules_tools_env.REPO_ROOT,
        release_notes_directory=hdl_modules_tools_env.HDL_MODULES_DOC / "release_notes",
        project_name="hdl_modules",
    )
    create_file(GENERATED_SPHINX / "release_notes.rst", rst)

    generate_module_documentation()

    generate_sphinx_index()

    build_sphinx(build_path=SPHINX_DOC, output_path=GENERATED_SPHINX_HTML)

    build_information_badges()


def generate_module_documentation():
    modules = get_modules(modules_folders=[hdl_modules_tools_env.HDL_MODULES_DIRECTORY])
    for module in modules:
        module_documentation = ModuleDocumentation(module)
        rst = module_documentation.get_rst_document()

        create_file(GENERATED_SPHINX / "modules" / f"{module.name}.rst", rst)


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

The hdl_modules project is a collection of reusable, high-quality, peer-reviewed VHDL
building blocks.

{extra_rst}
TBC...
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


def generate_sphinx_index():
    """
    Generate index.rst for sphinx. Also verify that readme.rst in the project is identical.

    Rst file inclusion in readme.rst does not work on gitlab unfortunately, hence this
    cumbersome handling of syncing documentation.
    """
    rst = get_readme_rst()
    create_file(GENERATED_SPHINX / "index.rst", rst)


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
