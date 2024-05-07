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
        tb = vunit_proj.library(self.library_name).test_bench("tb_resync_slv_level")
        for output_clock_is_faster in [True, False]:
            for test_coherent in [True, False]:
                for enable_input_register in [True, False]:
                    if test_coherent and enable_input_register:
                        # Coherent implementation does not have the 'input_register' mode
                        continue

                    generics = dict(
                        output_clock_is_faster=output_clock_is_faster,
                        test_coherent=test_coherent,
                        enable_input_register=enable_input_register,
                    )
                    self.add_vunit_config(tb, generics=generics)

        tb = vunit_proj.library(self.library_name).test_bench("tb_resync_pulse")

        for enable_feedback in [True, False]:
            for active_level in [True, False]:
                for input_pulse_overload in [True, False]:
                    for mode in [
                        "output_clock_is_faster",
                        "output_clock_is_slower",
                        "clocks_are_same",
                    ]:
                        generics = dict(
                            enable_feedback=enable_feedback,
                            input_pulse_overload=input_pulse_overload,
                            active_level=active_level,
                        )
                        generics[mode] = True
                        self.add_vunit_config(tb, generics=generics)

        tb = vunit_proj.library(self.library_name).test_bench("tb_resync_counter")
        for pipeline_output in [True, False]:
            name = "pipeline_output" if pipeline_output else "dont_pipeline_output"

            generics = dict(pipeline_output=pipeline_output)
            tb.add_config(name=name, generics=generics)

        tb = vunit_proj.library(self.library_name).test_bench("tb_resync_cycles")
        for active_high in [True, False]:
            generics = dict(active_high=active_high, output_clock_is_faster=True)
            self.add_vunit_config(tb, generics=generics)

            generics = dict(active_high=active_high)
            self.add_vunit_config(tb, generics=generics)

            generics = dict(active_high=active_high, output_clock_is_slower=True)
            self.add_vunit_config(tb, generics=generics)

    def get_build_projects(self):
        # The 'hdl_modules' Python package is probably not on the PYTHONPATH in most scenarios where
        # this module is used. Hence we can not import at the top of this file.
        # This method is only called when running netlist builds in the hdl-modules repo from the
        # bundled tools/build_fpga.py, where PYTHONPATH is correctly set up.
        # pylint: disable=import-outside-toplevel
        # First party libraries
        from hdl_modules import get_hdl_modules

        projects = []
        modules = get_hdl_modules(names_include=[self.name, "common", "math"])
        part = "xc7z020clg400-1"

        for enable_feedback in [False, True]:
            generics = dict(enable_feedback=enable_feedback)
            projects.append(
                TsfpgaExampleVivadoNetlistProject(
                    name=self.test_case_name(
                        f"{self.library_name}.resync_pulse", generics=generics
                    ),
                    modules=modules,
                    part=part,
                    top="resync_pulse",
                    generics=generics,
                    build_result_checkers=[
                        TotalLuts(EqualTo(2 + 1 * enable_feedback)),
                        Ffs(EqualTo(4 + 3 * enable_feedback)),
                    ],
                )
            )

        generics = dict(counter_width=8)
        projects.append(
            TsfpgaExampleVivadoNetlistProject(
                name=self.test_case_name(f"{self.library_name}.resync_cycles", generics),
                modules=modules,
                part=part,
                top="resync_cycles",
                generics=generics,
                build_result_checkers=[
                    TotalLuts(EqualTo(26)),
                    Ffs(EqualTo(41)),
                ],
            )
        )

        generics = dict(width=16)
        projects.append(
            TsfpgaExampleVivadoNetlistProject(
                name=self.test_case_name(
                    f"{self.library_name}.resync_slv_level_coherent", generics
                ),
                modules=modules,
                part=part,
                top="resync_slv_level_coherent",
                generics=generics,
                build_result_checkers=[
                    TotalLuts(EqualTo(3)),
                    Ffs(EqualTo(38)),
                ],
            )
        )

        projects.append(
            TsfpgaExampleVivadoNetlistProject(
                name=self.test_case_name(f"{self.library_name}.resync_counter", generics),
                modules=modules,
                part=part,
                top="resync_counter",
                generics=generics,
                build_result_checkers=[
                    TotalLuts(EqualTo(23)),
                    Ffs(EqualTo(48)),
                ],
            )
        )

        return projects
