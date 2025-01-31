# --------------------------------------------------------------------------------------------------
# Copyright (c) Lukas Vik. All rights reserved.
#
# This file is part of the hdl-modules project, a collection of reusable, high-quality,
# peer-reviewed VHDL building blocks.
# https://hdl-modules.com
# https://github.com/hdl-modules/hdl-modules
# --------------------------------------------------------------------------------------------------

# Standard libraries
from typing import TYPE_CHECKING

# Third party libraries
from tsfpga.examples.vivado.project import TsfpgaExampleVivadoNetlistProject
from tsfpga.module import BaseModule
from tsfpga.vivado.build_result_checker import EqualTo, Ffs, MaximumLogicLevel, TotalLuts

if TYPE_CHECKING:
    # Third party libraries
    from vunit.ui import VUnit


class Module(BaseModule):
    def setup_vunit(self, vunit_proj: "VUnit", **kwargs):  # pylint: disable=unused-argument
        test = (
            vunit_proj.library(self.library_name)
            .test_bench("tb_ring_buffer_write_simple")
            .get_tests("test_random_addresses")[0]
        )

        for segment_length_bytes in [1, 4, 8]:
            for buffer_size_segments in [2, 4, 16]:
                generics = dict(
                    segment_length_bytes=segment_length_bytes,
                    buffer_size_segments=buffer_size_segments,
                )
                self.add_vunit_config(test=test, generics=generics, set_random_seed=True)

        test = (
            vunit_proj.library(self.library_name)
            .test_bench("tb_ring_buffer_write_simple")
            .get_tests("test_invalid_addresses")[0]
        )
        self.add_vunit_config(
            test=test, generics=dict(segment_length_bytes=4, buffer_size_segments=4, seed=0)
        )

    def get_build_projects(self):
        # The 'hdl_modules' Python package is probably not on the PYTHONPATH in most scenarios where
        # this module is used. Hence we can not import at the top of this file.
        # This method is only called when running netlist builds in the hdl-modules repo from the
        # bundled tools/build_fpga.py, where PYTHONPATH is correctly set up.
        # pylint: disable=import-outside-toplevel
        # First party libraries
        from hdl_modules import get_hdl_modules

        modules = get_hdl_modules(names_include=[self.name, "common", "math"])
        part = "xc7z020clg400-1"

        generics = dict(address_width=29, segment_length_bytes=64)

        return [
            TsfpgaExampleVivadoNetlistProject(
                name=self.test_case_name(f"{self.library_name}.ring_buffer_write_simple", generics),
                modules=modules,
                part=part,
                top="ring_buffer_write_simple",
                generics=generics,
                build_result_checkers=[
                    TotalLuts(EqualTo(94)),
                    Ffs(EqualTo(52)),
                    MaximumLogicLevel(EqualTo(12)),
                ],
            )
        ]
