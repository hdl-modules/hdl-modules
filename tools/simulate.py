# --------------------------------------------------------------------------------------------------
# Copyright (c) Lukas Vik. All rights reserved.
#
# This file is part of the tsfpga project.
# https://tsfpga.com
# https://gitlab.com/tsfpga/tsfpga
# --------------------------------------------------------------------------------------------------

from pathlib import Path
from shutil import which
import sys

# Do PYTHONPATH insert() instead of append() to prefer any local repo checkout over any pip install
PATH_TO_TSFPGA = Path(__file__).parent.parent.resolve()
sys.path.insert(0, str(PATH_TO_TSFPGA))
PATH_TO_VUNIT = PATH_TO_TSFPGA.parent / "vunit"
sys.path.insert(0, str(PATH_TO_VUNIT))

from vunit import VUnitCLI, VUnit
from vunit.vivado.vivado import create_compile_order_file, add_from_compile_order_file

import tsfpga
import tsfpga.create_vhdl_ls_config
from tsfpga.git_simulation_subset import GitSimulationSubset
from tsfpga.vivado.ip_cores import VivadoIpCores
from tsfpga.vivado.simlib import VivadoSimlib

from examples.tsfpga_example_env import get_tsfpga_modules, TSFPGA_EXAMPLES_TEMP_DIR


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

    vunit_proj, modules, ip_core_vivado_project_directory = setup_vunit_project(args)

    create_vhdl_ls_configuration(
        output_path=PATH_TO_TSFPGA,
        vunit_proj=vunit_proj,
        modules=modules,
        ip_core_vivado_project_directory=ip_core_vivado_project_directory,
    )

    vunit_proj.main()


def find_git_test_filters(args):
    # Set up a dummy VUnit project that will be used for depency scanning. Note that sources are
    # added identically to the "real" VUnit project.
    vunit_proj, modules, _ = setup_vunit_project(args)

    testbenches_to_run = GitSimulationSubset(
        repo_root=tsfpga.REPO_ROOT,
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

    all_modules = get_tsfpga_modules()
    has_commercial_simulator = vunit_proj.get_simulator_name() != "ghdl"

    if has_commercial_simulator and not args.vivado_skip:
        # Includes modules with IP cores. Can only be used with a commercial simulator.
        sim_modules = all_modules
    else:
        # Only modules that do not contain IP cores
        sim_modules = [module for module in all_modules if len(module.get_ip_core_files()) == 0]

    if args.vivado_skip:
        ip_core_vivado_project_directory = None
    else:
        add_simlib(vunit_proj, args.temp_dir, args.simlib_compile)

        # Generate IP core simulation files. Will be used for the vhdl_ls config,
        # even if they are not added to the simulation project.
        (
            ip_core_compile_order_file,
            ip_core_vivado_project_directory,
        ) = generate_ip_core_files(all_modules, args.temp_dir, args.ip_compile)
        if has_commercial_simulator:
            add_from_compile_order_file(vunit_proj, ip_core_compile_order_file)

    for module in sim_modules:
        vunit_library = vunit_proj.add_library(module.library_name)
        for hdl_file in module.get_simulation_files():
            if hdl_file.is_vhdl or hdl_file.is_verilog_source:
                vunit_library.add_source_file(hdl_file.path)
            else:
                assert False, f"Can not handle this file: {hdl_file}"
        module.setup_vunit(vunit_proj)

    return vunit_proj, all_modules, ip_core_vivado_project_directory


def arguments():
    cli = VUnitCLI()
    cli.parser.add_argument(
        "--temp-dir",
        type=Path,
        default=TSFPGA_EXAMPLES_TEMP_DIR,
        help="where to place files needed for simulation flow",
    )
    cli.parser.add_argument(
        "--vivado-skip", action="store_true", help="skip all steps that require Vivado"
    )
    cli.parser.add_argument(
        "--ip-compile", action="store_true", help="force (re)compile of IP cores"
    )
    cli.parser.add_argument(
        "--simlib-compile", action="store_true", help="force (re)compile of Vivado simlib"
    )
    cli.parser.add_argument(
        "--git-minimal",
        action="store_true",
        help="compile and run only a minimal set of tests based on git history",
    )

    args = cli.parse_args()
    args.output_path = args.temp_dir / "vunit_out"
    return args


def add_simlib(vunit_proj, temp_dir, force_compile):
    vivado_simlib = VivadoSimlib.init(temp_dir, vunit_proj)
    if force_compile or vivado_simlib.compile_is_needed:
        vivado_simlib.compile()
        vivado_simlib.to_archive()
    vivado_simlib.add_to_vunit_project()


def generate_ip_core_files(modules, temp_dir, force_generate):
    vivado_ip_cores = VivadoIpCores(modules, temp_dir, "xc7z020clg400-1")

    if force_generate:
        vivado_ip_cores.create_vivado_project()
        vivado_project_created = True
    else:
        vivado_project_created = vivado_ip_cores.create_vivado_project_if_needed()

    if vivado_project_created:
        # If the IP core Vivado project has been (re)created we need to create
        # a new compile order file
        create_compile_order_file(
            vivado_ip_cores.vivado_project_file, vivado_ip_cores.compile_order_file
        )

    return vivado_ip_cores.compile_order_file, vivado_ip_cores.project_directory


def create_vhdl_ls_configuration(
    output_path, vunit_proj, modules, ip_core_vivado_project_directory
):
    """
    Create config for vhdl_ls. Granted this might no be the "correct" place for this functionality.
    But since the call is somewhat quick (~10 ms), and simulate.py is run "often" it seems an
    appropriate place in order to always have an up-to-date vhdl_ls config.
    """
    vivado_location = None if which("vivado") is None else Path(which("vivado"))
    tsfpga.create_vhdl_ls_config.create_configuration(
        output_path=output_path,
        modules=modules,
        vunit_proj=vunit_proj,
        vivado_location=vivado_location,
        ip_core_vivado_project_directory=ip_core_vivado_project_directory,
    )


if __name__ == "__main__":
    main()
