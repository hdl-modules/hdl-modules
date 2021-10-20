# --------------------------------------------------------------------------------------------------
# Copyright (c) Lukas Vik. All rights reserved.
#
# This file is part of the tsfpga project.
# https://tsfpga.com
# https://gitlab.com/tsfpga/tsfpga
# --------------------------------------------------------------------------------------------------

from tsfpga.module import BaseModule, get_hdl_modules
from tsfpga.vivado.project import VivadoNetlistProject


class Module(BaseModule):
    def setup_vunit(self, vunit_proj, **kwargs):  # pylint: disable=unused-argument
        tb = vunit_proj.library(self.library_name).test_bench("tb_axi_pkg")
        for data_width in [32, 64]:
            for id_width in [0, 5]:
                for addr_width in [32, 40]:
                    generics = dict(data_width=data_width, id_width=id_width, addr_width=addr_width)
                    self.add_vunit_config(tb, generics=generics)

        tb = vunit_proj.library(self.library_name).test_bench("tb_axi_lite_pkg")
        for data_width in [32, 64]:
            generics = dict(data_width=data_width)
            self.add_vunit_config(tb, generics=generics)

        for tb_name in ["tb_axi_to_axi_lite", "tb_axi_to_axi_lite_bus_error"]:
            tb = vunit_proj.library(self.library_name).test_bench(tb_name)
            for data_width in [32, 64]:
                name = f"data_width_{data_width}"
                tb.add_config(name=name, generics=dict(data_width=data_width))

        tb = vunit_proj.library(self.library_name).test_bench("tb_axi_stream_pkg")
        for data_width in [24, 32, 64]:
            for user_width in [8, 16]:
                generics = dict(data_width=data_width, user_width=user_width)
                self.add_vunit_config(tb, generics=generics)

        tb = vunit_proj.library(self.library_name).test_bench("tb_axi_to_axi_lite_vec")
        self.add_vunit_config(tb, generics=dict(pipeline=True))
        self.add_vunit_config(tb, generics=dict(pipeline=False))

        # The setting of max_burst_length_beats is not really dependent on the clock configurations,
        # so we do not need to test every possible combination of these settings.
        tb = vunit_proj.library(self.library_name).test_bench("tb_axi_cdc")
        tb.add_config(
            name="input_clk_fast", generics=dict(input_clk_fast=True, max_burst_length_beats=16)
        )
        tb.add_config(
            name="output_clk_fast", generics=dict(output_clk_fast=True, max_burst_length_beats=256)
        )
        tb.add_config(name="same_clocks", generics=dict(max_burst_length_beats=16))

        tb = vunit_proj.library(self.library_name).test_bench("tb_axi_lite_cdc")
        tb.add_config(name="master_clk_fast", generics=dict(master_clk_fast=True))
        tb.add_config(name="slave_clk_fast", generics=dict(slave_clk_fast=True))
        tb.add_config(name="same_clocks")

        tb = vunit_proj.library(self.library_name).test_bench("tb_axi_fifo")
        tb.add_config(name="passthrough", generics=dict(depth=0))
        tb.add_config(name="synchronous", generics=dict(depth=16, asynchronous=False))
        tb.add_config(name="asynchronous", generics=dict(depth=16, asynchronous=True))

        tb = vunit_proj.library(self.library_name).test_bench("tb_axi_stream_fifo")
        tb.add_config(name="synchronous", generics=dict(depth=16, asynchronous=False))
        tb.add_config(name="asynchronous", generics=dict(depth=16, asynchronous=True))

        tb = vunit_proj.library(self.library_name).test_bench("tb_axi_simple_crossbar")
        tb.add_config(name="axi_lite", generics=dict(test_axi_lite=True))
        tb.add_config(name="axi", generics=dict(test_axi_lite=False))

        tb = vunit_proj.library(self.library_name).test_bench("tb_axi_lite_mux")
        tb.test("read_from_non_existent_slave_base_address").set_generic("use_axi_lite_bfm", False)
        tb.test("write_to_non_existent_slave_base_address").set_generic("use_axi_lite_bfm", False)

    def get_build_projects(self):
        projects = []
        modules = get_hdl_modules(names_include=[self.name, "common", "math"])
        part = "xc7z020clg400-1"

        generics = dict(
            data_fifo_depth=1024,
            max_burst_length_beats=256,
            id_width=6,
            addr_width=32,
            full_ar_throughput=False,
            full_aw_throughput=False,
        )

        projects.append(
            VivadoNetlistProject(
                name=f"{self.library_name}.axi_read_throttle",
                modules=modules,
                part=part,
                top="axi_read_throttle",
                generics=generics,
            )
        )

        projects.append(
            VivadoNetlistProject(
                name=f"{self.library_name}.axi_write_throttle",
                modules=modules,
                part=part,
                top="axi_write_throttle",
                generics=generics,
            )
        )

        return projects
