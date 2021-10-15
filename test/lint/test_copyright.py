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
from tsfpga.system_utils import file_is_in_directory
from tsfpga.test.lint.test_copyright import CopyrightHeader

COPYRIGHT_HOLDER = "Lukas Vik"
COPYRIGHT_TEXT = [
    "This file is part of the hdl_modules project.",
    "https://hdl-modules.com",
    "https://gitlab.com/tsfpga/hdl_modules",
]
COPYRIGHT_TEXT_TSFPGA = [
    "This file is part of the tsfpga project.",
    "https://tsfpga.com",
    "https://gitlab.com/tsfpga/tsfpga",
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
        if file_is_in_directory(file, [REPO_ROOT / "modules"]):
            copyright_text = COPYRIGHT_TEXT_TSFPGA
        else:
            copyright_text = COPYRIGHT_TEXT

        copyright_header_checker = CopyrightHeader(file, COPYRIGHT_HOLDER, copyright_text)

        if not copyright_header_checker.check_file():
            test_ok = False
            expected = copyright_header_checker.expected_copyright_header
            print(f"Fail for {file}\nExpected:\n{expected}")
    assert test_ok
