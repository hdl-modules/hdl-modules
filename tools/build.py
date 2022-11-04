# --------------------------------------------------------------------------------------------------
# Copyright (c) Lukas Vik. All rights reserved.
#
# This file is part of the hdl_modules project, a collection of reusable, high-quality,
# peer-reviewed VHDL building blocks.
# https://hdl-modules.com
# https://gitlab.com/hdl_modules/hdl_modules
# --------------------------------------------------------------------------------------------------

# Standard libraries
import sys

# Third party libraries
from tsfpga.build_project_list import BuildProjectList
from tsfpga.examples.build import arguments, setup_and_run
from tsfpga.module import get_modules

# First party libraries
import tools.tools_env as tools_env
import tools.tools_pythonpath  # noqa: F401


def main():
    args = arguments(default_temp_dir=tools_env.HDL_MODULES_GENERATED)
    modules = get_modules([tools_env.HDL_MODULES_DIRECTORY])
    projects = BuildProjectList(
        modules=modules,
        project_filters=args.project_filters,
        include_netlist_not_top_builds=args.netlist_builds,
        no_color=args.no_color,
    )

    sys.exit(setup_and_run(modules, projects, args))


if __name__ == "__main__":
    main()
