# --------------------------------------------------------------------------------------------------
# Copyright (c) Lukas Vik. All rights reserved.
#
# This file is part of the hdl-modules project, a collection of reusable, high-quality,
# peer-reviewed VHDL building blocks.
# https://hdl-modules.com
# https://github.com/hdl-modules/hdl-modules
# --------------------------------------------------------------------------------------------------

# Standard libraries
from dataclasses import dataclass
from typing import Optional

# Third party libraries
from tsfpga.examples.vivado.project import TsfpgaExampleVivadoNetlistProject
from tsfpga.module import BaseModule
from tsfpga.vivado.build_result_checker import EqualTo, Ffs, MaximumLogicLevel, TotalLuts


class Module(BaseModule):
    def setup_vunit(self, vunit_proj, **kwargs):  # pylint: disable=unused-argument
        tb = vunit_proj.library(self.library_name).test_bench("tb_resync_slv_level")
        for output_clock_is_faster in [True, False]:
            for enable_input_register in [True, False]:
                generics = dict(
                    output_clock_is_faster=output_clock_is_faster,
                    enable_input_register=enable_input_register,
                )
                self.add_vunit_config(tb, generics=generics)

        tb = vunit_proj.library(self.library_name).test_bench("tb_resync_slv_level_coherent")
        for output_clock_is_faster in [True, False]:
            generics = dict(output_clock_is_faster=output_clock_is_faster)
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
            generics = dict(pipeline_output=pipeline_output)
            self.add_vunit_config(tb, generics=generics)

        tb = vunit_proj.library(self.library_name).test_bench("tb_resync_cycles")
        for active_high in [True, False]:
            generics = dict(active_high=active_high, output_clock_is_faster=True)
            self.add_vunit_config(tb, generics=generics)

            generics = dict(active_high=active_high)
            self.add_vunit_config(tb, generics=generics)

            generics = dict(active_high=active_high, output_clock_is_slower=True)
            self.add_vunit_config(tb, generics=generics)

        tb = vunit_proj.library(self.library_name).test_bench("tb_resync_slv_handshake")
        for input_clock_is_faster in [True, False]:
            for result_clock_is_faster in [True, False]:
                if input_clock_is_faster and result_clock_is_faster:
                    continue

                generics = dict(
                    input_clock_is_faster=input_clock_is_faster,
                    result_clock_is_faster=result_clock_is_faster,
                )

                test = tb.get_tests("test_random_data")[0]
                for data_width in [8, 16]:
                    generics["data_width"] = data_width
                    self.add_vunit_config(test, generics=generics, set_random_seed=True)
                    self.add_vunit_config(test, generics=generics, set_random_seed=1337)

                test = tb.get_tests("test_count_sampling_period")[0]
                generics["stall_probability_percent"] = 0
                self.add_vunit_config(test, generics=generics, set_random_seed=True)

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

        generics = dict(data_width=32)
        projects.append(
            TsfpgaExampleVivadoNetlistProject(
                name=self.test_case_name(
                    f"{self.library_name}.resync_slv_handshake_wrapper", generics=generics
                ),
                modules=modules,
                part=part,
                top="resync_slv_handshake_wrapper",
                generics=generics,
                build_result_checkers=[
                    TotalLuts(EqualTo(3)),
                    Ffs(EqualTo(70)),
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

            projects.append(
                TsfpgaExampleVivadoNetlistProject(
                    name=self.test_case_name(f"{self.library_name}.{config.name}", generics),
                    modules=modules,
                    part=part,
                    top=config.name,
                    generics=generics,
                    build_result_checkers=[
                        TotalLuts(EqualTo(config.lut)),
                        Ffs(EqualTo(config.ff)),
                        MaximumLogicLevel(EqualTo(config.logic)),
                    ],
                )
            )

        add_config(Config(name="resync_cycles", lut=26, ff=41, logic=5, counter_width=8))
        add_config(Config(name="resync_cycles", lut=31, ff=81, logic=7, counter_width=16))
        add_config(Config(name="resync_cycles", lut=69, ff=161, logic=9, counter_width=32))

        add_config(Config(name="resync_counter", lut=11, ff=24, logic=3, width=8))
        add_config(Config(name="resync_counter", lut=23, ff=48, logic=4, width=16))
        add_config(Config(name="resync_counter", lut=59, ff=96, logic=3, width=32))

        for width in [8, 16, 24, 32]:
            add_config(
                Config(
                    name="resync_slv_level_coherent", lut=3, ff=2 * width + 6, logic=2, width=width
                )
            )

        add_config(Config(name="resync_slv_handshake", lut=6, ff=26, logic=2, data_width=8))
        add_config(Config(name="resync_slv_handshake", lut=6, ff=42, logic=2, data_width=16))
        add_config(Config(name="resync_slv_handshake", lut=6, ff=74, logic=2, data_width=32))

        return projects
