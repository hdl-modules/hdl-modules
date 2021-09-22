# --------------------------------------------------------------------------------------------------
# Copyright (c) Lukas Vik. All rights reserved.
#
# This file is part of the tsfpga project.
# https://tsfpga.com
# https://gitlab.com/tsfpga/tsfpga
# --------------------------------------------------------------------------------------------------

import sys

import hdl_modules_tools_env

# Do PYTHONPATH insert() instead of append() to prefer any local repo checkout over any pip install
PATH_TO_TSFPGA = hdl_modules_tools_env.REPO_ROOT.parent / "tsfpga"
sys.path.insert(0, str(PATH_TO_TSFPGA))
PATH_TO_VUNIT = hdl_modules_tools_env.REPO_ROOT.parent / "vunit"
sys.path.insert(0, str(PATH_TO_VUNIT))

from tsfpga.build_project_list import BuildProjectList
from tsfpga.module import get_modules

import examples.build


def main():
    args = examples.build.arguments(default_temp_dir=hdl_modules_tools_env.HDL_MODULES_TEMP_DIR)
    modules = get_modules([hdl_modules_tools_env.HDL_MODULES_MODULES_DIRECTORY])
    projects = BuildProjectList(
        modules=modules,
        project_filters=args.project_filters,
        include_netlist_not_top_builds=args.netlist_builds,
        no_color=args.no_color,
    )

    sys.exit(examples.build.setup_and_run(modules, projects, args))


if __name__ == "__main__":
    main()
