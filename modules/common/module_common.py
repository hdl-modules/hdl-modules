# --------------------------------------------------------------------------------------------------
# Copyright (c) Lukas Vik. All rights reserved.
#
# This file is part of the tsfpga project.
# https://tsfpga.com
# https://gitlab.com/tsfpga/tsfpga
# --------------------------------------------------------------------------------------------------

import itertools

from tsfpga.module import BaseModule, get_hdl_modules
from tsfpga.vivado.project import VivadoNetlistProject
from tsfpga.vivado.build_result_checker import (
    EqualTo,
    DspBlocks,
    Ffs,
    MaximumLogicLevel,
    Srls,
    TotalLuts,
)


class Module(BaseModule):
    def setup_vunit(self, vunit_proj, **kwargs):  # pylint: disable=unused-argument
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

        self._setup_handshake_pipeline_tests(vunit_proj=vunit_proj)
        self._setup_width_conversion_tests(vunit_proj=vunit_proj)
        self._setup_keep_remover_tests(vunit_proj=vunit_proj)
        self._setup_strobe_on_last_tests(vunit_proj=vunit_proj)

    def get_build_projects(self):
        projects = []
        part = "xc7z020clg400-1"

        self._get_handshake_pipeline_build_projects(part, projects)
        self._get_width_conversion_build_projects(part, projects)
        self._get_keep_remover_build_projects(part, projects)
        self._get_strobe_on_last_build_projects(part, projects)
        self._get_clock_counter_build_projects(part, projects)
        self._get_period_pulser_build_projects(part, projects)

        return projects

    def _setup_handshake_pipeline_tests(self, vunit_proj):
        tb = vunit_proj.library(self.library_name).test_bench("tb_handshake_pipeline")
        for test in tb.get_tests():
            for allow_poor_input_ready_timing in [False, True]:
                if "full_throughput" in test.name:
                    generics = dict(
                        full_throughput=True,
                        allow_poor_input_ready_timing=allow_poor_input_ready_timing,
                    )
                    self.add_vunit_config(test=test, generics=generics)

                if "random_data" in test.name:
                    for full_throughput in [False, True]:
                        generics = dict(
                            data_jitter=True,
                            full_throughput=full_throughput,
                            allow_poor_input_ready_timing=allow_poor_input_ready_timing,
                        )
                        self.add_vunit_config(test=test, generics=generics)

    def _get_handshake_pipeline_build_projects(self, part, projects):
        full_throughput = [True, True, False, False]
        allow_poor_input_ready_timing = [True, False, True, False]

        total_luts = [1, 41, 2, 1]
        ffs = [38, 78, 38, 39]
        maximum_logic_level = [2, 2, 2, 2]

        for idx in range(len(total_luts)):  # pylint: disable=consider-using-enumerate
            generics = dict(
                data_width=32,
                full_throughput=full_throughput[idx],
                allow_poor_input_ready_timing=allow_poor_input_ready_timing[idx],
            )

            projects.append(
                VivadoNetlistProject(
                    name=self.test_case_name(
                        name=f"{self.name}.handshake_pipeline", generics=generics
                    ),
                    modules=[self],
                    part=part,
                    top="handshake_pipeline",
                    generics=generics,
                    build_result_checkers=[
                        TotalLuts(EqualTo(total_luts[idx])),
                        Ffs(EqualTo(ffs[idx])),
                        MaximumLogicLevel(EqualTo(maximum_logic_level[idx])),
                    ],
                )
            )

    def _setup_width_conversion_tests(self, vunit_proj):
        tb = vunit_proj.library(self.library_name).test_bench("tb_width_conversion")

        test = tb.get_tests("test_data")[0]
        for input_width, output_width, enable_strobe, enable_last in itertools.product(
            [8, 16, 32], [8, 16, 32], [True, False], [True, False]
        ):
            if input_width == output_width:
                continue

            generics = dict(
                input_width=input_width,
                output_width=output_width,
                enable_strobe=enable_strobe,
                enable_last=enable_last,
            )

            if enable_strobe and enable_last:
                for support_unaligned_burst_length in [True, False]:
                    generics["support_unaligned_burst_length"] = support_unaligned_burst_length
                    self.add_vunit_config(test, generics=generics)
            else:
                self.add_vunit_config(test, generics=generics)

        test = tb.get_tests("test_full_throughput")[0]
        test.add_config(
            name="input_16.output_8",
            generics=dict(
                input_width=16,
                output_width=8,
                enable_strobe=False,
                enable_last=True,
                enable_jitter=False,
            ),
        )
        test.add_config(
            name="input_8.output_16",
            generics=dict(
                input_width=8,
                output_width=16,
                enable_strobe=False,
                enable_last=True,
                enable_jitter=False,
            ),
        )

    def _get_width_conversion_build_projects(self, part, projects):
        modules = [self]

        # Downconversion in left array, upconversion on right.
        # Progressively adding more features from left to right.
        input_width = [32, 32, 32] + [16, 16, 16]
        output_width = [16, 16, 16] + [32, 32, 32]
        enable_strobe = [False, True, True] + [False, True, True]
        enable_last = [False, True, True] + [False, True, True]
        support_unaligned_burst_length = [False, False, True] + [False, False, True]

        # Resource utilization increases when more features are added.
        total_luts = [20, 23, 29] + [35, 40, 44]
        ffs = [51, 59, 63] + [51, 59, 62]
        maximum_logic_level = [2, 2, 3] + [2, 2, 2]

        for idx in range(len(input_width)):  # pylint: disable=consider-using-enumerate
            generics = dict(
                input_width=input_width[idx],
                output_width=output_width[idx],
                enable_strobe=enable_strobe[idx],
                enable_last=enable_last[idx],
                support_unaligned_burst_length=support_unaligned_burst_length[idx],
            )

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
                        MaximumLogicLevel(EqualTo(maximum_logic_level[idx])),
                    ],
                )
            )

    def _setup_keep_remover_tests(self, vunit_proj):
        tb = vunit_proj.library(self.library_name).test_bench("tb_keep_remover")

        test = tb.test("test_data")
        for data_width in [8, 16, 32]:
            for strobe_unit_width in [8, 16]:
                if strobe_unit_width <= data_width:
                    generics = dict(data_width=data_width, strobe_unit_width=strobe_unit_width)
                    self.add_vunit_config(test=test, generics=generics)

        test = tb.test("test_full_throughput")
        self.add_vunit_config(
            test=test, generics=dict(data_width=16, strobe_unit_width=8, enable_jitter=False)
        )
        self.add_vunit_config(
            test=test, generics=dict(data_width=32, strobe_unit_width=16, enable_jitter=False)
        )

    def _get_keep_remover_build_projects(self, part, projects):
        modules = [self]
        generic_configurations = [
            dict(data_width=32, strobe_unit_width=16),
            dict(data_width=64, strobe_unit_width=8),
            dict(data_width=16 * 8, strobe_unit_width=4 * 8),
        ]
        total_luts = [98, 407, 415]
        ffs = [79, 175, 282]
        maximum_logic_level = [3, 6, 5]

        for idx, generics in enumerate(generic_configurations):
            projects.append(
                VivadoNetlistProject(
                    name=self.test_case_name(name=f"{self.name}.keep_remover", generics=generics),
                    modules=modules,
                    part=part,
                    top="keep_remover",
                    generics=generics,
                    build_result_checkers=[
                        TotalLuts(EqualTo(total_luts[idx])),
                        Ffs(EqualTo(ffs[idx])),
                        MaximumLogicLevel(EqualTo(maximum_logic_level[idx])),
                        DspBlocks(EqualTo(0)),
                    ],
                )
            )

    def _setup_strobe_on_last_tests(self, vunit_proj):
        tb = vunit_proj.library(self.library_name).test_bench("tb_strobe_on_last")

        for data_width in [8, 16, 32]:
            for test_full_throughput in [False, True]:
                generics = dict(data_width=data_width, test_full_throughput=test_full_throughput)
                self.add_vunit_config(test=tb, generics=generics)

    def _get_strobe_on_last_build_projects(self, part, projects):
        modules = [self]
        generic_configurations = [
            dict(data_width=8),
            dict(data_width=32),
            dict(data_width=64),
        ]
        total_luts = [7, 8, 9]
        ffs = [12, 39, 75]
        maximum_logic_level = [3, 3, 3]

        for idx, generics in enumerate(generic_configurations):
            projects.append(
                VivadoNetlistProject(
                    name=self.test_case_name(name=f"{self.name}.strobe_on_last", generics=generics),
                    modules=modules,
                    part=part,
                    top="strobe_on_last",
                    generics=generics,
                    build_result_checkers=[
                        TotalLuts(EqualTo(total_luts[idx])),
                        Ffs(EqualTo(ffs[idx])),
                        MaximumLogicLevel(EqualTo(maximum_logic_level[idx])),
                    ],
                )
            )

    def _get_clock_counter_build_projects(self, part, projects):
        modules = get_hdl_modules(names_include=[self.name, "math", "resync"])

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
        modules = get_hdl_modules(names_include=[self.name, "math"])

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
