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
from tsfpga.vivado.build_result_checker import EqualTo, Ffs, TotalLuts
from tsfpga.vivado.project import VivadoNetlistProject


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
        for input_pulse_overload in [True, False]:
            name = "pulse_gating." if input_pulse_overload else ""

            generics = dict(input_pulse_overload=input_pulse_overload, output_clock_is_faster=True)
            tb.add_config(name=name + "output_clock_is_faster", generics=generics)

            generics = dict(input_pulse_overload=input_pulse_overload)
            tb.add_config(name=name + "output_clock_is_same", generics=generics)

            generics = dict(input_pulse_overload=input_pulse_overload, output_clock_is_slower=True)
            tb.add_config(name=name + "output_clock_is_slower", generics=generics)

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
        # bundled tools/build.py, where PYTHONPATH is correctly set up.
        # pylint: disable=import-outside-toplevel
        # First party libraries
        from hdl_modules import get_hdl_modules

        projects = []
        modules = get_hdl_modules(names_include=[self.name, "common", "math"])
        part = "xc7z020clg400-1"
        generics = dict(width=16)

        projects.append(
            VivadoNetlistProject(
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
            VivadoNetlistProject(
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
