# --------------------------------------------------------------------------------------------------
# Copyright (c) Lukas Vik. All rights reserved.
#
# This file is part of the hdl-modules project, a collection of reusable, high-quality,
# peer-reviewed VHDL building blocks.
# https://hdl-modules.com
# https://github.com/hdl-modules/hdl-modules
# --------------------------------------------------------------------------------------------------

# Third party libraries
from tsfpga.examples.vivado.project import TsfpgaExampleVivadoNetlistProject
from tsfpga.module import BaseModule
from tsfpga.vivado.build_result_checker import EqualTo, Ffs, TotalLuts


class Module(BaseModule):
    def setup_vunit(self, vunit_proj, **kwargs):  # pylint: disable=unused-argument
        self.setup_trail_pkg_tests(vunit_proj=vunit_proj)

    def setup_trail_pkg_tests(self, vunit_proj):
        tb_trail_pkg = vunit_proj.library(self.library_name).test_bench("tb_trail_pkg")
        test_slv_conversion = tb_trail_pkg.test("test_slv_conversion")

        tb_trail_pipeline = vunit_proj.library(self.library_name).test_bench("tb_trail_pipeline")

        tb_axi_lite_to_trail = vunit_proj.library(self.library_name).test_bench(
            "tb_axi_lite_to_trail"
        )

        for data_width in [8, 16, 32, 64]:
            for address_width in [7, 24, 40]:
                generics = dict(address_width=address_width, data_width=data_width)

                self.add_vunit_config(
                    test=test_slv_conversion, generics=generics, set_random_seed=True
                )
                self.add_vunit_config(
                    test=tb_trail_pipeline, generics=generics, set_random_seed=True
                )

                if data_width in [32, 64] and address_width < 32:
                    for _ in range(4):
                        self.add_vunit_config(
                            test=tb_axi_lite_to_trail, generics=generics, set_random_seed=True
                        )
                    self.add_vunit_config(
                        test=tb_axi_lite_to_trail, generics=generics, set_random_seed=711
                    )

        tb_trail_splitter = vunit_proj.library(self.library_name).test_bench("tb_trail_splitter")
        for _ in range(4):
            self.add_vunit_config(test=tb_trail_splitter, set_random_seed=True)

    def get_build_projects(self):
        # The 'hdl_modules' Python package is probably not on the PYTHONPATH in most scenarios where
        # this module is used. Hence we can not import at the top of this file.
        # This method is only called when running netlist builds in the hdl-modules repo from the
        # bundled tools/build_fpga.py, where PYTHONPATH is correctly set up.
        # pylint: disable=import-outside-toplevel
        # First party libraries
        from hdl_modules import get_hdl_modules

        projects = []
        all_modules = get_hdl_modules(
            names_include=[self.name, "axi", "axi_lite", "common", "math"]
        )
        part = "xc7z020clg400-1"

        def add(name: str, generics: dict, luts: int, ffs: int, top: str = ""):
            projects.append(
                TsfpgaExampleVivadoNetlistProject(
                    name=self.test_case_name(name=name, generics=generics),
                    modules=all_modules,
                    part=part,
                    top=name if top == "" else top,
                    generics=generics,
                    build_result_checkers=[TotalLuts(EqualTo(luts)), Ffs(EqualTo(ffs))],
                )
            )

        def add_trail_pipeline(generics: dict[str, bool], ffs: int):
            add(name="trail_pipeline", generics=generics, luts=0, ffs=ffs)

        def add_trail_splitter(generics: dict[str, bool], luts: int):
            add(
                name="trail_splitter",
                generics=generics,
                luts=luts,
                ffs=5,
                top="trail_splitter_netlist_build_wrapper",
            )

        add_trail_pipeline(generics=dict(address_width=38, data_width=64), ffs=0)
        add_trail_pipeline(
            generics=dict(address_width=40, data_width=32, pipeline_operation_address=True),
            ffs=(40 - 2) + 1,
        )
        add_trail_pipeline(
            generics=dict(
                address_width=24,
                data_width=16,
                pipeline_operation_write_data=True,
                pipeline_response_read_data=True,
            ),
            ffs=2 * (16 + 1),
        )
        add_trail_pipeline(
            generics=dict(
                address_width=20,
                data_width=32,
                pipeline_operation_address=True,
                pipeline_operation_write_enable=True,
                pipeline_response_read_data=True,
            ),
            ffs=53,
        )

        add(
            name="axi_lite_to_trail",
            generics=dict(address_width=24, data_width=32),
            luts=29,
            ffs=64,
        )
        add(
            name="axi_lite_to_trail",
            generics=dict(address_width=35, data_width=64),
            luts=34,
            ffs=106,
        )

        add_trail_splitter(generics=dict(address_width=32, data_width=64), luts=355)
        add_trail_splitter(generics=dict(address_width=24, data_width=32), luts=195)

        return projects
