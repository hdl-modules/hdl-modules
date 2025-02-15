# --------------------------------------------------------------------------------------------------
# Copyright (c) Lukas Vik. All rights reserved.
#
# This file is part of the hdl-modules project, a collection of reusable, high-quality,
# peer-reviewed VHDL building blocks.
# https://hdl-modules.com
# https://github.com/hdl-modules/hdl-modules
# --------------------------------------------------------------------------------------------------

from __future__ import annotations

from typing import TYPE_CHECKING, Any

from tsfpga.examples.vivado.project import TsfpgaExampleVivadoNetlistProject
from tsfpga.module import BaseModule
from tsfpga.vivado.build_result_checker import EqualTo, Ffs, MaximumLogicLevel, TotalLuts

if TYPE_CHECKING:
    from vunit.ui import VUnit


class Module(BaseModule):
    def setup_vunit(
        self,
        vunit_proj: VUnit,
        **kwargs: Any,  # noqa: ANN401, ARG002
    ) -> None:
        self._setup_math_pkg_tests(vunit_proj=vunit_proj)
        self._setup_saturate_signed_tests(vunit_proj=vunit_proj)
        self._setup_truncate_round_signed_tests(vunit_proj=vunit_proj)
        self._setup_unsigned_divider_tests(vunit_proj=vunit_proj)

    def _setup_math_pkg_tests(self, vunit_proj: VUnit) -> None:
        tb = vunit_proj.library(self.library_name).test_bench("tb_math_pkg")
        self.add_vunit_config(test=tb, set_random_seed=True)

    def _setup_saturate_signed_tests(self, vunit_proj: VUnit) -> None:
        tb = vunit_proj.library(self.library_name).test_bench("tb_saturate_signed")
        for _ in range(4):
            self.add_vunit_config(test=tb, set_random_seed=True)

    def _setup_truncate_round_signed_tests(self, vunit_proj: VUnit) -> None:
        tb = vunit_proj.library(self.library_name).test_bench("tb_truncate_round_signed")
        for _ in range(4):
            self.add_vunit_config(test=tb, set_random_seed=True)

    def _setup_unsigned_divider_tests(self, vunit_proj: VUnit) -> None:
        tb = vunit_proj.library(self.library_name).test_bench("tb_unsigned_divider")
        for dividend_width in [4, 7, 8]:
            for divisor_width in [4, 7, 8]:
                name = f"{dividend_width}_div_{divisor_width}"
                tb.add_config(
                    name=name,
                    generics={"dividend_width": dividend_width, "divisor_width": divisor_width},
                )

    def get_build_projects(self) -> list[TsfpgaExampleVivadoNetlistProject]:
        # The 'hdl_modules' Python package is probably not on the PYTHONPATH in most scenarios where
        # this module is used. Hence we can not import at the top of this file.
        # This method is only called when running netlist builds in the hdl-modules repo from the
        # bundled tools/build_fpga.py, where PYTHONPATH is correctly set up.
        from hdl_modules import get_hdl_modules

        projects = []
        all_modules = get_hdl_modules(names_include=[self.name, "common"])
        part = "xc7z020clg400-1"

        projects.append(
            TsfpgaExampleVivadoNetlistProject(
                name=f"{self.library_name}.truncate_round_signed",
                modules=all_modules,
                top="truncate_round_signed",
                part=part,
                generics={"input_width": 32, "result_width": 24, "enable_output_register": True},
                build_result_checkers=[
                    TotalLuts(EqualTo(6)),
                    Ffs(EqualTo(25)),
                    MaximumLogicLevel(EqualTo(6)),
                ],
            )
        )

        return projects
