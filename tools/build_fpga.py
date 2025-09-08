# --------------------------------------------------------------------------------------------------
# Copyright (c) Lukas Vik. All rights reserved.
#
# This file is part of the hdl-modules project, a collection of reusable, high-quality,
# peer-reviewed VHDL building blocks.
# https://hdl-modules.com
# https://github.com/hdl-modules/hdl-modules
# --------------------------------------------------------------------------------------------------

import sys
from pathlib import Path

# Do PYTHONPATH insert() instead of append() to prefer any local repo checkout over any pip install.
REPO_ROOT = Path(__file__).parent.parent.resolve()
sys.path.insert(0, str(REPO_ROOT))

# Import before others since it modifies PYTHONPATH.
import tools.tools_pythonpath  # noqa: F401

from tsfpga.build_project_list import BuildProjectList, get_build_projects
from tsfpga.examples.build_fpga_utils import arguments, setup_and_run
from tsfpga.module import get_modules

from tools import tools_env


def main() -> None:
    args = arguments(default_temp_dir=tools_env.HDL_MODULES_GENERATED)

    modules = get_modules(modules_folder=tools_env.HDL_MODULES_DIRECTORY)
    project_list = BuildProjectList(
        projects=get_build_projects(
            modules=modules,
            project_filters=args.project_filters,
            include_netlist_not_full_builds=args.netlist_builds,
        )
    )

    sys.exit(
        setup_and_run(
            modules=modules, project_list=project_list, args=args, collect_artifacts_function=None
        )
    )


if __name__ == "__main__":
    main()
