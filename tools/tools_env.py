# --------------------------------------------------------------------------------------------------
# Copyright (c) Lukas Vik. All rights reserved.
#
# This file is part of the hdl-modules project, a collection of reusable, high-quality,
# peer-reviewed VHDL building blocks.
# https://hdl-modules.com
# https://github.com/hdl-modules/hdl-modules
# --------------------------------------------------------------------------------------------------

from pathlib import Path

REPO_ROOT = Path(__file__).parent.parent.resolve()
HDL_MODULES_DIRECTORY = REPO_ROOT / "modules"

HDL_MODULES_DOC = REPO_ROOT / "doc"
HDL_MODULES_GENERATED = REPO_ROOT / "generated"
