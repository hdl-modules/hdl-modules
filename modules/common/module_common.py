# --------------------------------------------------------------------------------------------------
# Copyright (c) Lukas Vik. All rights reserved.
#
# This file is part of the hdl-modules project, a collection of reusable, high-quality,
# peer-reviewed VHDL building blocks.
# https://hdl-modules.com
# https://github.com/hdl-modules/hdl-modules
# --------------------------------------------------------------------------------------------------

# Standard libraries
import itertools
from random import randrange

# Third party libraries
from tsfpga.examples.vivado.project import TsfpgaExampleVivadoNetlistProject
from tsfpga.module import BaseModule
from tsfpga.vivado.build_result_checker import (
    DspBlocks,
    EqualTo,
    Ffs,
    MaximumLogicLevel,
    Srls,
    TotalLuts,
)


class Module(BaseModule):
    def setup_vunit(self, vunit_proj, **kwargs):  # pylint: disable=unused-argument
        self._setup_clock_counter_tests(vunit_proj=vunit_proj)
        self._setup_clean_packet_dropper_tests(vunit_proj=vunit_proj)
        self._setup_debounce_tests(vunit_proj=vunit_proj)
        self._setup_handshake_merger_tests(vunit_proj=vunit_proj)
        self._setup_handshake_mux_tests(vunit_proj=vunit_proj)
        self._setup_handshake_pipeline_tests(vunit_proj=vunit_proj)
        self._setup_handshake_splitter_tests(vunit_proj=vunit_proj)
        self._setup_keep_remover_tests(vunit_proj=vunit_proj)
        self._setup_periodic_pulser_tests(vunit_proj=vunit_proj)
        self._setup_strobe_on_last_tests(vunit_proj=vunit_proj)
        self._setup_width_conversion_tests(vunit_proj=vunit_proj)

    def get_build_projects(self):
        projects = []
        part = "xc7z020clg400-1"

        # The 'hdl_modules' Python package is probably not on the PYTHONPATH in most scenarios where
        # this module is used. Hence we can not import at the top of this file.
        # This method is only called when running netlist builds in the hdl-modules repo from the
        # bundled tools/build_fpga.py, where PYTHONPATH is correctly set up.
        # pylint: disable=import-outside-toplevel
        # First party libraries
        from hdl_modules import get_hdl_modules

        modules = get_hdl_modules(names_include=[self.name, "math", "resync"])

        self._get_clock_counter_build_projects(part, modules, projects)
        self._get_frequency_conversion_build_projects(part, projects)
        self._get_handshake_pipeline_build_projects(part, projects)
        self._get_handshake_splitter_build_projects(part, projects)
        self._get_keep_remover_build_projects(part, projects)
        self._get_periodic_pulser_build_projects(part, modules, projects)
        self._get_strobe_on_last_build_projects(part, projects)
        self._get_width_conversion_build_projects(part, projects)

        return projects

    def _setup_clock_counter_tests(self, vunit_proj):
        tb = vunit_proj.library(self.library_name).test_bench("tb_clock_counter")
        self.add_vunit_config(
            tb, generics=dict(reference_clock_rate_mhz=250, target_clock_rate_mhz=50)
        )
        self.add_vunit_config(
            tb, generics=dict(reference_clock_rate_mhz=50, target_clock_rate_mhz=250)
        )

    def _setup_clean_packet_dropper_tests(self, vunit_proj):
        tb = vunit_proj.library(self.library_name).test_bench("tb_clean_packet_dropper")

        for data_width in [16, 32]:
            generics = dict(data_width=data_width)
            self.add_vunit_config(test=tb, generics=generics, set_random_seed=True)

    def _setup_debounce_tests(self, vunit_proj):
        tb = vunit_proj.library(self.library_name).test_bench("tb_debounce")

        for enable_iob in [False, True]:
            generics = dict(enable_iob=enable_iob)
            self.add_vunit_config(test=tb, generics=generics)

    def _setup_handshake_merger_tests(self, vunit_proj):
        tb = vunit_proj.library(self.library_name).test_bench("tb_handshake_merger")
        for test in tb.get_tests():
            stall_probability_percent = 0 if "test_full_throughput" in test.name else 20

            self.add_vunit_config(
                test=test,
                generics=dict(stall_probability_percent=stall_probability_percent),
                set_random_seed=True,
            )

    def _setup_handshake_mux_tests(self, vunit_proj):
        tb = vunit_proj.library(self.library_name).test_bench("tb_handshake_mux")
        for _ in range(2):
            self.add_vunit_config(test=tb, set_random_seed=True)

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

    def _setup_handshake_splitter_tests(self, vunit_proj):
        tb = vunit_proj.library(self.library_name).test_bench("tb_handshake_splitter")
        for test in tb.get_tests():
            stall_probability_percent = 0 if "test_full_throughput" in test.name else 20
            self.add_vunit_config(
                test=test,
                generics=dict(stall_probability_percent=stall_probability_percent),
                set_random_seed=True,
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

    def _setup_periodic_pulser_tests(self, vunit_proj):
        tb = vunit_proj.library(self.library_name).test_bench("tb_periodic_pulser")
        for period in [5, 15, 127]:
            self.add_vunit_config(tb, generics=dict(period=period, shift_register_length=8))

        # Create some random settings
        for _ in range(3):
            period = randrange(2, 5000)
            shift_register_length = randrange(1, 66)
            self.add_vunit_config(
                tb, generics=dict(period=period, shift_register_length=shift_register_length)
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
                for support_unaligned_packet_length in [True, False]:
                    generics["support_unaligned_packet_length"] = support_unaligned_packet_length
                    self.add_vunit_config(test, generics=generics, set_random_seed=True)
            else:
                self.add_vunit_config(test, generics=generics, set_random_seed=True)

        test = tb.get_tests("test_full_throughput")[0]
        self.add_vunit_config(
            test=test,
            name="input_16.output_8",
            generics=dict(
                input_width=16,
                output_width=8,
                enable_strobe=False,
                enable_last=True,
                enable_jitter=False,
            ),
            set_random_seed=True,
        )
        self.add_vunit_config(
            test=test,
            name="input_8.output_16",
            generics=dict(
                input_width=8,
                output_width=16,
                enable_strobe=False,
                enable_last=True,
                enable_jitter=False,
            ),
            set_random_seed=True,
        )

    def _get_clock_counter_build_projects(self, part, modules, projects):
        generics = dict(resolution_bits=24, max_relation_bits=6)
        projects.append(
            TsfpgaExampleVivadoNetlistProject(
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
            TsfpgaExampleVivadoNetlistProject(
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

    def _get_frequency_conversion_build_projects(self, part, projects):
        # No result checkers, but the entity contains a lot of assertions
        projects.append(
            TsfpgaExampleVivadoNetlistProject(
                name=f"{self.library_name}.test_frequency_conversion",
                modules=[self],
                part=part,
                top="test_frequency_conversion",
            )
        )

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
                TsfpgaExampleVivadoNetlistProject(
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

    def _get_handshake_splitter_build_projects(self, part, projects):
        def get_build_configurations():
            yield dict(num_interfaces=2), [TotalLuts(EqualTo(4)), Ffs(EqualTo(2))]
            yield dict(num_interfaces=4), [TotalLuts(EqualTo(9)), Ffs(EqualTo(4))]

        for generics, build_result_checkers in get_build_configurations():
            projects.append(
                TsfpgaExampleVivadoNetlistProject(
                    name=self.test_case_name(
                        name=f"{self.library_name}.handshake_splitter", generics=generics
                    ),
                    modules=[self],
                    part=part,
                    top="handshake_splitter",
                    generics=generics,
                    build_result_checkers=build_result_checkers,
                )
            )

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
                TsfpgaExampleVivadoNetlistProject(
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

    def _get_periodic_pulser_build_projects(self, part, modules, projects):
        # Returns: generics, checkers
        def generate_netlist_configurations():
            # A period of 33 fits within an srl and the succeeding ff
            # Note that an extra lut is needed for handling clock enable
            yield dict(period=33, shift_register_length=33), [
                TotalLuts(EqualTo(2)),
                Srls(EqualTo(1)),
                Ffs(EqualTo(1)),
            ]
            yield dict(period=33, shift_register_length=1), [
                TotalLuts(EqualTo(6)),
                Srls(EqualTo(0)),
                Ffs(EqualTo(6)),
            ]

            # A period of 37 cannot be broken up into multiple shift registers because it is
            # a prime. It will be put in multiple srls
            yield dict(period=37, shift_register_length=33), [
                TotalLuts(EqualTo(3)),
                Srls(EqualTo(2)),
                Ffs(EqualTo(1)),
            ]
            yield dict(period=37, shift_register_length=1), [
                TotalLuts(EqualTo(6)),
                Srls(EqualTo(0)),
                Ffs(EqualTo(6)),
            ]

            # 25 * 4
            yield dict(period=100, shift_register_length=33), [
                TotalLuts(EqualTo(3)),
                Srls(EqualTo(2)),
                Ffs(EqualTo(2)),
            ]
            yield dict(period=100, shift_register_length=1), [
                TotalLuts(EqualTo(8)),
                Srls(EqualTo(0)),
                Ffs(EqualTo(7)),
            ]

            # 25 * 5
            yield dict(period=125, shift_register_length=33), [
                TotalLuts(EqualTo(4)),
                Srls(EqualTo(2)),
                Ffs(EqualTo(2)),
            ]
            yield dict(period=125, shift_register_length=1), [
                TotalLuts(EqualTo(7)),
                Srls(EqualTo(0)),
                Ffs(EqualTo(7)),
            ]

            # A period of 127 cannot be broken up into multiple shift registers because it is
            # a prime. It will be put in multiple srls.
            yield dict(period=127, shift_register_length=33), [
                TotalLuts(EqualTo(5)),
                Srls(EqualTo(4)),
                Ffs(EqualTo(1)),
            ]
            yield dict(period=127, shift_register_length=1), [
                TotalLuts(EqualTo(8)),
                Srls(EqualTo(0)),
                Ffs(EqualTo(7)),
            ]

            # = 25 * 5 * 37
            yield dict(period=4625, shift_register_length=33), [
                TotalLuts(EqualTo(7)),
                Srls(EqualTo(4)),
                Ffs(EqualTo(3)),
            ]
            yield dict(period=4625, shift_register_length=1), [
                TotalLuts(EqualTo(2)),
                Srls(EqualTo(0)),
                Ffs(EqualTo(13)),
            ]

            # Would pulse once every second on a 311 MHz clock
            yield dict(period=311000000, shift_register_length=33), [
                TotalLuts(EqualTo(15)),
                Srls(EqualTo(4)),
                Ffs(EqualTo(15)),
            ]
            yield dict(period=311000000, shift_register_length=1), [
                TotalLuts(EqualTo(2)),
                Srls(EqualTo(0)),
                Ffs(EqualTo(29)),
            ]

        for generics, checkers in generate_netlist_configurations():
            projects.append(
                TsfpgaExampleVivadoNetlistProject(
                    name=self.test_case_name(f"{self.library_name}.periodic_pulser", generics),
                    modules=modules,
                    part=part,
                    top="periodic_pulser",
                    generics=generics,
                    build_result_checkers=checkers,
                )
            )

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
                TsfpgaExampleVivadoNetlistProject(
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

    def _get_width_conversion_build_projects(self, part, projects):
        modules = [self]

        # Downsizing in left array, upsizing on right.
        # Progressively adding more features from left to right.
        input_width = [32, 32, 32, 32] + [16, 16, 16, 16]
        output_width = [16, 16, 16, 16] + [32, 32, 32, 32]
        enable_last = [False, True, True, True] + [False, True, True, True]
        enable_strobe = [False, True, True, True] + [False, True, True, True]
        user_width = [0, 0, 0, 5] + [0, 0, 0, 5]
        support_unaligned_packet_length = [False, False, True, True] + [False, False, True, True]

        # Resource utilization increases when more features are added.
        total_luts = [20, 23, 27, 32] + [35, 40, 44, 54]
        ffs = [51, 59, 60, 70] + [51, 59, 62, 77]
        maximum_logic_level = [2, 2, 3, 3] + [2, 2, 2, 2]

        for idx in range(len(input_width)):  # pylint: disable=consider-using-enumerate
            generics = dict(
                input_width=input_width[idx],
                output_width=output_width[idx],
                enable_last=enable_last[idx],
                enable_strobe=enable_strobe[idx],
                user_width=user_width[idx],
                support_unaligned_packet_length=support_unaligned_packet_length[idx],
            )

            projects.append(
                TsfpgaExampleVivadoNetlistProject(
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
