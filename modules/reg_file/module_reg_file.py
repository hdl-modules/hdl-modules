# --------------------------------------------------------------------------------------------------
# Copyright (c) Lukas Vik. All rights reserved.
#
# This file is part of the tsfpga project.
# https://tsfpga.com
# https://gitlab.com/tsfpga/tsfpga
# --------------------------------------------------------------------------------------------------

from tsfpga.module import BaseModule, get_hdl_modules
from tsfpga.vivado.project import VivadoNetlistProject
from tsfpga.vivado.build_result_checker import (
    EqualTo,
    Ffs,
    LogicLuts,
    MaximumLogicLevel,
    Ramb18,
    Ramb36,
    TotalLuts,
)


class Module(BaseModule):
    def setup_vunit(self, vunit_proj, **kwargs):  # pylint: disable=unused-argument
        tb = vunit_proj.library(self.library_name).test_bench("tb_axi_lite_reg_file")
        tb.test("read_from_non_existent_register").set_generic("use_axi_lite_bfm", False)
        tb.test("read_from_non_read_type_register").set_generic("use_axi_lite_bfm", False)
        tb.test("write_to_non_existent_register").set_generic("use_axi_lite_bfm", False)
        tb.test("write_to_non_write_type_register").set_generic("use_axi_lite_bfm", False)

    def setup_formal(self, formal_proj, **kwargs):  # pylint: disable=unused-argument,no-self-use
        formal_proj.add_config(
            top="axi_lite_reg_file_wrapper",
            engine_command="smtbmc",
            solver_command="z3",
            mode="prove",
        )

    def get_build_projects(self):  # pylint: disable=no-self-use
        projects = []
        all_modules = get_hdl_modules()
        part = "xc7z020clg400-1"

        projects.append(
            VivadoNetlistProject(
                name=f"{self.library_name}.axi_lite_reg_file",
                modules=all_modules,
                part=part,
                top="axi_lite_reg_file_wrapper",
                build_result_checkers=[
                    TotalLuts(EqualTo(197)),
                    LogicLuts(EqualTo(197)),
                    Ffs(EqualTo(447)),
                    Ramb36(EqualTo(0)),
                    Ramb18(EqualTo(0)),
                    MaximumLogicLevel(EqualTo(4)),
                ],
            )
        )

        projects.append(
            VivadoNetlistProject(
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
