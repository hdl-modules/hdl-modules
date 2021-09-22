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

import examples.simulate


def main():
    args = arguments()

    modules = get_modules([hdl_modules_tools_env.HDL_MODULES_MODULES_DIRECTORY])

    if args.git_minimal:
        if args.test_patterns != "*":
            sys.exit(
                "Can not specify a test pattern when using the --git-minimal flag."
                f" Got {args.test_patterns}",
            )

        git_test_filters = examples.simulate.find_git_test_filters(
            args=args, modules=modules, repo_root=hdl_modules_tools_env.REPO_ROOT
        )
        if not git_test_filters:
            print("Nothing to run. Appears to be no VHDL-related git diff.")
            return

        # Override the test pattern argument to VUnit
        args.test_patterns = git_test_filters
        print(f"Running VUnit with test pattern {args.test_patterns}")

        # Enable minimal compilation in VUnit
        args.minimal = True

    vunit_proj, _ = examples.simulate.setup_vunit_project(args=args, modules=modules)
    vunit_proj.main()


def arguments():
    cli = VUnitCLI()
    cli.parser.add_argument(
        "--temp-dir",
        type=Path,
        default=hdl_modules_tools_env.HDL_MODULES_TEMP_DIR,
        help="where to place files needed for simulation flow",
    )
    cli.parser.add_argument(
        "--git-minimal",
        action="store_true",
        help="compile and run only a minimal set of tests based on git history",
    )

    args = cli.parse_args()
    args.output_path = args.temp_dir / "vunit_out"

    # Modules in this repo have no dependency on Vivado simlib or IP cores
    args.vivado_skip = True

    return args


if __name__ == "__main__":
    main()
