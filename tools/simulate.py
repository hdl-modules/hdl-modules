# --------------------------------------------------------------------------------------------------
# Copyright (c) Lukas Vik. All rights reserved.
#
# This file is part of the hdl-modules project, a collection of reusable, high-quality,
# peer-reviewed VHDL building blocks.
# https://hdl-modules.com
# https://github.com/hdl-modules/hdl-modules
# --------------------------------------------------------------------------------------------------

# Standard libraries
import os
import sys
from pathlib import Path

# Do PYTHONPATH insert() instead of append() to prefer any local repo checkout over any pip install
REPO_ROOT = Path(__file__).parent.parent.resolve()
sys.path.insert(0, str(REPO_ROOT))

# Import before others since it modifies PYTHONPATH. pylint: disable=unused-import
import tools.tools_pythonpath  # noqa: F401

# Third party libraries
from tsfpga.examples.simulate import find_git_test_filters
from tsfpga.examples.simulation_utils import SimulationProject, get_arguments_cli
from tsfpga.module import get_modules

# First party libraries
from tools import tools_env


def main() -> None:
    cli = get_arguments_cli(default_output_path=tools_env.HDL_MODULES_GENERATED)
    args = cli.parse_args()  # type: ignore[no-untyped-call]

    modules = get_modules(modules_folder=tools_env.HDL_MODULES_DIRECTORY)

    if args.vcs_minimal:
        if args.test_patterns != "*":
            sys.exit(
                "Can not specify a test pattern when using the --vcs-minimal flag."
                f" Got {args.test_patterns}",
            )

        test_filters = find_git_test_filters(
            args=args,
            repo_root=tools_env.REPO_ROOT,
            modules=modules,
            reference_branch="origin/main",
        )
        if not test_filters:
            print("Nothing to run. Appears to be no VHDL-related git diff.")
            return

        # Override the test pattern argument to VUnit
        args.test_patterns = test_filters
        print(f"Running VUnit with test pattern {args.test_patterns}")

        # Enable minimal compilation in VUnit
        args.minimal = True

    # Some of our test names get really long (tb_asynchronous_fifo specifically),
    # resulting in too long paths: "OSError: [Errno 36] File name too long".
    # Hence let VUnit shorten the paths in vunit_out folder.
    os.environ["VUNIT_SHORT_TEST_OUTPUT_PATHS"] = "true"

    simulation_project = SimulationProject(args=args, enable_preprocessing=True)
    simulation_project.add_modules(modules=modules)
    simulation_project.add_vivado_simlib()

    simulation_project.vunit_proj.main()


if __name__ == "__main__":
    main()
