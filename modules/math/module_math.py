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
        fixed_input_width = 24
        fixed_result_width = 16

        for test in (
            vunit_proj.library(self.library_name).test_bench("tb_truncate_round_signed").get_tests()
        ):
            if test.name == "test_random_data":
                for _ in range(4):
                    self.add_vunit_config(test=test, set_random_seed=True)
            else:

                def pre_config(output_path: str) -> bool:
                    import random
                    from pathlib import Path

                    # Can set random.seed here to get a deterministic random sequence.

                    output_path = Path(output_path)

                    min_value = -(2 ** (fixed_input_width - 1))
                    max_value = 2 ** (fixed_input_width - 1) - 1
                    divider = 2 ** (fixed_input_width - fixed_result_width)

                    input_values = ["" for _ in range(8192)]
                    result_values = ["" for _ in range(len(input_values))]

                    for index in range(len(input_values)):
                        input_value = random.randint(min_value, max_value)  # noqa: S311
                        result_value = round(input_value / divider)

                        input_values[index] = str(input_value)
                        result_values[index] = str(result_value)

                    (output_path / "input_values.csv").write_text("\n".join(input_values))
                    (output_path / "result_values.csv").write_text("\n".join(result_values))

                    return True

                generics = {
                    "input_width": fixed_input_width,
                    "result_width": fixed_result_width,
                    "convergent_rounding": True,
                }

                self.add_vunit_config(
                    test=test,
                    generics=generics,
                    set_random_seed=True,
                    pre_config=pre_config,
                )
                self.add_vunit_config(
                    test=test,
                    generics=generics,
                    set_random_seed=1237191019,
                    pre_config=pre_config,
                )

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

        def add(
            lut: int,
            ff: int,
            logic: int,
        ) -> None:
            generics = {
                "enable_addition_register": True,
                "enable_saturation": True,
                "enable_saturation_register": True,
                "input_width": 32,
                "result_width": 24,
            }

            projects.append(
                TsfpgaExampleVivadoNetlistProject(
                    name=self.test_case_name(
                        name=f"{self.library_name}.truncate_round_signed", generics=generics
                    ),
                    modules=all_modules,
                    top="truncate_round_signed",
                    part=part,
                    generics=generics,
                    build_result_checkers=[
                        TotalLuts(EqualTo(lut)),
                        Ffs(EqualTo(ff)),
                        MaximumLogicLevel(EqualTo(logic)),
                    ],
                )
            )

        add(lut=7, ff=52, logic=8)

        return projects
