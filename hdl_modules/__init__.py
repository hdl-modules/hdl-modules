# --------------------------------------------------------------------------------------------------
# Copyright (c) Lukas Vik. All rights reserved.
#
# This file is part of the hdl-modules project, a collection of reusable, high-quality,
# peer-reviewed VHDL building blocks.
# https://hdl-modules.com
# https://github.com/hdl-modules/hdl-modules
# --------------------------------------------------------------------------------------------------

from __future__ import annotations

from pathlib import Path
from typing import TYPE_CHECKING

from .about import get_short_slogan

if TYPE_CHECKING:
    from tsfpga.module_list import ModuleList

REPO_ROOT = Path(__file__).parent.parent.resolve()

__version__ = "6.2.2-dev"

# We have the slogan in one place only, instead of repeating it here in a proper docstring.
__doc__ = get_short_slogan()


def get_hdl_modules(
    names_include: set[str] | None = None, names_avoid: set[str] | None = None
) -> ModuleList:
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
    from tsfpga.module import get_modules  # noqa: PLC0415

    return get_modules(
        modules_folder=REPO_ROOT / "modules",
        names_include=names_include,
        names_avoid=names_avoid,
        library_name_has_lib_suffix=False,
    )
