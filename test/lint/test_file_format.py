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
from tsfpga.test.lint.file_format_lint import (
    check_file_ends_with_newline,
    check_file_for_carriage_return,
    check_file_for_line_length,
    check_file_for_tab_character,
    check_file_for_trailing_whitespace,
    open_file_with_encoding,
)

# First party libraries
from tools.tools_env import HDL_MODULES_DIRECTORY, HDL_MODULES_DOC, REPO_ROOT


def files_to_test(excludes=None):
    excludes = [] if excludes is None else excludes
    # Do not test binary image files
    return find_git_files(
        directory=REPO_ROOT,
        exclude_directories=excludes,
        file_endings_avoid=("png", "svg"),
    )


def test_all_checked_in_files_are_properly_encoded():
    """
    To avoid problems with different editors and different file encodings, all checked in files
    should contain only ASCII characters.
    """
    for file in files_to_test():
        open_file_with_encoding(file)


def test_all_checked_in_files_end_with_newline():
    """
    All checked in files should end with a UNIX style line break (\n).
    Otherwise UNIX doesn't consider them actual text files.
    """
    test_ok = True
    for file in files_to_test():
        test_ok &= check_file_ends_with_newline(file)
    assert test_ok


def test_no_checked_in_files_contain_tabs():
    """
    To avoid problems with files looking different in different editors, no checked in files may
    contain TAB characters.
    """
    test_ok = True
    for file in files_to_test():
        test_ok &= check_file_for_tab_character(file)
    assert test_ok


def test_no_checked_in_files_contain_carriage_return():
    """
    All checked in files should use UNIX style line breaks (\n not \r\n). Some Linux editors and
    tools will display or interpret the \r as something other than a line break.
    """
    test_ok = True
    for file in files_to_test():
        test_ok &= check_file_for_carriage_return(file)
    assert test_ok


def test_no_checked_in_files_contain_trailing_whitespace():
    """
    Trailing whitespace is not allowed. Some motivation here:
    https://softwareengineering.stackexchange.com/questions/121555
    """
    test_ok = True
    for file in files_to_test():
        test_ok &= check_file_for_trailing_whitespace(file)
    assert test_ok


def test_no_checked_in_files_have_too_long_lines():
    test_ok = True
    excludes = [
        # RST syntax hard to break.
        REPO_ROOT / "readme.rst",
        # We list the license text exactly as the original, with no line breaks
        REPO_ROOT / "license.txt",
        # Impossible to break RST syntax
        HDL_MODULES_DOC / "sphinx" / "getting_started.rst",
        HDL_MODULES_DIRECTORY / "fifo" / "src" / "asynchronous_fifo.vhd",
        HDL_MODULES_DIRECTORY / "resync" / "doc" / "resync.rst",
        HDL_MODULES_DIRECTORY / "resync" / "src" / "resync_counter.vhd",
        HDL_MODULES_DIRECTORY / "resync" / "src" / "resync_level_on_signal.vhd",
        HDL_MODULES_DIRECTORY / "resync" / "src" / "resync_level.vhd",
        HDL_MODULES_DIRECTORY / "resync" / "src" / "resync_pulse.vhd",
        HDL_MODULES_DIRECTORY / "resync" / "src" / "resync_slv_handshake.vhd",
        HDL_MODULES_DIRECTORY / "resync" / "src" / "resync_slv_level_coherent.vhd",
        # Impossible to break TCL syntax
        HDL_MODULES_DIRECTORY / "resync" / "scoped_constraints" / "resync_slv_level_coherent.tcl",
    ]
    for file_path in files_to_test(excludes=excludes):
        test_ok &= check_file_for_line_length(file_path=file_path)

    assert test_ok
