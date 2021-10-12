# --------------------------------------------------------------------------------------------------
# Copyright (c) Lukas Vik. All rights reserved.
#
# This file is part of the tsfpga project.
# https://tsfpga.com
# https://gitlab.com/tsfpga/tsfpga
# --------------------------------------------------------------------------------------------------

from pathlib import Path
import sys

import hdl_modules_tools_env

# Do PYTHONPATH insert() instead of append() to prefer any local repo checkout over any pip install
PATH_TO_TSFPGA = hdl_modules_tools_env.REPO_ROOT.parent / "tsfpga"
sys.path.insert(0, str(PATH_TO_TSFPGA))
PATH_TO_VUNIT = hdl_modules_tools_env.REPO_ROOT.parent / "vunit"
sys.path.insert(0, str(PATH_TO_VUNIT))

from vunit import VUnitCLI

from tsfpga.module import get_modules

from examples.simulate import find_git_test_filters, get_arguments_cli, setup_vunit_project


def main():
    cli = get_arguments_cli(default_output_path=hdl_modules_tools_env.HDL_MODULES_TEMP_DIR)
    args = cli.parse_args()

    # Modules in this repo have no dependency on Vivado simlib or IP cores
    args.vivado_skip = True

    modules = get_modules([hdl_modules_tools_env.HDL_MODULES_DIRECTORY])

    if args.vcs_minimal:
        if args.test_patterns != "*":
            sys.exit(
                "Can not specify a test pattern when using the --vcs-minimal flag."
                f" Got {args.test_patterns}",
            )

        test_filters = find_git_test_filters(
            args=args, repo_root=hdl_modules_tools_env.REPO_ROOT, modules=modules
        )
        if not test_filters:
            print("Nothing to run. Appears to be no VHDL-related git diff.")
            return

        # Override the test pattern argument to VUnit
        args.test_patterns = test_filters
        print(f"Running VUnit with test pattern {args.test_patterns}")

        # Enable minimal compilation in VUnit
        args.minimal = True

    vunit_proj, _ = setup_vunit_project(args=args, modules=modules)
    vunit_proj.main()


if __name__ == "__main__":
    main()
