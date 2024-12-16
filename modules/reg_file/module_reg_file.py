# --------------------------------------------------------------------------------------------------
# Copyright (c) Lukas Vik. All rights reserved.
#
# This file is part of the hdl-modules project, a collection of reusable, high-quality,
# peer-reviewed VHDL building blocks.
# https://hdl-modules.com
# https://github.com/hdl-modules/hdl-modules
# --------------------------------------------------------------------------------------------------

# Third party libraries
from tsfpga.examples.vivado.project import TsfpgaExampleVivadoNetlistProject
from tsfpga.module import BaseModule
from tsfpga.vivado.build_result_checker import (
    EqualTo,
    Ffs,
    MaximumLogicLevel,
    Ramb18,
    Ramb36,
    TotalLuts,
)


class Module(BaseModule):
    def setup_vunit(self, vunit_proj, **kwargs):  # pylint: disable=unused-argument
        tb = vunit_proj.library(self.library_name).test_bench("tb_axi_lite_reg_file")

        tb.test("test_read_from_non_existent_register").set_generic("use_axi_lite_bfm", False)
        tb.test("test_read_from_non_read_type_register").set_generic("use_axi_lite_bfm", False)
        tb.test("test_write_to_non_existent_register").set_generic("use_axi_lite_bfm", False)
        tb.test("test_write_to_non_write_type_register").set_generic("use_axi_lite_bfm", False)

        self.add_vunit_config(test=tb, set_random_seed=True)

    def get_build_projects(self):
        # The 'hdl_modules' Python package is probably not on the PYTHONPATH in most scenarios where
        # this module is used. Hence we can not import at the top of this file.
        # This method is only called when running netlist builds in the hdl-modules repo from the
        # bundled tools/build_fpga.py, where PYTHONPATH is correctly set up.
        # pylint: disable=import-outside-toplevel
        # First party libraries
        from hdl_modules import get_hdl_modules

        projects = []
        all_modules = get_hdl_modules(
            names_include=[self.name, "axi", "axi_lite", "common", "trail", "math"]
        )
        part = "xc7z020clg400-1"

        def add_reg_file(name: str, luts: int, ffs: int, logic_level: int):
            projects.append(
                TsfpgaExampleVivadoNetlistProject(
                    name=f"{self.library_name}.{name}_reg_file",
                    modules=all_modules,
                    part=part,
                    top=f"{name}_reg_file_netlist_wrapper",
                    build_result_checkers=[
                        TotalLuts(EqualTo(luts)),
                        Ffs(EqualTo(ffs)),
                        Ramb36(EqualTo(0)),
                        Ramb18(EqualTo(0)),
                        MaximumLogicLevel(EqualTo(logic_level)),
                    ],
                )
            )

        add_reg_file(name="axi_lite", luts=202, ffs=447, logic_level=4)
        add_reg_file(name="trail", luts=178, ffs=439, logic_level=3)

        projects.append(
            TsfpgaExampleVivadoNetlistProject(
                name=f"{self.library_name}.interrupt_register",
                modules=all_modules,
                part=part,
                top="interrupt_register",
                build_result_checkers=[
                    TotalLuts(EqualTo(39)),
                    Ffs(EqualTo(33)),
                    MaximumLogicLevel(EqualTo(5)),
                ],
            )
        )

        return projects
