# --------------------------------------------------------------------------------------------------
# Copyright (c) Lukas Vik. All rights reserved.
#
# This file is part of the hdl-modules project, a collection of reusable, high-quality,
# peer-reviewed VHDL building blocks.
# https://hdl-modules.com
# https://github.com/hdl-modules/hdl-modules
# --------------------------------------------------------------------------------------------------

"""
Import this file to have the default paths of some third party packages added to PYTHONPATH.
"""

# Standard libraries
import sys

# First party libraries
from tools.tools_env import REPO_ROOT

# Do PYTHONPATH insert() instead of append() to prefer any local repo checkout over any pip install.

# Paths e.g.
# repo/hdl-modules/hdl-modules
# repo/tsfpga/tsfpga
PATH_TO_TSFPGA = REPO_ROOT.parent.parent.resolve() / "tsfpga" / "tsfpga"
sys.path.insert(0, str(PATH_TO_TSFPGA))

# Paths e.g.
# repo/hdl-modules/hdl-modules
# repo/hdl-registers/hdl-registers
PATH_TO_HDL_REGISTERS = REPO_ROOT.parent.parent.resolve() / "hdl-registers" / "hdl-registers"
sys.path.insert(0, str(PATH_TO_HDL_REGISTERS))

# Paths e.g.
# repo/hdl-modules/hdl-modules
# repo/vunit/vunit
PATH_TO_VUNIT = REPO_ROOT.parent.parent.resolve() / "vunit" / "vunit"
sys.path.insert(0, str(PATH_TO_VUNIT))
