# --------------------------------------------------------------------------------------------------
# Copyright (c) Lukas Vik. All rights reserved.
#
# This file is part of the hdl-modules project, a collection of reusable, high-quality,
# peer-reviewed VHDL building blocks.
# https://hdl-modules.com
# https://github.com/hdl-modules/hdl-modules
# --------------------------------------------------------------------------------------------------

# Third party libraries
# pylint: disable=wrong-import-order
from tsfpga.git_utils import find_git_files
from tsfpga.test.lint.copyright_lint import CopyrightHeader

# First party libraries
from tools.tools_env import REPO_ROOT

COPYRIGHT_HOLDER = "Lukas Vik"
COPYRIGHT_TEXT = [
    "This file is part of the hdl-modules project, a collection of reusable, high-quality,",
    "peer-reviewed VHDL building blocks.",
    "https://hdl-modules.com",
    "https://github.com/hdl-modules/hdl-modules",
]


def files_to_check_for_copyright_header():
    files = []

    file_endings = (".py", ".vhd", ".tcl", ".cpp", ".h")
    for file_ending in file_endings:
        files += find_git_files(
            directory=REPO_ROOT,
            file_endings_include=file_ending,
        )

    return files


def test_copyright_header_of_all_checked_in_files():
    test_ok = True
    for file in files_to_check_for_copyright_header():
        copyright_header_checker = CopyrightHeader(file, COPYRIGHT_HOLDER, COPYRIGHT_TEXT)

        if not copyright_header_checker.check_file():
            test_ok = False
            expected = copyright_header_checker.expected_copyright_header
            print(f"Fail for {file}\nExpected:\n{expected}")
    assert test_ok
