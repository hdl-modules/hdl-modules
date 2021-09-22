# --------------------------------------------------------------------------------------------------
# Copyright (c) Lukas Vik. All rights reserved.
#
# This file is part of the tsfpga project.
# https://tsfpga.com
# https://gitlab.com/tsfpga/tsfpga
# --------------------------------------------------------------------------------------------------

from tsfpga.module import BaseModule
from tsfpga.vivado.project import VivadoNetlistProject
from tsfpga.vivado.build_result_checker import EqualTo, Ffs, Srls, TotalLuts
from examples.tsfpga_example_env import get_tsfpga_modules


class Module(BaseModule):
    def setup_vunit(self, vunit_proj, **kwargs):
        tb = vunit_proj.library(self.library_name).test_bench("tb_clock_counter")
        self.add_vunit_config(
            tb, generics=dict(reference_clock_rate_mhz=250, target_clock_rate_mhz=50)
        )
        self.add_vunit_config(
            tb, generics=dict(reference_clock_rate_mhz=50, target_clock_rate_mhz=250)
        )

        tb = vunit_proj.library(self.library_name).test_bench("tb_periodic_pulser")

        for period in [5, 15, 37, 300, 4032]:
            self.add_vunit_config(tb, generics=dict(period=period, shift_register_length=8))

        tb = vunit_proj.library(self.library_name).test_bench("tb_width_conversion")

        test = tb.get_tests("test_data")[0]
        for input_width in [8, 16, 32]:
            for output_width in [8, 16, 32]:
                if input_width == output_width:
                    continue

                for enable_strobe in [True, False]:
                    generics = dict(
                        input_width=input_width,
                        output_width=output_width,
                        enable_strobe=enable_strobe,
                    )

                    if enable_strobe and input_width < output_width:
                        generics["support_unaligned_burst_length"] = True

                    self.add_vunit_config(test, generics=generics)

        test = tb.get_tests("test_full_throughput")[0]
        test.add_config(
            name="input_16.output_8",
            generics=dict(input_width=16, output_width=8, enable_strobe=False, data_jitter=False),
        )
        test.add_config(
            name="input_8.output_16",
            generics=dict(input_width=8, output_width=16, enable_strobe=False, data_jitter=False),
        )

        for test in (
            vunit_proj.library(self.library_name).test_bench("tb_handshake_pipeline").get_tests()
        ):
            if "full_throughput" in test.name:
                for allow_poor_input_ready_timing in [False, True]:
                    generics = dict(
                        full_throughput=True,
                        allow_poor_input_ready_timing=allow_poor_input_ready_timing,
                    )
                    self.add_vunit_config(test=test, generics=generics)

            if "random_data" in test.name:
                for full_throughput in [False, True]:
                    for allow_poor_input_ready_timing in [False, True]:
                        generics = dict(
                            data_jitter=True,
                            full_throughput=full_throughput,
                            allow_poor_input_ready_timing=allow_poor_input_ready_timing,
                        )
                        self.add_vunit_config(test=test, generics=generics)

    def get_build_projects(self):
        projects = []
        part = "xc7z020clg400-1"
        self._get_handshake_pipeline_build_projects(part, projects)
        self._get_clock_counter_build_projects(part, projects)
        self._get_period_pulser_build_projects(part, projects)
        self._get_width_conversion_build_projects(part, projects)
        return projects

    def _get_handshake_pipeline_build_projects(self, part, projects):
        generics = dict(data_width=32)

        generics.update(full_throughput=True, allow_poor_input_ready_timing=True)
        projects.append(
            VivadoNetlistProject(
                name=self.test_case_name("handshake_pipeline", generics),
                modules=[self],
                part=part,
                top="handshake_pipeline",
                generics=generics,
                build_result_checkers=[
                    TotalLuts(EqualTo(1)),
                    Ffs(EqualTo(34)),
                ],
            )
        )

        # Full skid-aside buffer is quite large.
        generics.update(full_throughput=True, allow_poor_input_ready_timing=False)
        projects.append(
            VivadoNetlistProject(
                name=self.test_case_name("handshake_pipeline", generics),
                modules=[self],
                part=part,
                top="handshake_pipeline",
                generics=generics,
                build_result_checkers=[
                    TotalLuts(EqualTo(37)),
                    Ffs(EqualTo(70)),
                ],
            )
        )

        generics.update(full_throughput=False, allow_poor_input_ready_timing=True)
        projects.append(
            VivadoNetlistProject(
                name=self.test_case_name("handshake_pipeline", generics),
                modules=[self],
                part=part,
                top="handshake_pipeline",
                generics=generics,
                build_result_checkers=[
                    TotalLuts(EqualTo(2)),
                    Ffs(EqualTo(34)),
                ],
            )
        )

        generics.update(full_throughput=False, allow_poor_input_ready_timing=False)
        projects.append(
            VivadoNetlistProject(
                name=self.test_case_name("handshake_pipeline", generics),
                modules=[self],
                part=part,
                top="handshake_pipeline",
                generics=generics,
                build_result_checkers=[
                    TotalLuts(EqualTo(1)),
                    Ffs(EqualTo(35)),
                ],
            )
        )

    def _get_clock_counter_build_projects(self, part, projects):
        modules = get_tsfpga_modules(names_include=[self.name, "math", "resync"])

        generics = dict(resolution_bits=24, max_relation_bits=6)
        projects.append(
            VivadoNetlistProject(
                name=self.test_case_name(name=f"{self.name}.clock_counter", generics=generics),
                modules=modules,
                part=part,
                top="clock_counter",
                generics=generics,
                build_result_checkers=[
                    TotalLuts(EqualTo(84)),
                    Srls(EqualTo(5)),
                    Ffs(EqualTo(185)),
                ],
            )
        )

        generics = dict(resolution_bits=10, max_relation_bits=4)
        projects.append(
            VivadoNetlistProject(
                name=self.test_case_name(name=f"{self.name}.clock_counter", generics=generics),
                modules=modules,
                part=part,
                top="clock_counter",
                generics=generics,
                build_result_checkers=[
                    TotalLuts(EqualTo(38)),
                    Srls(EqualTo(2)),
                    Ffs(EqualTo(86)),
                ],
            )
        )

    def _get_period_pulser_build_projects(self, part, projects):
        modules = get_tsfpga_modules(names_include=[self.name, "math"])

        periods = [32, 37, 300, 63 * 64, 311000000]
        total_luts = [2, 7, 4, 5, 18]
        srls = [1, 0, 2, 3, 4]
        ffs = [1, 6, 2, 3, 15]

        for idx, period in enumerate(periods):
            generics = dict(period=period, shift_register_length=32)
            projects.append(
                VivadoNetlistProject(
                    name=self.test_case_name(f"{self.name}.periodic_pulser", generics),
                    modules=modules,
                    part=part,
                    top="periodic_pulser",
                    generics=generics,
                    build_result_checkers=[
                        TotalLuts(EqualTo(total_luts[idx])),
                        Srls(EqualTo(srls[idx])),
                        Ffs(EqualTo(ffs[idx])),
                    ],
                )
            )

    def _get_width_conversion_build_projects(self, part, projects):
        modules = [self]
        generic_configurations = [
            dict(input_width=32, output_width=16, enable_strobe=False),
            dict(input_width=16, output_width=32, enable_strobe=False),
            dict(
                input_width=32,
                output_width=16,
                enable_strobe=True,
                strobe_unit_width=8,
            ),
            dict(
                input_width=16,
                output_width=32,
                enable_strobe=True,
                support_unaligned_burst_length=True,
                strobe_unit_width=8,
            ),
        ]
        total_luts = [21, 36, 26, 46]
        ffs = [52, 52, 62, 65]

        for idx, generics in enumerate(generic_configurations):
            projects.append(
                VivadoNetlistProject(
                    name=self.test_case_name(
                        name=f"{self.name}.width_conversion", generics=generics
                    ),
                    modules=modules,
                    part=part,
                    top="width_conversion",
                    generics=generics,
                    build_result_checkers=[
                        TotalLuts(EqualTo(total_luts[idx])),
                        Ffs(EqualTo(ffs[idx])),
                    ],
                )
            )
