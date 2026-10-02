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
from tsfpga.vivado.build_result_checker import EqualTo, Ffs, TotalLuts

if TYPE_CHECKING:
    from vunit.ui import VUnit


class Module(BaseModule):
    def setup_vunit(
        self,
        vunit_proj: VUnit,
        **kwargs: Any,  # noqa: ANN401, ARG002
    ) -> None:
        self.setup_trail_pkg_tests(vunit_proj=vunit_proj)

    def setup_trail_pkg_tests(self, vunit_proj: VUnit) -> None:
        tb_trail_cdc = vunit_proj.library(self.library_name).test_bench("tb_trail_cdc")

        tb_trail_pkg = vunit_proj.library(self.library_name).test_bench("tb_trail_pkg")

        test_slv_conversion = tb_trail_pkg.test("test_slv_conversion")

        tb_trail_pipeline = vunit_proj.library(self.library_name).test_bench("tb_trail_pipeline")

        tb_axi_to_trail = vunit_proj.library(self.library_name).test_bench("tb_axi_to_trail")

        for data_width in [8, 16, 32, 64]:
            for address_width in [7, 24, 40]:
                generics = {"address_width": address_width, "data_width": data_width}

                self.add_vunit_config(test=test_slv_conversion, generics=generics)
                self.add_vunit_config(test=tb_trail_pipeline, generics=generics)

                # FIX!!! Does not need to be run for all combinations of address and data width.
                for use_lutram in [True, False]:
                    # FIX!!! this does not need to be tested here.
                    # Should be done in tb_resync_rarely_valid_lutram.
                    for use_lutram_output_register in [True, False]:
                        self.add_vunit_config(
                            test=tb_trail_cdc,
                            generics=dict(
                                use_lutram=use_lutram,
                                use_lutram_output_register=use_lutram_output_register,
                                **generics,
                            ),
                        )

                if data_width in [32, 64] and address_width < 32:
                    for test_axi_lite in [True, False]:
                        generics["test_axi_lite"] = test_axi_lite

                        self.add_vunit_config(
                            test=tb_axi_to_trail,
                            generics=generics,
                            # , count=4
                        )

        tb_trail_splitter = vunit_proj.library(self.library_name).test_bench("tb_trail_splitter")
        self.add_vunit_config(test=tb_trail_splitter, count=4)

    def get_build_projects(self) -> list[TsfpgaExampleVivadoNetlistProject]:
        # The 'hdl_modules' Python package is probably not on the PYTHONPATH in most scenarios where
        # this module is used. Hence we can not import at the top of this file.
        # This method is only called when running netlist builds in the hdl-modules repo from the
        # bundled tools/build_fpga.py, where PYTHONPATH is correctly set up.
        from hdl_modules import get_hdl_modules  # noqa: PLC0415

        projects = []
        all_modules = get_hdl_modules(
            names_include=[self.name, "axi", "axi_lite", "common", "math", "resync"]
        )
        part = "xc7z020clg400-1"

        def add(name: str, generics: dict, luts: int, ffs: int, top: str = "") -> None:
            projects.append(
                TsfpgaExampleVivadoNetlistProject(
                    name=self.netlist_build_name(name, generics=generics),
                    modules=all_modules,
                    part=part,
                    top=name if top == "" else top,
                    generics=generics,
                    build_result_checkers=[TotalLuts(EqualTo(luts)), Ffs(EqualTo(ffs))],
                )
            )

        def add_trail_pipeline(generics: dict[str, bool], ffs: int) -> None:
            add(name="trail_pipeline", generics=generics, luts=0, ffs=ffs)

        def add_trail_splitter(generics: dict[str, bool], luts: int) -> None:
            add(
                name="trail_splitter",
                generics=generics,
                luts=luts,
                ffs=5,
                top="trail_splitter_netlist_build_wrapper",
            )

        add_trail_pipeline(generics={"address_width": 38, "data_width": 64}, ffs=0)
        add_trail_pipeline(
            generics={"address_width": 40, "data_width": 32, "pipeline_operation_address": True},
            ffs=(40 - 2) + 1,
        )
        add_trail_pipeline(
            generics={
                "address_width": 24,
                "data_width": 16,
                "pipeline_operation_write_data": True,
                "pipeline_response_read_data": True,
            },
            ffs=2 * (16 + 1),
        )
        add_trail_pipeline(
            generics={
                "address_width": 20,
                "data_width": 32,
                "pipeline_operation_address": True,
                "pipeline_operation_write_enable": True,
                "pipeline_response_read_data": True,
            },
            ffs=53,
        )

        add(
            name="axi_lite_to_trail",
            generics={"address_width": 24, "data_width": 32},
            luts=29,
            ffs=64,
        )
        add(
            name="axi_lite_to_trail",
            generics={"address_width": 35, "data_width": 64},
            luts=34,
            ffs=106,
        )

        add_trail_splitter(generics={"address_width": 32, "data_width": 64}, luts=355)
        add_trail_splitter(generics={"address_width": 24, "data_width": 32}, luts=195)

        add(
            name="trail_cdc",
            generics={"address_width": 24, "data_width": 32, "use_lutram": False},
            luts=4,
            ffs=186,
        )
        add(
            name="trail_cdc",
            generics={"address_width": 35, "data_width": 64, "use_lutram": False},
            luts=4,
            ffs=334,
        )
        add(
            name="trail_cdc",
            generics={"address_width": 24, "data_width": 32, "use_lutram": True},
            luts=66,
            ffs=8,
        )
        add(
            name="trail_cdc",
            generics={"address_width": 35, "data_width": 64, "use_lutram": True},
            luts=114,
            ffs=8,
        )
        add(
            name="trail_cdc",
            generics={
                "address_width": 24,
                "data_width": 32,
                "use_lutram": True,
                "use_lutram_output_register": True,
            },
            luts=66,
            ffs=98,
        )
        add(
            name="trail_cdc",
            generics={
                "address_width": 35,
                "data_width": 64,
                "use_lutram": True,
                "use_lutram_output_register": True,
            },
            luts=114,
            ffs=172,
        )

        return projects
