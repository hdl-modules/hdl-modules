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

project = "hdl-modules"
copyright = "Lukas Vik"
author = "Lukas Vik"

extensions = [
    "sphinx.ext.graphviz",
    "sphinx.ext.intersphinx",
    "sphinx_rtd_theme",
    "sphinx_sitemap",
    "symbolator_sphinx",
]

intersphinx_mapping = {
    "hdl_registers": ("https://hdl-registers.com", None),
    "tsfpga": ("https://tsfpga.com", None),
    "vunit": ("https://vunit.github.io/", None),
}

symbolator_output_format = "png"

# Base URL for generated sitemap.xml.
html_baseurl = "https://hdl-modules.com"

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
html_static_path = ["css"]

# These paths are either relative to html_static_path
# or fully qualified paths (eg. https://...)
html_css_files = [
    # A hack to get the table captions below the table.
    # Per instructions at
    # https://stackoverflow.com/questions/69845499/
    "docutils_table_caption_below.css",
]
