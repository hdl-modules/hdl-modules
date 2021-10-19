# --------------------------------------------------------------------------------------------------
# Copyright (c) Lukas Vik. All rights reserved.
#
# This file is part of the hdl_modules project.
# https://hdl-modules.com
# https://gitlab.com/tsfpga/hdl_modules
# --------------------------------------------------------------------------------------------------

# Configuration file for the Sphinx documentation builder.
#
# This file only contains a selection of the most common options. For a full
# list see the documentation:
# https://www.sphinx-doc.org/en/master/usage/configuration.html

# -- Project information -----------------------------------------------------

project = "hdl_modules"
copyright = "Lukas Vik"
author = "Lukas Vik"


# -- General configuration ---------------------------------------------------

# Add any Sphinx extension module names here, as strings. They can be
# extensions coming with Sphinx (named "sphinx.ext.*") or your custom
# ones.
extensions = [
    "sphinx.ext.graphviz",
    "sphinx.ext.napoleon",
    "sphinx_rtd_theme",
    "sphinx_sitemap",
]

# List of patterns, relative to source directory, that match files and
# directories to ignore when looking for source files.
# This pattern also affects html_static_path and html_extra_path.
exclude_patterns = ["_build", "Thumbs.db", ".DS_Store"]

# Base URL for generated sitemap XML
html_baseurl = "https://hdl-modules.com"

# Include robots.txt which points to sitemap
html_extra_path = ["robots.txt"]


# -- Options for HTML output -------------------------------------------------

html_theme = "sphinx_rtd_theme"

html_theme_options = {
    "prev_next_buttons_location": "both",
}

html_context = {
    "display_gitlab": True,
    "gitlab_user": "tsfpga",
    "gitlab_repo": "hdl_modules",
    "gitlab_version": "master",
    "conf_py_path": "/doc/sphinx/",
}
