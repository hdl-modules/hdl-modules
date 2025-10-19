# --------------------------------------------------------------------------------------------------
# Copyright (c) Lukas Vik. All rights reserved.
#
# This file is part of the hdl-modules project, a collection of reusable, high-quality,
# peer-reviewed VHDL building blocks.
# https://hdl-modules.com
# https://github.com/hdl-modules/hdl-modules
# --------------------------------------------------------------------------------------------------

from __future__ import annotations

import argparse
import sys
from itertools import product
from pathlib import Path

# Do PYTHONPATH insert() instead of append() to prefer any local repo checkout over any pip install.
REPO_ROOT = Path(__file__).parent.parent.resolve()
sys.path.insert(0, str(REPO_ROOT))

# Import before others since it modifies PYTHONPATH.
import tools.tools_pythonpath  # noqa: F401

from tsfpga.build_project_list import BuildProjectList
from tsfpga.examples.build_fpga_utils import setup_and_run
from tsfpga.examples.vivado.project import TsfpgaExampleVivadoNetlistProject
from tsfpga.module import BaseModule, get_modules

from tools import tools_env


def main() -> None:
    args = arguments(default_temp_dir=tools_env.HDL_MODULES_GENERATED)

    generic_setups = parse_generics(command_line_argument=args.generic)
    modules = get_modules(modules_folder=tools_env.HDL_MODULES_DIRECTORY)

    projects = [
        TsfpgaExampleVivadoNetlistProject(
            name=BaseModule.test_case_name(name=args.top_level, generics=generics),
            modules=modules,
            part="xcku5p-sfvb784-3-e",
            top=args.top_level,
            generics=generics,
            analyze_synthesis_timing=args.analyze_timing,
        )
        for generics in generic_setups
    ]
    project_list = BuildProjectList(projects=projects)

    # Fill in fixed arguments for this specific build flow so the general 'setup_and_run'
    # function can be used.
    args.generate_registers_only = False
    args.collect_artifacts_only = False
    args.synth_only = True
    args.num_threads_per_build = 2
    args.output_path = None
    args.from_impl = False
    sys.exit(
        setup_and_run(
            modules=modules, project_list=project_list, args=args, collect_artifacts_function=None
        )
    )


def arguments(default_temp_dir: Path) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        "Synthesize a specific entity/module to get quick design feedback",
        formatter_class=argparse.ArgumentDefaultsHelpFormatter,
    )

    group = parser.add_mutually_exclusive_group()

    group.add_argument("--list-only", action="store_true", help="list the available projects")

    group.add_argument("--create-only", action="store_true", help="only create projects")

    group.add_argument("--open", action="store_true", help="open existing projects in the GUI")

    parser.add_argument(
        "--use-existing-project",
        action="store_true",
        help="synthesize existing projects, or create first if they do not exist",
    )

    parser.add_argument(
        "--projects-path",
        type=Path,
        default=default_temp_dir / "projects",
        help="the FPGA build projects will be placed here",
    )

    parser.add_argument(
        "--ip-cache-path",
        type=Path,
        default=default_temp_dir / "vivado_ip_cache",
        help="location of Vivado IP cache",
    )

    parser.add_argument(
        "--num-parallel-builds", type=int, default=8, help="number of parallel builds to launch"
    )

    parser.add_argument(
        "--analyze-timing",
        action="store_true",
        help="analyzes the timing of the design after synthesis (makes the build slower)",
    )

    parser.add_argument(
        "--generic",
        "--parameter",
        action="append",
        help=("generics/parameters to synthesize with, on the format 'name=value1,value2,etc'"),
    )

    parser.add_argument(
        "top_level", type=str, help="name of the top level entity/module to synthesize"
    )

    return parser.parse_args()


def parse_generics(
    command_line_argument: list[str] | None,
) -> list[dict[str, bool | int]]:
    """
    Parse the ``--generic name=value1,value2`` command line arguments.
    Each generic can have multiple values, and multiple generics can be specified.
    The result is all combinations of generics and values.
    """
    # List of all values for each generic. For example:
    # {"a": [True, False], "b": [16, 32]}
    result_raw: dict[str, list[bool | int]] = {}

    for argument in command_line_argument or []:
        if argument.count("=") != 1:
            raise ValueError(
                f'Expected generic argument to be in the form "name=value".Got "{argument}".'
            )

        name, values = argument.split("=")
        if name == "" or values == "":
            raise ValueError(
                f'Expected generic argument to be in the form "name=value". Got "{argument}".'
            )

        result_raw[name] = []

        for value in values.split(","):
            value_lower = value.lower()

            if value_lower in ["true", "false"]:
                value_casted = value_lower == "true"
            elif value.isdigit():
                value_casted = int(value)
            else:
                raise ValueError(f'Cannot parse "{name}" generic value: "{value}"')

            result_raw[name].append(value_casted)

    # All combinations of generics and values. For example:
    # [{"a": True, "b": 16}, {"a": True, "b": 32}, {"a": False, "b": 16}, {"a": False, "b": 32}]
    return [
        dict(zip(result_raw.keys(), combination, strict=False))
        for combination in product(*result_raw.values())
    ]


if __name__ == "__main__":
    main()
