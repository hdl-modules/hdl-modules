# --------------------------------------------------------------------------------------------------
# Copyright (c) Lukas Vik. All rights reserved.
#
# This file is part of the hdl-modules project, a collection of reusable, high-quality,
# peer-reviewed VHDL building blocks.
# https://hdl-modules.com
# https://github.com/hdl-modules/hdl-modules
# --------------------------------------------------------------------------------------------------

from __future__ import annotations

from typing import Any

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
    def get_build_projects(self) -> list[TsfpgaExampleVivadoNetlistProject]:
        # The 'hdl_modules' Python package is probably not on the PYTHONPATH in most scenarios where
        # this module is used. Hence we can not import at the top of this file.
        # This method is only called when running netlist builds in the hdl-modules repo from the
        # bundled tools/build_fpga.py, where PYTHONPATH is correctly set up.
        from hdl_modules import get_hdl_modules  # noqa: PLC0415

        projects = []
        all_modules = get_hdl_modules(
            names_include=[self.name, "axi", "axi_lite", "common", "trail", "math"]
        )
        part = "xc7z020clg400-1"

        def add_register_file(
            name: str,
            luts: int,
            ffs: int,
            logic_level: int,
            generics: dict[str, Any] | None = None,
        ) -> None:
            projects.append(
                TsfpgaExampleVivadoNetlistProject(
                    name=self.netlist_build_name(name=f"{name}_register_file", generics=generics),
                    modules=all_modules,
                    part=part,
                    top=f"{name}_register_file_netlist_build_wrapper",
                    generics=generics,
                    build_result_checkers=[
                        TotalLuts(EqualTo(luts)),
                        Ffs(EqualTo(ffs)),
                        Ramb36(EqualTo(0)),
                        Ramb18(EqualTo(0)),
                        MaximumLogicLevel(EqualTo(logic_level)),
                    ],
                )
            )

        for enable_reset in [True, False]:
            add_register_file(
                name="axi_lite",
                luts=170 + 95 * enable_reset,
                ffs=301,
                logic_level=3,
                generics={"enable_reset": enable_reset},
            )

        add_register_file(name="trail", luts=116, ffs=312, logic_level=4)

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
