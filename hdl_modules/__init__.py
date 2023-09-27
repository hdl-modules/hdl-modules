# --------------------------------------------------------------------------------------------------
# Copyright (c) Lukas Vik. All rights reserved.
#
# This file is part of the hdl_modules project, a collection of reusable, high-quality,
# peer-reviewed VHDL building blocks.
# https://hdl-modules.com
# https://gitlab.com/hdl_modules/hdl_modules
# --------------------------------------------------------------------------------------------------

# Standard libraries
from pathlib import Path

# Local folder libraries
from .about import get_short_slogan

REPO_ROOT = Path(__file__).parent.parent.resolve()

__version__ = "3.0.1"
__doc__ = get_short_slogan()  # pylint: disable=redefined-builtin


def get_hdl_modules(names_include=None, names_avoid=None):
    """
    Wrapper of :func:`tsfpga.module.get_modules` which returns the ``hdl_modules`` module objects.

    Arguments will be passed on to :func:`.get_modules`.

    Return:
        :class:`.ModuleList`: The module objects.
    """
    # tsfpga might not be available on some systems where the hdl_modules are used.
    # Hence we can not import at the top of this file.
    # This function however, which highly depends on tsfpga Module objects, must import it.
    # We assume that it is only called by users who have tsfpga available.
    # pylint: disable=import-outside-toplevel
    # Third party libraries
    from tsfpga.module import get_modules

    return get_modules(
        modules_folders=[REPO_ROOT / "modules"],
        names_include=names_include,
        names_avoid=names_avoid,
        library_name_has_lib_suffix=False,
    )
