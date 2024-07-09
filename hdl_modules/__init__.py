# --------------------------------------------------------------------------------------------------
# Copyright (c) Lukas Vik. All rights reserved.
#
# This file is part of the hdl-modules project, a collection of reusable, high-quality,
# peer-reviewed VHDL building blocks.
# https://hdl-modules.com
# https://github.com/hdl-modules/hdl-modules
# --------------------------------------------------------------------------------------------------

# Standard libraries
from pathlib import Path
from typing import TYPE_CHECKING, Optional

# Local folder libraries
from .about import get_short_slogan

if TYPE_CHECKING:
    # Third party libraries
    from tsfpga.module_list import ModuleList

REPO_ROOT = Path(__file__).parent.parent.resolve()

__version__ = "5.0.2-dev"
__doc__ = get_short_slogan()  # pylint: disable=redefined-builtin


def get_hdl_modules(
    names_include: Optional[set[str]] = None, names_avoid: Optional[set[str]] = None
) -> "ModuleList":
    """
    Wrapper of :func:`tsfpga.module.get_modules` which returns the ``hdl-modules`` module objects.

    Arguments will be passed on to :func:`.get_modules`.

    Return:
        The module objects.
    """
    # tsfpga might not be available on some systems where the hdl-modules are used.
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
