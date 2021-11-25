# --------------------------------------------------------------------------------------------------
# Copyright (c) Lukas Vik. All rights reserved.
#
# This file is part of the hdl_modules project.
# https://hdl-modules.com
# https://gitlab.com/tsfpga/hdl_modules
# --------------------------------------------------------------------------------------------------

import argparse
from pathlib import Path
from shutil import move
import sys

from packaging.version import parse
from git import Repo

import hdl_modules_tools_env

from tsfpga.system_utils import create_file, read_file
from tsfpga.tools.version_number_handler import (
    commit_and_tag_release,
    make_commit,
    UNRELEASED_EMPTY,
    VersionNumberHandler,
)

PATH_TO_REPO_ROOT = Path(__file__).parent.parent.resolve()
sys.path.insert(0, str(PATH_TO_REPO_ROOT))

from hdl_modules import __version__ as current_version


RELEASE_NOTES = hdl_modules_tools_env.HDL_MODULES_DOC / "release_notes"


def main():
    parser = argparse.ArgumentParser(description="Make release commits and tag")
    parser.add_argument(
        "release_version", nargs=1, type=str, help="release version number MAJOR.MINOR.PATCH"
    )
    release_version = parser.parse_args().release_version[0]

    repo = Repo(hdl_modules_tools_env.REPO_ROOT)
    git_tag = verify_new_version_number(repo=repo, new_version=release_version)

    version_number_handler = VersionNumberHandler(
        repo=repo, version_file_path=PATH_TO_REPO_ROOT / "hdl_modules" / "__init__.py"
    )
    version_number_handler.update(new_version=release_version)

    move_release_notes(repo=repo, version=release_version)

    commit_and_tag_release(repo=repo, version=release_version, git_tag=git_tag)

    version_number_handler.bump_to_prelease()
    make_commit(repo=repo, commit_message="Set pre-release version number")


def verify_new_version_number(repo, new_version):
    if repo.is_dirty():
        sys.exit("Must make release from clean repo")

    unreleased_notes_file = RELEASE_NOTES / "unreleased.rst"
    if read_file(unreleased_notes_file) in ["", UNRELEASED_EMPTY]:
        sys.exit(f"The unreleased notes file {unreleased_notes_file} should not be empty")

    if parse(new_version) <= parse(current_version):
        sys.exit(f"New version {new_version} is not greater than current version {current_version}")

    new_git_tag = "v" + new_version
    for existing_tag in repo.tags:
        existing_tag_str = str(existing_tag)

        if new_git_tag == existing_tag_str:
            sys.exit(f"Git release tag already exists: {new_git_tag}")

        # Split e.g. "v1.0.0" -> "1.0.0"
        existing_version = existing_tag_str.split("v")[1]
        if parse(new_version) <= parse(existing_version):
            sys.exit(f"New version {new_version} is not greater than existing tag {existing_tag}")

    return new_git_tag


def move_release_notes(repo, version):
    unreleased_rst = RELEASE_NOTES / "unreleased.rst"
    version_rst = RELEASE_NOTES / f"{version}.rst"

    if version_rst.exists():
        raise RuntimeError(f"Release notes already exist: {version_rst}")

    move(unreleased_rst, version_rst)

    # Create a new, empty, unreleased notes file
    create_file(unreleased_rst, UNRELEASED_EMPTY)

    # Add files so that the changes get included in the commit
    repo.index.add(str(unreleased_rst.resolve()))
    repo.index.add(str(version_rst.resolve()))


if __name__ == "__main__":
    main()
