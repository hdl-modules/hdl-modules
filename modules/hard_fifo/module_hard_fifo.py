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
from tsfpga.vivado.build_result_checker import EqualTo, Ffs, MaximumLogicLevel, Ramb36, TotalLuts


class Module(BaseModule):
    def setup_vunit(self, vunit_proj, **kwargs):  # pylint: disable=unused-argument
        tb = vunit_proj.library(self.library_name).test_bench("tb_hard_fifo")

        for test in tb.get_tests():
            # Test all the standard cases, and one value that is in-between (21)
            for data_width in [4, 9, 16, 21, 36]:
                for is_asynchronous in [False, True]:
                    for read_clock_is_faster in [False, True]:
                        if read_clock_is_faster and not is_asynchronous:
                            # Loop over this parameter only for asynchronous test
                            continue

                        generics = dict(
                            data_width=data_width,
                            is_asynchronous=is_asynchronous,
                            read_clock_is_faster=read_clock_is_faster,
                            # On for a few and off for a few
                            enable_output_register=(data_width % 2) == 0,
                        )

                        if test.name == "test_fifo_full":
                            generics.update(read_stall_probability_percent=95)

                        if test.name == "test_fifo_empty":
                            generics.update(write_stall_probability_percent=95)

                        self.add_vunit_config(test, generics=generics)

    def get_build_projects(self):
        projects = []
        part = "xcku5p-ffva676-2-i"

        data_widths = [18, 32]
        enable_output_registers = [False, True]

        for idx, data_width in enumerate(data_widths):
            generics = dict(
                data_width=data_width, enable_output_register=enable_output_registers[idx]
            )

            for name in ["hard_fifo", "asynchronous_hard_fifo"]:
                projects.append(
                    TsfpgaExampleVivadoNetlistProject(
                        name=self.test_case_name(f"{self.library_name}.{name}", generics),
                        modules=[self],
                        part=part,
                        top=name,
                        generics=generics,
                        build_result_checkers=[
                            TotalLuts(EqualTo(3)),
                            Ffs(EqualTo(1)),
                            Ramb36(EqualTo(1)),
                            MaximumLogicLevel(EqualTo(2)),
                        ],
                    )
                )

        return projects
