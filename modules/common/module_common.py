# --------------------------------------------------------------------------------------------------
# Copyright (c) Lukas Vik. All rights reserved.
#
# This file is part of the hdl_modules project.
# https://hdl-modules.com
# https://gitlab.com/tsfpga/hdl_modules
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
        self._get_periodic_pulser_build_projects(part, projects)
        self._get_frequency_conversion_build_projects(part, projects)

        return projects

    def _setup_handshake_pipeline_tests(self, vunit_proj):
        tb = vunit_proj.library(self.library_name).test_bench("tb_handshake_pipeline")
        for test in tb.get_tests():
            for (
                pipeline_control_signals,
                pipeline_data_signals,
                full_throughput,
            ) in itertools.product([False, True], [False, True], [False, True]):
                # Implementation does not support full throughput
                # when only pipelining control signals
                if full_throughput and pipeline_control_signals and (not pipeline_data_signals):
                    continue

                # The full throughput test case should only run  with the full_throughput
                # generic set
                if "full_throughput" in test.name and (not full_throughput):
                    continue

                data_jitter = "full_throughput" not in test.name

                generics = dict(
                    data_jitter=data_jitter,
                    full_throughput=full_throughput,
                    pipeline_control_signals=pipeline_control_signals,
                    pipeline_data_signals=pipeline_data_signals,
                )
                self.add_vunit_config(test=test, generics=generics)

    def _get_handshake_pipeline_build_projects(self, part, projects):
        # All sets of generics are supported except full throughput with pipeline of
        # control signals but not data signals
        full_throughput = [True, True, True, False, False, False, False]
        pipeline_control_signals = [True, False, False, True, True, False, False]
        pipeline_data_signals = [True, True, False, True, False, True, False]

        total_luts = [41, 1, 0, 1, 2, 2, 0]
        ffs = [78, 38, 0, 39, 3, 38, 0]
        maximum_logic_level = [2, 2, 0, 2, 2, 2, 0]

        for idx in range(len(total_luts)):  # pylint: disable=consider-using-enumerate
            generics = dict(
                data_width=32,
                full_throughput=full_throughput[idx],
                pipeline_control_signals=pipeline_control_signals[idx],
                pipeline_data_signals=pipeline_data_signals[idx],
            )

            projects.append(
                VivadoNetlistProject(
                    name=self.test_case_name(
                        name=f"{self.library_name}.handshake_pipeline", generics=generics
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
                        name=f"{self.library_name}.width_conversion", generics=generics
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
                if strobe_unit_width > data_width:
                    continue

                generics = dict(data_width=data_width, strobe_unit_width=strobe_unit_width)
                self.add_vunit_config(test=test, generics=generics, set_random_seed=True)

        test = tb.test("test_full_throughput")
        for data_width, strobe_unit_width in [(16, 8), (32, 16)]:
            generics = dict(
                data_width=data_width, strobe_unit_width=strobe_unit_width, enable_jitter=False
            )
            self.add_vunit_config(test=test, generics=generics, set_random_seed=True)

    def _get_keep_remover_build_projects(self, part, projects):
        modules = [self]
        generic_configurations = [
            dict(data_width=32, strobe_unit_width=16),
            dict(data_width=64, strobe_unit_width=8),
            dict(data_width=16 * 8, strobe_unit_width=4 * 8),
        ]
        total_luts = [88, 410, 414]
        ffs = [79, 175, 282]
        maximum_logic_level = [3, 6, 5]

        for idx, generics in enumerate(generic_configurations):
            projects.append(
                VivadoNetlistProject(
                    name=self.test_case_name(
                        name=f"{self.library_name}.keep_remover", generics=generics
                    ),
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

                # The "full throughput" test is very static, so test only with one seed.
                # The regular test though should be tested more exhaustively.
                num_tests = 1 if test_full_throughput else 5
                for _ in range(num_tests):
                    self.add_vunit_config(test=tb, generics=generics, set_random_seed=True)

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
                    name=self.test_case_name(
                        name=f"{self.library_name}.strobe_on_last", generics=generics
                    ),
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
                name=self.test_case_name(
                    name=f"{self.library_name}.clock_counter", generics=generics
                ),
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
                name=self.test_case_name(
                    name=f"{self.library_name}.clock_counter", generics=generics
                ),
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

    def _get_periodic_pulser_build_projects(self, part, projects):
        modules = get_hdl_modules(names_include=[self.name, "math"])

        build_settings = [
            {
                "period": 33,
                "shift_register_lengths": (33, 1),
                "sizes": {
                    # A period of 33 fits within an srl and the succeeding ff
                    # Note that an extra lut is needed for handling clock enable
                    "33": {"total_luts": 2, "srls": 1, "ffs": 1},
                    "1": {"total_luts": 6, "srls": 0, "ffs": 6},
                },
            },
            {
                # A period of 37 cannot be broken up into multiple shift registers because it is
                # a prime. It doesn't fit in one srl, so a counter will be created.
                "period": 37,
                "shift_register_lengths": (33, 1),
                "sizes": {
                    "33": {"total_luts": 6, "srls": 0, "ffs": 6},
                    "1": {"total_luts": 6, "srls": 0, "ffs": 6},
                },
            },
            {
                "period": 100,  # = 25 * 4
                "shift_register_lengths": (33, 1),
                "sizes": {
                    "33": {"total_luts": 3, "srls": 2, "ffs": 2},
                    "1": {"total_luts": 7, "srls": 0, "ffs": 7},
                },
            },
            {
                "period": 125,  # = 25 * 5
                "shift_register_lengths": (33, 1),
                "sizes": {
                    "33": {"total_luts": 4, "srls": 2, "ffs": 2},
                    "1": {"total_luts": 7, "srls": 0, "ffs": 7},
                },
            },
            {
                "period": 4625,  # = 25 * 5 * 37
                "shift_register_lengths": (33, 1),
                "sizes": {
                    "33": {"total_luts": 9, "srls": 2, "ffs": 8},
                    "1": {"total_luts": 4, "srls": 0, "ffs": 13},
                },
            },
            {
                "period": 311000000,  # Would pulse once every second on a 311 MHz clock
                "shift_register_lengths": (33, 1),
                "sizes": {
                    "33": {"total_luts": 17, "srls": 4, "ffs": 15},
                    "1": {"total_luts": 7, "srls": 0, "ffs": 29},
                },
            },
        ]

        for build_setting in build_settings:
            for shift_register_length in build_setting["shift_register_lengths"]:
                generics = dict(
                    period=build_setting["period"],
                    shift_register_length=shift_register_length,
                )
                projects.append(
                    VivadoNetlistProject(
                        name=self.test_case_name(f"{self.library_name}.periodic_pulser", generics),
                        modules=modules,
                        part=part,
                        top="periodic_pulser",
                        generics=generics,
                        build_result_checkers=[
                            TotalLuts(
                                EqualTo(
                                    build_setting["sizes"][str(shift_register_length)]["total_luts"]
                                )
                            ),
                            Srls(
                                EqualTo(build_setting["sizes"][str(shift_register_length)]["srls"])
                            ),
                            Ffs(EqualTo(build_setting["sizes"][str(shift_register_length)]["ffs"])),
                        ],
                    )
                )

    def _get_frequency_conversion_build_projects(self, part, projects):
        # No result checkers, but the entity contains a lot of assertions
        projects.append(
            VivadoNetlistProject(
                name=f"{self.library_name}.test_frequency_conversion",
                modules=[self],
                part=part,
                top="test_frequency_conversion",
            )
        )
