# --------------------------------------------------------------------------------------------------
# Copyright (c) Lukas Vik. All rights reserved.
#
# This file is part of the hdl-modules project, a collection of reusable, high-quality,
# peer-reviewed VHDL building blocks.
# https://hdl-modules.com
# https://github.com/hdl-modules/hdl-modules
# --------------------------------------------------------------------------------------------------

"""
Configuration file for the Sphinx documentation builder.
"""

# Standard libraries
import sys
from pathlib import Path

# Do PYTHONPATH insert() instead of append() to prefer any local repo checkout over any pip install
REPO_ROOT = Path(__file__).parent.parent.parent.resolve()
sys.path.insert(0, str(REPO_ROOT))

# Import before others since it modifies PYTHONPATH. pylint: disable=unused-import
import tools.tools_pythonpath  # noqa: F401

# First party libraries
from hdl_modules.about import WEBSITE_URL

project = "hdl-modules"
copyright = "Lukas Vik"
author = "Lukas Vik"

extensions = [
    "sphinx_rtd_theme",
    "sphinx_sitemap",
    "sphinx.ext.graphviz",
    "sphinx.ext.intersphinx",
    "sphinxext.opengraph",
    "symbolator_sphinx",
]

intersphinx_mapping = {
    "hdl_registers": ("https://hdl-registers.com", None),
    "tsfpga": ("https://tsfpga.com", None),
    "vunit": ("https://vunit.github.io/", None),
}

symbolator_output_format = "png"

# Base URL for generated sitemap.xml.
# Note that this must end with a trailing slash, otherwise the sitemap.xml will be incorrect.
html_baseurl = f"{WEBSITE_URL}/"

# To avoid "en" in the sitemap.xml URL.
# https://sphinx-sitemap.readthedocs.io/en/latest/advanced-configuration.html
sitemap_url_scheme = "{link}"

# Include robots.txt which points to sitemap
html_extra_path = ["robots.txt"]

html_theme = "sphinx_rtd_theme"

html_theme_options = {
    "prev_next_buttons_location": "both",
    "analytics_id": "G-GN3TVQGSHC",
    "logo_only": True,
}

html_logo = "hdl_modules_sphinx.png"

# These folders are copied to the documentation's HTML output
html_static_path = ["css", "opengraph"]

# These paths are either relative to html_static_path
# or fully qualified paths (eg. https://...)
html_css_files = [
    # A hack to get the table captions below the table.
    # Per instructions at
    # https://stackoverflow.com/questions/69845499/
    "docutils_table_caption_below.css",
]

# OpenGraph settings.
ogp_site_url = WEBSITE_URL
ogp_image = "_static/social_media_preview.png"
