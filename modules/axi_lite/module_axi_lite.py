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
        for tb_name in ["tb_axi_to_axi_lite", "tb_axi_to_axi_lite_bus_error"]:
            tb = vunit_proj.library(self.library_name).test_bench(tb_name)
            for data_width in [32, 64]:
                name = f"data_width_{data_width}"
                tb.add_config(name=name, generics={"data_width": data_width})

        tb = vunit_proj.library(self.library_name).test_bench("tb_axi_to_axi_lite_vec")
        for pipeline_axi_lite in [True, False]:
            for pipeline_slaves in [True, False]:
                generics = {
                    "pipeline_axi_lite": pipeline_axi_lite,
                    "pipeline_slaves": pipeline_slaves,
                }
                self.add_vunit_config(tb, generics=generics)

        tb = vunit_proj.library(self.library_name).test_bench("tb_axi_lite_cdc")
        tb.add_config(name="master_clk_fast", generics={"master_clk_fast": True})
        tb.add_config(name="slave_clk_fast", generics={"slave_clk_fast": True})
        tb.add_config(name="same_clocks")

        tb = vunit_proj.library(self.library_name).test_bench("tb_axi_lite_mux")
        tb.test("read_from_non_existent_slave_base_address").set_generic("use_axi_lite_bfm", False)
        tb.test("write_to_non_existent_slave_base_address").set_generic("use_axi_lite_bfm", False)

        tb = vunit_proj.library(self.library_name).test_bench("tb_axi_lite_pkg")
        for test in tb.get_tests():
            if test.name in ["test_slv_conversion", "test_axi_lite_strb"]:
                for data_width in [32, 64]:
                    generics = {"data_width": data_width}
                    self.add_vunit_config(test=test, generics=generics)

    def get_build_projects(self) -> list[TsfpgaExampleVivadoNetlistProject]:
        # The 'hdl_modules' Python package is probably not on the PYTHONPATH in most scenarios where
        # this module is used. Hence we can not import at the top of this file.
        # This method is only called when running netlist builds in the hdl-modules repo from the
        # bundled tools/build_fpga.py, where PYTHONPATH is correctly set up.
        from hdl_modules import get_hdl_modules  # noqa: PLC0415

        projects = []
        modules = get_hdl_modules(
            names_include=[self.name, "axi", "common", "fifo", "resync", "math"]
        )
        part = "xc7z020clg400-1"

        projects.append(
            TsfpgaExampleVivadoNetlistProject(
                name=f"{self.library_name}.axi_lite_cdc",
                modules=modules,
                part=part,
                top="axi_lite_cdc",
                generics={"data_width": 32, "addr_width": 24},
                build_result_checkers=[
                    TotalLuts(EqualTo(199)),
                    Ffs(EqualTo(290)),
                    MaximumLogicLevel(EqualTo(4)),
                ],
            )
        )

        projects.append(
            TsfpgaExampleVivadoNetlistProject(
                name=f"{self.library_name}.axi_lite_mux",
                modules=modules,
                part=part,
                top="axi_lite_mux_netlist_build_wrapper",
                build_result_checkers=[
                    TotalLuts(EqualTo(516)),
                    Ffs(EqualTo(28)),
                    MaximumLogicLevel(EqualTo(5)),
                ],
            )
        )

        projects.append(
            TsfpgaExampleVivadoNetlistProject(
                name=f"{self.library_name}.axi_lite_simple_read_crossbar",
                modules=modules,
                part=part,
                top="axi_lite_simple_read_crossbar",
                generics={"num_inputs": 4},
                build_result_checkers=[
                    TotalLuts(EqualTo(78)),
                    Ffs(EqualTo(5)),
                    MaximumLogicLevel(EqualTo(3)),
                ],
            )
        )

        projects.append(
            TsfpgaExampleVivadoNetlistProject(
                name=f"{self.library_name}.axi_lite_simple_write_crossbar",
                modules=modules,
                part=part,
                top="axi_lite_simple_write_crossbar",
                generics={"num_inputs": 4},
                build_result_checkers=[
                    TotalLuts(EqualTo(153)),
                    Ffs(EqualTo(4)),
                    MaximumLogicLevel(EqualTo(4)),
                ],
            )
        )

        return projects
