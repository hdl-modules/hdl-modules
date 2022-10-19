# --------------------------------------------------------------------------------------------------
# Copyright (c) Lukas Vik. All rights reserved.
#
# This file is part of the hdl_modules project, a collection of reusable, high-quality,
# peer-reviewed VHDL building blocks.
# https://hdl-modules.com
# https://gitlab.com/hdl_modules/hdl_modules
# --------------------------------------------------------------------------------------------------

import sys

import hdl_modules_tools_env

from tsfpga.examples.simulate import find_git_test_filters, get_arguments_cli, SimulationProject
from tsfpga.module import get_modules


def main():
    cli = get_arguments_cli(default_output_path=hdl_modules_tools_env.HDL_MODULES_GENERATED)
    args = cli.parse_args()

    # Avoid the module that depends on Xilinx unisim library
    module_names_avoid = ["hard_fifo"] if args.vivado_skip else []
    modules = get_modules(
        modules_folders=[hdl_modules_tools_env.HDL_MODULES_DIRECTORY],
        names_avoid=module_names_avoid,
    )

    if args.vcs_minimal:
        if args.test_patterns != "*":
            sys.exit(
                "Can not specify a test pattern when using the --vcs-minimal flag."
                f" Got {args.test_patterns}",
            )

        test_filters = find_git_test_filters(
            args=args,
            repo_root=hdl_modules_tools_env.REPO_ROOT,
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

    simulation_project = SimulationProject(args=args, enable_preprocessing=True)
    simulation_project.add_modules(args=args, modules=modules)
    simulation_project.add_vivado_simlib(args=args)

    simulation_project.vunit_proj.main()


if __name__ == "__main__":
    main()
