# --------------------------------------------------------------------------------------------------
# Copyright (c) Lukas Vik. All rights reserved.
#
# This file is part of the hdl_modules project.
# https://hdl-modules.com
# https://gitlab.com/tsfpga/hdl_modules
# --------------------------------------------------------------------------------------------------

from pathlib import Path
import sys

REPO_ROOT = Path(__file__).parent.parent.resolve()
HDL_MODULES_TEMP_DIR = REPO_ROOT / "generated"
HDL_MODULES_DIRECTORY = REPO_ROOT / "modules"

# Do PYTHONPATH insert() instead of append() to prefer any local repo checkout over any pip install
PATH_TO_TSFPGA = REPO_ROOT.parent / "tsfpga"
sys.path.insert(0, str(PATH_TO_TSFPGA))
PATH_TO_VUNIT = REPO_ROOT.parent / "vunit"
sys.path.insert(0, str(PATH_TO_VUNIT))
