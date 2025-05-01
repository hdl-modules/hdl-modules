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
        self._setup_saturate_signed_tests(vunit_proj=vunit_proj)
        self._setup_truncate_round_signed_tests(vunit_proj=vunit_proj)
        self._setup_unsigned_divider_tests(vunit_proj=vunit_proj)

    def _setup_saturate_signed_tests(self, vunit_proj: VUnit) -> None:
        tb = vunit_proj.library(self.library_name).test_bench("tb_saturate_signed")
        self.add_vunit_config(test=tb, count=4)

    def _setup_truncate_round_signed_tests(self, vunit_proj: VUnit) -> None:
        fixed_input_width = 24
        fixed_result_width = 16

        tb = vunit_proj.library(self.library_name).test_bench("tb_truncate_round_signed")
        for test in tb.get_tests():
            if test.name == "test_non_convergent":
                self.add_vunit_config(test=test, count=4)
            else:

                def pre_config(output_path: str) -> bool:
                    import random
                    from pathlib import Path

                    # Can set random.seed here to get a deterministic random sequence.

                    output_path = Path(output_path)

                    min_input_value = -(2 ** (fixed_input_width - 1))
                    max_input_value = 2 ** (fixed_input_width - 1) - 1

                    divider = 2 ** (fixed_input_width - fixed_result_width)
                    min_result_value = -(2 ** (fixed_result_width - 1))
                    max_result_value = 2 ** (fixed_result_width - 1) - 1

                    input_values = ["" for _ in range(8192)]
                    result_values = ["" for _ in range(len(input_values))]
                    overflow_values = ["0" for _ in range(len(input_values))]

                    for index in range(len(input_values)):
                        input_value = random.randint(min_input_value, max_input_value)  # noqa: S311
                        result_value = round(input_value / divider)

                        if result_value > max_result_value:
                            overflow_values[index] = "1"
                            result_value = max_result_value
                        elif result_value < min_result_value:
                            overflow_values[index] = "1"
                            result_value = min_result_value

                        input_values[index] = str(input_value)
                        result_values[index] = str(result_value)

                    (output_path / "input_values.csv").write_text("\n".join(input_values))
                    (output_path / "result_values.csv").write_text("\n".join(result_values))
                    (output_path / "overflow_values.csv").write_text("\n".join(overflow_values))

                    return True

                self.add_vunit_config(
                    test=test,
                    generics={
                        "input_width": fixed_input_width,
                        "result_width": fixed_result_width,
                        "convergent_rounding": True,
                    },
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
            convergent_rounding: bool,
            lut: int,
            ff: int,
            logic: int,
        ) -> None:
            generics = {
                "convergent_rounding": convergent_rounding,
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

        add(convergent_rounding=False, lut=6, ff=52, logic=6)
        add(convergent_rounding=True, lut=7, ff=52, logic=8)

        return projects
