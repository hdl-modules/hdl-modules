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
        self.setup_axi_pkg_tests(vunit_proj=vunit_proj)
        self.setup_axi_read_throttle_tests(vunit_proj=vunit_proj)
        self.setup_axi_write_throttle_tests(vunit_proj=vunit_proj)

        tb = vunit_proj.library(self.library_name).test_bench("tb_axi_cdc")
        tb.add_config(name="input_clk_fast", generics={"input_clk_fast": True})
        tb.add_config(name="output_clk_fast", generics={"output_clk_fast": True})
        tb.add_config(name="same_clocks")

        tb = vunit_proj.library(self.library_name).test_bench("tb_axi_fifo")
        tb.add_config(name="passthrough", generics={"depth": 0})
        tb.add_config(name="synchronous", generics={"depth": 16, "asynchronous": False})
        tb.add_config(name="asynchronous", generics={"depth": 16, "asynchronous": True})

    def setup_axi_pkg_tests(self, vunit_proj: VUnit) -> None:
        tb = vunit_proj.library(self.library_name).test_bench("tb_axi_pkg")
        test = tb.test("test_slv_conversion")

        for data_width in [32, 64]:
            for id_width in [0, 5]:
                for addr_width in [32, 40]:
                    generics = {
                        "data_width": data_width,
                        "id_width": id_width,
                        "addr_width": addr_width,
                    }
                    self.add_vunit_config(test=test, generics=generics)

    def setup_axi_read_throttle_tests(self, vunit_proj: VUnit) -> None:
        tb = vunit_proj.library(self.library_name).test_bench("tb_axi_read_throttle")

        # Set low in order to keep simulation time down
        for max_burst_length_beats in [16, 32]:
            for full_ar_throughput in [True, False]:
                self.add_vunit_config(
                    test=tb,
                    generics={
                        "max_burst_length_beats": max_burst_length_beats,
                        "full_ar_throughput": full_ar_throughput,
                    },
                    count=2,
                )

    def setup_axi_write_throttle_tests(self, vunit_proj: VUnit) -> None:
        tb = vunit_proj.library(self.library_name).test_bench("tb_axi_write_throttle")

        for include_slave_w_fifo in [True, False]:
            self.add_vunit_config(
                test=tb, generics={"include_slave_w_fifo": include_slave_w_fifo}, count=4
            )

    def get_build_projects(self) -> list[TsfpgaExampleVivadoNetlistProject]:
        # The 'hdl_modules' Python package is probably not on the PYTHONPATH in most scenarios where
        # this module is used. Hence we can not import at the top of this file.
        # This method is only called when running netlist builds in the hdl-modules repo from the
        # bundled tools/build_fpga.py, where PYTHONPATH is correctly set up.
        from hdl_modules import get_hdl_modules  # noqa: PLC0415

        projects = []
        modules = get_hdl_modules(names_include=[self.name, "common", "fifo", "resync", "math"])
        part = "xc7z020clg400-1"

        projects.append(
            TsfpgaExampleVivadoNetlistProject(
                name=f"{self.library_name}.axi_write_throttle",
                modules=modules,
                part=part,
                top="axi_write_throttle",
                build_result_checkers=[
                    TotalLuts(EqualTo(5)),
                    Ffs(EqualTo(2)),
                    MaximumLogicLevel(EqualTo(2)),
                ],
            )
        )

        generics = {
            "data_fifo_depth": 1024,
            "max_burst_length_beats": 256,
            "id_width": 6,
            "addr_width": 32,
            "full_ar_throughput": False,
        }
        projects.append(
            TsfpgaExampleVivadoNetlistProject(
                name=f"{self.library_name}.axi_read_throttle",
                modules=modules,
                part=part,
                top="axi_read_throttle",
                generics=generics,
                build_result_checkers=[
                    TotalLuts(EqualTo(41)),
                    Ffs(EqualTo(76)),
                    MaximumLogicLevel(EqualTo(8)),
                ],
            )
        )

        projects.append(
            TsfpgaExampleVivadoNetlistProject(
                name=f"{self.library_name}.axi_simple_read_crossbar",
                modules=modules,
                part=part,
                top="axi_simple_read_crossbar",
                generics={"num_inputs": 4},
                build_result_checkers=[
                    TotalLuts(EqualTo(120)),
                    Ffs(EqualTo(5)),
                    MaximumLogicLevel(EqualTo(4)),
                ],
            )
        )

        projects.append(
            TsfpgaExampleVivadoNetlistProject(
                name=f"{self.library_name}.axi_simple_write_crossbar",
                modules=modules,
                part=part,
                top="axi_simple_write_crossbar",
                generics={"num_inputs": 4},
                build_result_checkers=[
                    TotalLuts(EqualTo(298)),
                    Ffs(EqualTo(5)),
                    MaximumLogicLevel(EqualTo(4)),
                ],
            )
        )

        return projects
