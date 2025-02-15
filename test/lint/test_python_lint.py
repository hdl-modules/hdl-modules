# --------------------------------------------------------------------------------------------------
# Copyright (c) Lukas Vik. All rights reserved.
#
# This file is part of the hdl-modules project, a collection of reusable, high-quality,
# peer-reviewed VHDL building blocks.
# https://hdl-modules.com
# https://github.com/hdl-modules/hdl-modules
# --------------------------------------------------------------------------------------------------

import sys

from tsfpga.system_utils import run_command

from tools.tools_env import REPO_ROOT


def _run_ruff(command: list[str]):
    run_command([sys.executable, "-m", "ruff", *command], cwd=REPO_ROOT)


def test_ruff_check():
    _run_ruff(command=["check"])


def test_ruff_format():
    _run_ruff(command=["format", "--check", "--diff"])
