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
from tsfpga.vivado.build_result_checker import EqualTo, Ffs, MaximumLogicLevel, TotalLuts


class Module(BaseModule):
    def setup_vunit(self, vunit_proj, **kwargs):  # pylint: disable=unused-argument
        test = vunit_proj.library(self.library_name).test_bench("tb_simple_dma_axi_lite")
        for _ in range(8):
            self.add_vunit_config(test=test, set_random_seed=True)

    def get_build_projects(self):
        # The 'hdl_modules' Python package is probably not on the PYTHONPATH in most scenarios where
        # this module is used. Hence we can not import at the top of this file.
        # This method is only called when running netlist builds in the hdl-modules repo from the
        # bundled tools/build_fpga.py, where PYTHONPATH is correctly set up.
        # pylint: disable=import-outside-toplevel
        # First party libraries
        from hdl_modules import get_hdl_modules

        modules = get_hdl_modules()
        part = "xc7z020clg400-1"

        generics = dict(
            address_width=29, stream_data_width=64, axi_data_width=64, packet_length_beats=1
        )

        return [
            TsfpgaExampleVivadoNetlistProject(
                name=self.test_case_name(f"{self.library_name}.simple_dma_axi_lite", generics),
                modules=modules,
                part=part,
                top="simple_dma_axi_lite",
                generics=generics,
                build_result_checkers=[
                    TotalLuts(EqualTo(156)),
                    Ffs(EqualTo(207)),
                    MaximumLogicLevel(EqualTo(16)),
                ],
            )
        ]
