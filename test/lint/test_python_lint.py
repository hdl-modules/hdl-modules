# --------------------------------------------------------------------------------------------------
# Copyright (c) Lukas Vik. All rights reserved.
#
# This file is part of the hdl_modules project.
# https://hdl-modules.com
# https://gitlab.com/tsfpga/hdl_modules
# --------------------------------------------------------------------------------------------------

from tools.hdl_modules_tools_env import REPO_ROOT

# pylint: disable=wrong-import-order
from tsfpga.git_utils import find_git_files
from tsfpga.test.lint.test_python_lint import run_black, run_flake8_lint, run_pylint


def _files_to_test():
    return list(find_git_files(file_endings_include="py", directory=REPO_ROOT))


def test_pylint():
    run_pylint(_files_to_test())


def test_flake8_lint():
    run_flake8_lint(_files_to_test())


def test_black_formatting():
    run_black(_files_to_test())
