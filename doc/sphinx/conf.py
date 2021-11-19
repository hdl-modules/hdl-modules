# --------------------------------------------------------------------------------------------------
# Copyright (c) Lukas Vik. All rights reserved.
#
# This file is part of the hdl_modules project.
# https://hdl-modules.com
# https://gitlab.com/tsfpga/hdl_modules
# --------------------------------------------------------------------------------------------------

"""
Configuration file for the Sphinx documentation builder.
"""

project = "hdl_modules"
copyright = "Lukas Vik"
author = "Lukas Vik"

extensions = [
    "sphinx.ext.graphviz",
    "sphinx.ext.intersphinx",
    "sphinx.ext.napoleon",
    "sphinx_rtd_theme",
    "sphinx_sitemap",
    "symbolator_sphinx",
]

intersphinx_mapping = {
    "tsfpga": ("https://tsfpga.com", None),
    "hdl_registers": ("https://hdl-registers.com", None),
}

symbolator_output_format = "png"

# Base URL for generated sitemap XML
html_baseurl = "https://hdl-modules.com"

# Include robots.txt which points to sitemap
html_extra_path = ["robots.txt"]

html_theme = "sphinx_rtd_theme"

html_theme_options = {
    "prev_next_buttons_location": "both",
}
