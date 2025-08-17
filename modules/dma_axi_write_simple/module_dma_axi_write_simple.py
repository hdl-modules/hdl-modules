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
        test = vunit_proj.library(self.library_name).test_bench("tb_dma_axi_write_simple")
        self.add_vunit_config(test=test, count=8)

    def get_build_projects(self) -> list[TsfpgaExampleVivadoNetlistProject]:
        # The 'hdl_modules' Python package is probably not on the PYTHONPATH in most scenarios where
        # this module is used. Hence we can not import at the top of this file.
        # This method is only called when running netlist builds in the hdl-modules repo from the
        # bundled tools/build_fpga.py, where PYTHONPATH is correctly set up.
        from hdl_modules import get_hdl_modules  # noqa: PLC0415

        modules = get_hdl_modules()
        part = "xc7z020clg400-1"

        projects = []

        def add(generics: dict, lut: int, ff: int, logic: int) -> None:
            all_generics = dict(address_width=29, stream_data_width=64, **generics)
            projects.append(
                TsfpgaExampleVivadoNetlistProject(
                    name=self.netlist_build_name(
                        "dma_axi_write_simple_axi_lite", generics=all_generics
                    ),
                    modules=modules,
                    part=part,
                    top="dma_axi_write_simple_axi_lite",
                    generics=all_generics,
                    build_result_checkers=[
                        TotalLuts(EqualTo(lut)),
                        Ffs(EqualTo(ff)),
                        MaximumLogicLevel(EqualTo(logic)),
                    ],
                )
            )

        add(generics={"axi_data_width": 64, "packet_length_beats": 1}, lut=156, ff=207, logic=16)
        add(generics={"axi_data_width": 64, "packet_length_beats": 16}, lut=157, ff=226, logic=12)
        add(generics={"axi_data_width": 64, "packet_length_beats": 2048}, lut=132, ff=218, logic=11)
        add(
            generics={"axi_data_width": 64, "packet_length_beats": 16384}, lut=134, ff=218, logic=10
        )

        add(
            generics={"axi_data_width": 32, "packet_length_beats": 16384}, lut=171, ff=320, logic=11
        )
        add(
            generics={"axi_data_width": 128, "packet_length_beats": 16384},
            lut=198,
            ff=410,
            logic=11,
        )
        add(
            generics={
                "axi_data_width": 64,
                "packet_length_beats": 1024,
                "write_done_aggregate_count": 512,
                "write_done_aggregate_ticks": 262144,
            },
            lut=156,
            ff=247,
            logic=12,
        )

        return projects
