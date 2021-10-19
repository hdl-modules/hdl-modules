# --------------------------------------------------------------------------------------------------
# Copyright (c) Lukas Vik. All rights reserved.
#
# This file is part of the hdl_modules project.
# https://hdl-modules.com
# https://gitlab.com/tsfpga/hdl_modules
# --------------------------------------------------------------------------------------------------

import sys

import hdl_modules_tools_env

from tsfpga.build_project_list import BuildProjectList
from tsfpga.module import get_modules

from tsfpga.examples.build import arguments, setup_and_run


def main():
    args = arguments(default_temp_dir=hdl_modules_tools_env.HDL_MODULES_TEMP_DIRECTORY)
    modules = get_modules([hdl_modules_tools_env.HDL_MODULES_DIRECTORY])
    projects = BuildProjectList(
        modules=modules,
        project_filters=args.project_filters,
        include_netlist_not_top_builds=args.netlist_builds,
        no_color=args.no_color,
    )

    sys.exit(setup_and_run(modules, projects, args))


if __name__ == "__main__":
    main()
