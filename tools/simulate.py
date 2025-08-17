# --------------------------------------------------------------------------------------------------
# Copyright (c) Lukas Vik. All rights reserved.
#
# This file is part of the hdl-modules project, a collection of reusable, high-quality,
# peer-reviewed VHDL building blocks.
# https://hdl-modules.com
# https://github.com/hdl-modules/hdl-modules
# --------------------------------------------------------------------------------------------------

import os
import sys
from pathlib import Path

# Do PYTHONPATH insert() instead of append() to prefer any local repo checkout over any pip install.
REPO_ROOT = Path(__file__).parent.parent.resolve()
sys.path.insert(0, str(REPO_ROOT))

# Import before others since it modifies PYTHONPATH.
import tools.tools_pythonpath  # noqa: F401

from tsfpga.examples.simulation_utils import (
    SimulationProject,
    get_arguments_cli,
    set_git_test_pattern,
)
from tsfpga.module import get_modules

from tools import tools_env


def main() -> None:
    cli = get_arguments_cli(default_output_path=tools_env.HDL_MODULES_GENERATED)
    args = cli.parse_args()  # type: ignore[no-untyped-call]

    modules = get_modules(modules_folder=tools_env.HDL_MODULES_DIRECTORY)

    simulation_project = SimulationProject(args=args, enable_preprocessing=True)
    simulation_project.add_modules(modules=modules)
    simulation_project.add_vivado_simlib()

    if args.vcs_minimal and not set_git_test_pattern(
        args=args,
        repo_root=REPO_ROOT,
        vunit_proj=simulation_project.vunit_proj,
        modules=modules,
    ):
        # No git diff. Don't run anything.
        return

    # Some of our test names get really long (tb_asynchronous_fifo specifically),
    # resulting in too long paths: "OSError: [Errno 36] File name too long".
    # Hence let VUnit shorten the paths in vunit_out folder.
    os.environ["VUNIT_SHORT_TEST_OUTPUT_PATHS"] = "true"

    simulation_project.vunit_proj.main()


if __name__ == "__main__":
    main()
