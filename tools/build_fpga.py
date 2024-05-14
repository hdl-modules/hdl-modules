# --------------------------------------------------------------------------------------------------
# Copyright (c) Lukas Vik. All rights reserved.
#
# This file is part of the hdl-modules project, a collection of reusable, high-quality,
# peer-reviewed VHDL building blocks.
# https://hdl-modules.com
# https://github.com/hdl-modules/hdl-modules
# --------------------------------------------------------------------------------------------------

# Standard libraries
import sys
from pathlib import Path

# Do PYTHONPATH insert() instead of append() to prefer any local repo checkout over any pip install
REPO_ROOT = Path(__file__).parent.parent.resolve()
sys.path.insert(0, str(REPO_ROOT))

# Import before others since it modifies PYTHONPATH. pylint: disable=unused-import
import tools.tools_pythonpath  # noqa: F401

# Third party libraries
from tsfpga.build_project_list import BuildProjectList
from tsfpga.examples.build_fpga_utils import arguments, setup_and_run
from tsfpga.module import get_modules

# First party libraries
from tools import tools_env


def main() -> None:
    args = arguments(default_temp_dir=tools_env.HDL_MODULES_GENERATED)
    modules = get_modules(modules_folder=tools_env.HDL_MODULES_DIRECTORY)
    projects = BuildProjectList(
        modules=modules,
        project_filters=args.project_filters,
        include_netlist_not_top_builds=args.netlist_builds,
        no_color=args.no_color,
    )

    sys.exit(
        setup_and_run(
            modules=modules, projects=projects, args=args, collect_artifacts_function=None
        )
    )


if __name__ == "__main__":
    main()
