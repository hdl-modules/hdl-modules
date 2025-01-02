# --------------------------------------------------------------------------------------------------
# Copyright (c) Lukas Vik. All rights reserved.
#
# This file is part of the hdl-modules project, a collection of reusable, high-quality,
# peer-reviewed VHDL building blocks.
# https://hdl-modules.com
# https://github.com/hdl-modules/hdl-modules
# --------------------------------------------------------------------------------------------------

# Standard libraries
from typing import Optional

# Third party libraries
from tsfpga.examples.vivado.project import TsfpgaExampleVivadoNetlistProject
from tsfpga.module import BaseModule
from tsfpga.vivado.build_result_checker import (
    EqualTo,
    Ffs,
    GreaterThan,
    LutRams,
    MaximumLogicLevel,
    TotalLuts,
)


class Module(BaseModule):

    def setup_vunit(self, vunit_proj, **kwargs):  # pylint: disable=unused-argument
        self.setup_resync_counter_tests(vunit_proj=vunit_proj)
        self.setup_resync_cycles_tests(vunit_proj=vunit_proj)
        self.setup_resync_pulse_tests(vunit_proj=vunit_proj)
        self.setup_resync_slv_level_tests(vunit_proj=vunit_proj)
        self.setup_resync_twophase_tests(vunit_proj=vunit_proj)
        self.setup_resync_twophase_handshake_tests(vunit_proj=vunit_proj)

    def setup_resync_counter_tests(self, vunit_proj):
        tb = vunit_proj.library(self.library_name).test_bench("tb_resync_counter")
        for pipeline_output in [True, False]:
            generics = dict(pipeline_output=pipeline_output)
            self.add_vunit_config(tb, generics=generics)

    def setup_resync_cycles_tests(self, vunit_proj):
        tb = vunit_proj.library(self.library_name).test_bench("tb_resync_cycles")
        for active_high in [True, False]:
            generics = dict(active_high=active_high, output_clock_is_faster=True)
            self.add_vunit_config(tb, generics=generics)

            generics = dict(active_high=active_high)
            self.add_vunit_config(tb, generics=generics)

            generics = dict(active_high=active_high, output_clock_is_slower=True)
            self.add_vunit_config(tb, generics=generics)

    def setup_resync_pulse_tests(self, vunit_proj):
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

    def setup_resync_slv_level_tests(self, vunit_proj):
        tb = vunit_proj.library(self.library_name).test_bench("tb_resync_slv_level")
        for output_clock_is_faster in [True, False]:
            for enable_input_register in [True, False]:
                generics = dict(
                    output_clock_is_faster=output_clock_is_faster,
                    enable_input_register=enable_input_register,
                )
                self.add_vunit_config(tb, generics=generics)

    def setup_resync_twophase_tests(self, vunit_proj):
        tb = vunit_proj.library(self.library_name).test_bench("tb_resync_twophase")
        for mode in [
            "output_clock_is_greatly_faster",
            "output_clock_is_mildly_faster",
            "clocks_are_same",
            "output_clock_is_mildly_slower",
            "output_clock_is_greatly_slower",
        ]:
            for enable_lutram in [False, True]:
                generics = {mode: True, "enable_lutram": enable_lutram}

                if enable_lutram:
                    for enable_output_register in [False, True]:
                        generics["enable_output_register"] = enable_output_register
                        self.add_vunit_config(tb, generics=generics)
                else:
                    self.add_vunit_config(tb, generics=generics)

    def setup_resync_twophase_handshake_tests(self, vunit_proj):
        tb = vunit_proj.library(self.library_name).test_bench("tb_resync_twophase_handshake")
        for mode in [
            "result_clock_is_greatly_faster",
            "result_clock_is_mildly_faster",
            "clocks_are_same",
            "result_clock_is_mildly_slower",
            "result_clock_is_greatly_slower",
        ]:
            generics = {mode: True}

            for test in tb.get_tests():
                if test.name == "test_random_data":
                    for data_width in [8, 16]:
                        generics["data_width"] = data_width
                        self.add_vunit_config(test, generics=generics, set_random_seed=True)

                elif test.name == "test_count_sampling_period":
                    generics["stall_probability_percent"] = 0
                    self.add_vunit_config(test, generics=generics, set_random_seed=True)

                elif test.name == "test_init_state":
                    self.add_vunit_config(test, generics=generics, set_random_seed=0)

                else:
                    raise RuntimeError(f"Unknown test: {test.name}")

    def get_build_projects(self):
        # Standard libraries
        # pylint: disable=import-outside-toplevel
        from dataclasses import dataclass

        # First party libraries
        # The 'hdl_modules' Python package is probably not on the PYTHONPATH in most scenarios where
        # this module is used. Hence we can not import at the top of this file.
        # This method is only called when running netlist builds in the hdl-modules repo from the
        # bundled tools/build_fpga.py, where PYTHONPATH is correctly set up.
        # pylint: disable=import-outside-toplevel
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

        @dataclass
        class Config:
            name: str
            lut: int
            ff: int
            logic: int
            width: Optional[int] = None
            data_width: Optional[int] = None
            counter_width: Optional[int] = None

        def add_config(config: Config):
            if config.width is not None:
                generics = dict(width=config.width)
            elif config.data_width is not None:
                generics = dict(data_width=config.data_width)
            elif config.counter_width is not None:
                generics = dict(counter_width=config.counter_width)
            else:
                raise ValueError("Invalid config")

            build_result_checkers = [
                TotalLuts(EqualTo(config.lut)),
                Ffs(EqualTo(config.ff)),
                MaximumLogicLevel(EqualTo(config.logic)),
            ]
            if "lutram" in config.name:
                build_result_checkers.append(LutRams(GreaterThan(0)))

            projects.append(
                TsfpgaExampleVivadoNetlistProject(
                    name=self.test_case_name(f"{self.library_name}.{config.name}", generics),
                    modules=modules,
                    part=part,
                    top=config.name,
                    generics=generics,
                    build_result_checkers=build_result_checkers,
                )
            )

        add_config(Config(name="resync_cycles", counter_width=8, lut=26, ff=41, logic=5))
        add_config(Config(name="resync_cycles", counter_width=16, lut=31, ff=81, logic=7))
        add_config(Config(name="resync_cycles", counter_width=24, lut=45, ff=121, logic=9))
        add_config(Config(name="resync_cycles", counter_width=32, lut=69, ff=161, logic=9))
        add_config(Config(name="resync_cycles", counter_width=64, lut=140, ff=321, logic=17))

        add_config(Config(name="resync_counter", width=8, lut=11, ff=24, logic=3))
        add_config(Config(name="resync_counter", width=16, lut=23, ff=48, logic=4))
        add_config(Config(name="resync_counter", width=24, lut=35, ff=72, logic=6))
        add_config(Config(name="resync_counter", width=32, lut=59, ff=96, logic=3))
        add_config(Config(name="resync_counter", width=64, lut=123, ff=192, logic=4))

        for width in [8, 16, 24, 32, 64]:
            add_config(
                Config(name="resync_twophase", width=width, lut=3, ff=2 * width + 6, logic=2)
            )

        add_config(Config(name="resync_twophase_lutram", width=8, lut=10, ff=6, logic=2))
        add_config(Config(name="resync_twophase_lutram", width=16, lut=14, ff=6, logic=2))
        add_config(Config(name="resync_twophase_lutram", width=24, lut=18, ff=6, logic=2))
        add_config(Config(name="resync_twophase_lutram", width=32, lut=26, ff=6, logic=2))
        add_config(Config(name="resync_twophase_lutram", width=64, lut=46, ff=6, logic=2))

        for width in [8, 16, 24, 32, 64]:
            add_config(
                Config(
                    name="resync_twophase_handshake",
                    data_width=width,
                    lut=5,
                    ff=2 * width + 8,
                    logic=2,
                )
            )

        for data_width in [32, 64]:
            add_config(
                Config(
                    name="resync_rarely_valid",
                    data_width=data_width,
                    lut=2,
                    ff=2 * data_width + 5,
                    logic=2,
                )
            )

        add_config(Config(name="resync_rarely_valid_lutram", data_width=32, lut=26, ff=4, logic=2))
        add_config(Config(name="resync_rarely_valid_lutram", data_width=64, lut=46, ff=4, logic=2))

        return projects
