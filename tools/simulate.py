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

from vunit import VUnitCLI, VUnit

from tsfpga.git_simulation_subset import GitSimulationSubset
from tsfpga.module import get_modules


def main():
    args = arguments()

    if args.git_minimal:
        if args.test_patterns != "*":
            sys.exit(
                "Can not specify a test pattern when using the --git-minimal flag."
                f" Got {args.test_patterns}",
            )

        git_test_filters = find_git_test_filters(args)
        if not git_test_filters:
            print("Nothing to run. Appears to be no VHDL-related git diff.")
            return

        # Override the test pattern argument to VUnit
        args.test_patterns = git_test_filters
        print(f"Running VUnit with test pattern {args.test_patterns}")

        # Enable minimal compilation in VUnit
        args.minimal = True

    vunit_proj, _ = setup_vunit_project(args)
    vunit_proj.main()


def find_git_test_filters(args):
    # Set up a dummy VUnit project that will be used for depency scanning. Note that sources are
    # added identically to the "real" VUnit project.
    vunit_proj, modules = setup_vunit_project(args)

    testbenches_to_run = GitSimulationSubset(
        repo_root=hdl_modules_tools_env.REPO_ROOT,
        reference_branch="origin/master",
        vunit_proj=vunit_proj,
        # We use VUnit preprocessing, so these arguments have to be supplied
        vunit_preprocessed_path=args.output_path / "preprocessed",
        modules=modules,
    ).find_subset()

    test_filters = []
    for testbench_file_name, library_name in testbenches_to_run:
        test_filters.append(f"{library_name}.{testbench_file_name}.*")

    return test_filters


def setup_vunit_project(args):
    vunit_proj = VUnit.from_args(args=args)
    vunit_proj.add_verification_components()
    vunit_proj.add_random()
    vunit_proj.enable_location_preprocessing()
    vunit_proj.enable_check_preprocessing()

    modules = get_modules([hdl_modules_tools_env.HDL_MODULES_MODULES_DIRECTORY])

    for module in modules:
        vunit_library = vunit_proj.add_library(module.library_name)
        for hdl_file in module.get_simulation_files():
            if hdl_file.is_vhdl or hdl_file.is_verilog_source:
                vunit_library.add_source_file(hdl_file.path)
            else:
                assert False, f"Can not handle this file: {hdl_file}"

        module.setup_vunit(vunit_proj)

    return vunit_proj, modules


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
    return args


if __name__ == "__main__":
    main()
