# --------------------------------------------------------------------------------------------------
# Copyright (c) Lukas Vik. All rights reserved.
#
# This file is part of the hdl_modules project, a collection of reusable, high-quality,
# peer-reviewed VHDL building blocks.
# https://hdl-modules.com
# https://gitlab.com/hdl_modules/hdl_modules
# --------------------------------------------------------------------------------------------------

# Third party libraries
# pylint: disable=wrong-import-order
from tsfpga.git_utils import find_git_files
from tsfpga.test.lint.test_python_lint import run_black, run_flake8_lint, run_pylint

# First party libraries
from tools.tools_env import HDL_MODULES_DOC, REPO_ROOT


def _files_to_test():
    # Exclude doc folder, since conf.py used by sphinx does not conform
    return [
        str(path)
        for path in find_git_files(
            directory=REPO_ROOT,
            exclude_directories=[HDL_MODULES_DOC],
            file_endings_include="py",
        )
    ]


def test_pylint():
    run_pylint(_files_to_test())


def test_flake8_lint():
    run_flake8_lint(_files_to_test())


def test_black_formatting():
    run_black(_files_to_test())
