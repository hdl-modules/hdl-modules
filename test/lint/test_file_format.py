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
from tsfpga.test.lint.test_file_format import (
    open_file_with_encoding,
    check_file_ends_with_newline,
    check_file_for_tab_character,
    check_file_for_carriage_return,
    check_file_for_trailing_whitespace,
)


def test_all_checked_in_files_are_properly_encoded():
    """
    To avoid problems with different editors and different file encodings, all checked in files
    should contain only ASCII characters.
    """
    for file in find_git_files(directory=REPO_ROOT):
        open_file_with_encoding(file)


def test_all_checked_in_files_end_with_newline():
    """
    All checked in files should end with a UNIX style line break (\n).
    Otherwise UNIX doesn't consider them actual text files.
    """
    test_ok = True
    for file in find_git_files(directory=REPO_ROOT):
        test_ok &= check_file_ends_with_newline(file)
    assert test_ok


def test_no_checked_in_files_contain_tabs():
    """
    To avoid problems with files looking different in different editors, no checked in files may
    contain TAB characters.
    """
    test_ok = True
    for file in find_git_files(directory=REPO_ROOT):
        test_ok &= check_file_for_tab_character(file)
    assert test_ok


def test_no_checked_in_files_contain_carriage_return():
    """
    All checked in files should use UNIX style line breaks (\n not \r\n). Some Linux editors and
    tools will display or interpret the \r as something other than a line break.
    """
    test_ok = True
    for file in find_git_files(directory=REPO_ROOT):
        test_ok &= check_file_for_carriage_return(file)
    assert test_ok


def test_no_checked_in_files_contain_trailing_whitespace():
    """
    Trailing whitespace is not allowed. Some motivation here:
    https://softwareengineering.stackexchange.com/questions/121555
    """
    test_ok = True
    for file in find_git_files(directory=REPO_ROOT):
        test_ok &= check_file_for_trailing_whitespace(file)
    assert test_ok
