# --------------------------------------------------------------------------------------------------
# Copyright (c) Lukas Vik. All rights reserved.
#
# This file is part of the hdl-modules project, a collection of reusable, high-quality,
# peer-reviewed VHDL building blocks.
# https://hdl-modules.com
# https://github.com/hdl-modules/hdl-modules
# --------------------------------------------------------------------------------------------------

# Third party libraries
from tsfpga.module import BaseModule
from tsfpga.vivado.build_result_checker import EqualTo, Ffs, MaximumLogicLevel, TotalLuts
from tsfpga.vivado.project import VivadoNetlistProject


class Module(BaseModule):
    def setup_vunit(self, vunit_proj, **kwargs):  # pylint: disable=unused-argument
        self.setup_axi_pkg_tests(vunit_proj=vunit_proj)
        self.setup_axi_read_throttle_tests(vunit_proj=vunit_proj)
        self.setup_axi_write_throttle_tests(vunit_proj=vunit_proj)

        tb = vunit_proj.library(self.library_name).test_bench("tb_axi_cdc")
        tb.add_config(name="input_clk_fast", generics=dict(input_clk_fast=True))
        tb.add_config(name="output_clk_fast", generics=dict(output_clk_fast=True))
        tb.add_config(name="same_clocks")

        tb = vunit_proj.library(self.library_name).test_bench("tb_axi_fifo")
        tb.add_config(name="passthrough", generics=dict(depth=0))
        tb.add_config(name="synchronous", generics=dict(depth=16, asynchronous=False))
        tb.add_config(name="asynchronous", generics=dict(depth=16, asynchronous=True))

        tb = vunit_proj.library(self.library_name).test_bench("tb_axi_simple_crossbar")
        tb.add_config(name="axi_lite", generics=dict(test_axi_lite=True))
        tb.add_config(name="axi", generics=dict(test_axi_lite=False))

        tb = vunit_proj.library(self.library_name).test_bench("tb_axi_pipeline")
        self.add_vunit_config(test=tb, set_random_seed=True)

    def setup_axi_pkg_tests(self, vunit_proj):
        tb = vunit_proj.library(self.library_name).test_bench("tb_axi_pkg")
        for test in tb.get_tests("test_slv_conversion"):
            for data_width in [32, 64]:
                for id_width in [0, 5]:
                    for addr_width in [32, 40]:
                        generics = dict(
                            data_width=data_width, id_width=id_width, addr_width=addr_width
                        )
                        self.add_vunit_config(test=test, generics=generics)

    def setup_axi_read_throttle_tests(self, vunit_proj):
        tb = vunit_proj.library(self.library_name).test_bench("tb_axi_read_throttle")

        # Set low in order to keep simulation time down
        for max_burst_length_beats in [16, 32]:
            for full_ar_throughput in [True, False]:
                generics = dict(
                    max_burst_length_beats=max_burst_length_beats,
                    full_ar_throughput=full_ar_throughput,
                )

                for _ in range(2):
                    self.add_vunit_config(test=tb, set_random_seed=True, generics=generics)

    def setup_axi_write_throttle_tests(self, vunit_proj):
        tb = vunit_proj.library(self.library_name).test_bench("tb_axi_write_throttle")

        for include_slave_w_fifo in [True, False]:
            generics = dict(include_slave_w_fifo=include_slave_w_fifo)

            for _ in range(4):
                self.add_vunit_config(test=tb, set_random_seed=True, generics=generics)

    def get_build_projects(self):
        # The 'hdl_modules' Python package is probably not on the PYTHONPATH in most scenarios where
        # this module is used. Hence we can not import at the top of this file.
        # This method is only called when running netlist builds in the hdl-modules repo from the
        # bundled tools/build.py, where PYTHONPATH is correctly set up.
        # pylint: disable=import-outside-toplevel
        # First party libraries
        from hdl_modules import get_hdl_modules

        projects = []
        modules = get_hdl_modules(names_include=[self.name, "common", "fifo", "resync", "math"])
        part = "xc7z020clg400-1"

        projects.append(
            VivadoNetlistProject(
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

        generics = dict(
            data_fifo_depth=1024,
            max_burst_length_beats=256,
            id_width=6,
            addr_width=32,
            full_ar_throughput=False,
        )

        projects.append(
            VivadoNetlistProject(
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

        return projects
