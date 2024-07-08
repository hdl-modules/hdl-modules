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
from tsfpga.vivado.build_result_checker import (
    EqualTo,
    Ffs,
    MaximumLogicLevel,
    Ramb18,
    Ramb36,
    TotalLuts,
)


class Module(BaseModule):
    def setup_vunit(self, vunit_proj, **kwargs):  # pylint: disable=unused-argument
        library = vunit_proj.library(self.library_name)

        for test in library.test_bench("tb_asynchronous_fifo").get_tests():
            for enable_output_register in [False, True]:
                for read_clock_is_faster in [False, True]:
                    original_generics = dict(
                        read_clock_is_faster=read_clock_is_faster,
                        enable_output_register=enable_output_register,
                    )

                    for generics in self.generate_common_fifo_test_generics(
                        test.name, original_generics
                    ):
                        self.add_vunit_config(test, generics=generics, set_random_seed=True)

        for test in library.test_bench("tb_fifo").get_tests():
            for enable_output_register in [False, True]:
                original_generics = dict(enable_output_register=enable_output_register)
                for generics in self.generate_common_fifo_test_generics(
                    test.name, original_generics
                ):
                    # Output register is supported in all settings except for peek_mode
                    if enable_output_register and "peek_mode" in test.name:
                        continue

                    self.add_vunit_config(test, generics=generics, set_random_seed=True)

    @staticmethod
    def generate_common_fifo_test_generics(test_name, original_generics=None):
        generics = original_generics if original_generics is not None else {}

        if "write_faster_than_read" in test_name:
            generics.update(read_stall_probability_percent=90)
            generics.update(enable_last=True)

        if "read_faster_than_write" in test_name:
            generics.update(write_stall_probability_percent=90)

        if "packet_mode" in test_name:
            generics.update(enable_last=True, enable_packet_mode=True)

        if "drop_packet" in test_name:
            generics.update(enable_last=True, enable_drop_packet=True)

        if "peek_mode" in test_name:
            generics.update(enable_last=True, enable_peek_mode=True)

        if "init_state" in test_name or "almost" in test_name:
            # Note that
            #   almost_full_level = depth, or
            #   almost_empty_level = 0
            # result in alternative ways of calculating almost full/empty.
            depth = 32 + generics["enable_output_register"]

            for almost_full_level, almost_empty_level in [(depth, depth // 2), (depth // 2, 0)]:
                generics.update(
                    depth=depth,
                    almost_full_level=almost_full_level,
                    almost_empty_level=almost_empty_level,
                )

                yield generics

        elif "drop_packet_mode_read_level_should_be_zero" in test_name:
            # Do not need to test this in many configurations
            depth = 16 + generics["enable_output_register"]
            generics.update(depth=depth)
            yield generics

        else:
            # For most test, generate configuration with two different depths
            for depth in [16, 64]:
                depth = depth + generics["enable_output_register"]
                generics.update(depth=depth)

                yield generics

    def get_build_projects(self):
        # The 'hdl_modules' Python package is probably not on the PYTHONPATH in most scenarios where
        # this module is used. Hence we can not import at the top of this file.
        # This method is only called when running netlist builds in the hdl-modules repo from the
        # bundled tools/build_fpga.py, where PYTHONPATH is correctly set up.
        # pylint: disable=import-outside-toplevel
        # First party libraries
        from hdl_modules import get_hdl_modules

        projects = []
        modules = get_hdl_modules(names_include=[self.name, "common", "math", "resync"])
        part = "xc7z020clg400-1"

        self._setup_fifo_build_projects(projects, modules, part)
        self._setup_asynchronous_fifo_build_projects(projects, modules, part)

        return projects

    def _setup_fifo_build_projects(self, projects, modules, part):
        # Use a wrapper as top level, which only routes the "barebone" ports, resulting in
        # a minimal FIFO.
        generics = dict(
            use_asynchronous_fifo=False, width=32, depth=1024, enable_output_register=False
        )
        projects.append(
            TsfpgaExampleVivadoNetlistProject(
                name=self.test_case_name(f"{self.library_name}.fifo.minimal", generics),
                modules=modules,
                part=part,
                top="fifo_netlist_build_wrapper",
                generics=generics,
                build_result_checkers=[
                    TotalLuts(EqualTo(14)),
                    Ffs(EqualTo(24)),
                    Ramb36(EqualTo(1)),
                    Ramb18(EqualTo(0)),
                    MaximumLogicLevel(EqualTo(6)),
                ],
            )
        )

        # Use a wrapper as top level, which only routes the "barebone" ports, resulting in
        # a minimal FIFO. This mode also adds an output register.
        generics.update(depth=generics["depth"] + 1, enable_output_register=True)
        projects.append(
            TsfpgaExampleVivadoNetlistProject(
                name=self.test_case_name(
                    f"{self.library_name}.fifo.minimal_with_output_register", generics
                ),
                modules=modules,
                part=part,
                top="fifo_netlist_build_wrapper",
                generics=generics,
                build_result_checkers=[
                    TotalLuts(EqualTo(15)),
                    Ffs(EqualTo(25)),
                    Ramb36(EqualTo(1)),
                    Ramb18(EqualTo(0)),
                    MaximumLogicLevel(EqualTo(6)),
                ],
            )
        )

        # A FIFO with level counter port and non-default almost_full_level, which
        # increases resource utilization.
        generics = dict(width=32, depth=1024, almost_full_level=800)
        projects.append(
            TsfpgaExampleVivadoNetlistProject(
                name=self.test_case_name(f"{self.library_name}.fifo.with_levels", generics),
                modules=modules,
                part=part,
                top="fifo",
                generics=generics,
                build_result_checkers=[
                    TotalLuts(EqualTo(27)),
                    Ffs(EqualTo(35)),
                    Ramb36(EqualTo(1)),
                    Ramb18(EqualTo(0)),
                    MaximumLogicLevel(EqualTo(6)),
                ],
            )
        )

        # Enabling last should not increase resource utilization
        generics.update(enable_last=True)
        projects.append(
            TsfpgaExampleVivadoNetlistProject(
                name=self.test_case_name(f"{self.library_name}.fifo.with_last", generics),
                modules=modules,
                part=part,
                top="fifo",
                generics=generics,
                build_result_checkers=[
                    TotalLuts(EqualTo(27)),
                    Ffs(EqualTo(35)),
                    Ramb36(EqualTo(1)),
                    Ramb18(EqualTo(0)),
                    MaximumLogicLevel(EqualTo(6)),
                ],
            )
        )

        # Enabling packet mode increases resource utilization a bit, since an extra counter
        # and some further logic is introduced.
        generics.update(enable_packet_mode=True)
        projects.append(
            TsfpgaExampleVivadoNetlistProject(
                name=self.test_case_name(f"{self.library_name}.fifo.with_packet_mode", generics),
                modules=modules,
                part=part,
                top="fifo",
                generics=generics,
                build_result_checkers=[
                    TotalLuts(EqualTo(40)),
                    Ffs(EqualTo(47)),
                    Ramb36(EqualTo(1)),
                    Ramb18(EqualTo(0)),
                    MaximumLogicLevel(EqualTo(6)),
                ],
            )
        )

        # Enabling the output register increases logic, but the register itself
        # should be packed into the RAM output register
        generics.update(depth=generics["depth"] + 1, enable_output_register=True)
        projects.append(
            TsfpgaExampleVivadoNetlistProject(
                name=self.test_case_name(
                    f"{self.library_name}.fifo.with_packet_mode_and_output_register", generics
                ),
                modules=modules,
                part=part,
                top="fifo",
                generics=generics,
                build_result_checkers=[
                    TotalLuts(EqualTo(45)),
                    Ffs(EqualTo(50)),
                    Ramb36(EqualTo(1)),
                    Ramb18(EqualTo(0)),
                    MaximumLogicLevel(EqualTo(9)),
                ],
            )
        )

        # Enabling drop packet support increases utilization compared to only packet mode,
        # since an extra counter and some further logic is introduced.
        generics.update(
            depth=generics["depth"] - 1, enable_output_register=False, enable_drop_packet=True
        )
        projects.append(
            TsfpgaExampleVivadoNetlistProject(
                name=self.test_case_name(f"{self.library_name}.fifo.with_drop_packet", generics),
                modules=modules,
                part=part,
                top="fifo",
                generics=generics,
                build_result_checkers=[
                    TotalLuts(EqualTo(45)),
                    Ffs(EqualTo(58)),
                    Ramb36(EqualTo(1)),
                    Ramb18(EqualTo(0)),
                    MaximumLogicLevel(EqualTo(6)),
                ],
            )
        )

        # Enabling peek mode support increases utilization compared to only packet mode,
        # since an extra address pointer and some further muxing is introduced.
        generics.update(enable_drop_packet=False, enable_peek_mode=True)
        projects.append(
            TsfpgaExampleVivadoNetlistProject(
                name=self.test_case_name(f"{self.library_name}.fifo.with_peek_mode", generics),
                modules=modules,
                part=part,
                top="fifo",
                generics=generics,
                build_result_checkers=[
                    TotalLuts(EqualTo(58)),
                    Ffs(EqualTo(58)),
                    Ramb36(EqualTo(1)),
                    Ramb18(EqualTo(0)),
                    MaximumLogicLevel(EqualTo(6)),
                ],
            )
        )

        # Use a wrapper as top level, which only routes the "barebone" ports, resulting in
        # a minimal FIFO.
        generics = dict(
            use_asynchronous_fifo=False,
            width=8,
            depth=32,
            enable_output_register=False,
        )
        projects.append(
            TsfpgaExampleVivadoNetlistProject(
                name=self.test_case_name(f"{self.library_name}.fifo.lutram_minimal", generics),
                modules=modules,
                part=part,
                top="fifo_netlist_build_wrapper",
                generics=generics,
                build_result_checkers=[
                    TotalLuts(EqualTo(32)),
                    Ffs(EqualTo(22)),
                    Ramb36(EqualTo(0)),
                    Ramb18(EqualTo(0)),
                    MaximumLogicLevel(EqualTo(3)),
                ],
            )
        )

    def _setup_asynchronous_fifo_build_projects(self, projects, modules, part):
        # Standard libraries
        # pylint: disable=import-outside-toplevel
        from dataclasses import dataclass

        @dataclass
        class ResyncConfig:
            width: int
            lut: int
            ff: int
            logic: int

        def add_resync_config(config: ResyncConfig):
            # A shallow FIFO, which commonly would be used to resync a coherent bit vector.
            # Note that this uses the minimal top level wrapper so that only the barebone features
            # are available.
            generics = dict(
                use_asynchronous_fifo=True,
                width=config.width,
                depth=8,
                enable_output_register=False,
            )

            projects.append(
                TsfpgaExampleVivadoNetlistProject(
                    name=self.test_case_name(
                        f"{self.library_name}.asynchronous_fifo.resync_fifo", generics
                    ),
                    modules=modules,
                    part=part,
                    top="fifo_netlist_build_wrapper",
                    generics=generics,
                    build_result_checkers=[
                        TotalLuts(EqualTo(config.lut)),
                        Ffs(EqualTo(config.ff)),
                        MaximumLogicLevel(EqualTo(config.logic)),
                        Ramb36(EqualTo(0)),
                        Ramb18(EqualTo(0)),
                    ],
                )
            )

        add_resync_config(ResyncConfig(width=8, lut=31, ff=42, logic=4))
        add_resync_config(ResyncConfig(width=16, lut=35, ff=50, logic=4))
        add_resync_config(ResyncConfig(width=24, lut=39, ff=58, logic=4))
        add_resync_config(ResyncConfig(width=32, lut=47, ff=66, logic=4))
        add_resync_config(ResyncConfig(width=64, lut=67, ff=98, logic=4))

        # Typical FIFO without levels. Use a wrapper as top level, which only routes the
        # "barebone" ports, resulting in a minimal FIFO.
        generics = dict(
            use_asynchronous_fifo=True, width=32, depth=1024, enable_output_register=False
        )
        projects.append(
            TsfpgaExampleVivadoNetlistProject(
                name=self.test_case_name(
                    f"{self.library_name}.asynchronous_fifo.minimal", generics
                ),
                modules=modules,
                part=part,
                top="fifo_netlist_build_wrapper",
                generics=generics,
                build_result_checkers=[
                    TotalLuts(EqualTo(44)),
                    Ffs(EqualTo(90)),
                    Ramb36(EqualTo(1)),
                    Ramb18(EqualTo(0)),
                    MaximumLogicLevel(EqualTo(6)),
                ],
            )
        )

        # Use a wrapper as top level, which only routes the "barebone" ports, resulting in
        # a minimal FIFO. This mode also adds an output register.
        generics.update(
            use_asynchronous_fifo=True, depth=generics["depth"] + 1, enable_output_register=True
        )
        projects.append(
            TsfpgaExampleVivadoNetlistProject(
                name=self.test_case_name(
                    f"{self.library_name}.asynchronous_fifo.minimal_with_output_register", generics
                ),
                modules=modules,
                part=part,
                top="fifo_netlist_build_wrapper",
                generics=generics,
                build_result_checkers=[
                    TotalLuts(EqualTo(45)),
                    Ffs(EqualTo(91)),
                    Ramb36(EqualTo(1)),
                    Ramb18(EqualTo(0)),
                    MaximumLogicLevel(EqualTo(6)),
                ],
            )
        )

        # A FIFO with level counter ports and non-default almost_full_level, which
        # increases resource utilization.
        generics = dict(width=32, depth=1024, almost_full_level=800)
        projects.append(
            TsfpgaExampleVivadoNetlistProject(
                name=self.test_case_name(
                    f"{self.library_name}.asynchronous_fifo.with_levels", generics
                ),
                modules=modules,
                part=part,
                top="asynchronous_fifo",
                generics=generics,
                build_result_checkers=[
                    TotalLuts(EqualTo(68)),
                    Ffs(EqualTo(112)),
                    Ramb36(EqualTo(1)),
                    Ramb18(EqualTo(0)),
                    MaximumLogicLevel(EqualTo(6)),
                ],
            )
        )

        # Enabling last should not increase resource utilization
        generics.update(enable_last=True)
        projects.append(
            TsfpgaExampleVivadoNetlistProject(
                name=self.test_case_name(
                    f"{self.library_name}.asynchronous_fifo.with_last", generics
                ),
                modules=modules,
                part=part,
                top="asynchronous_fifo",
                generics=generics,
                build_result_checkers=[
                    TotalLuts(EqualTo(68)),
                    Ffs(EqualTo(112)),
                    Ramb36(EqualTo(1)),
                    Ramb18(EqualTo(0)),
                    MaximumLogicLevel(EqualTo(6)),
                ],
            )
        )

        # Enabling packet mode increases resource utilization quite a lot since another
        # resync_counter is added.
        generics.update(enable_packet_mode=True)
        projects.append(
            TsfpgaExampleVivadoNetlistProject(
                name=self.test_case_name(
                    f"{self.library_name}.asynchronous_fifo.with_packet_mode", generics
                ),
                modules=modules,
                part=part,
                top="asynchronous_fifo",
                generics=generics,
                build_result_checkers=[
                    TotalLuts(EqualTo(60)),
                    Ffs(EqualTo(123)),
                    Ramb36(EqualTo(1)),
                    Ramb18(EqualTo(0)),
                    MaximumLogicLevel(EqualTo(6)),
                ],
            )
        )

        # Enabling the output register increases logic, but the register itself
        # should be packed into the RAM output register
        generics.update(depth=generics["depth"] + 1, enable_output_register=True)
        projects.append(
            TsfpgaExampleVivadoNetlistProject(
                name=self.test_case_name(
                    f"{self.library_name}.asynchronous_fifo.with_packet_mode_and_output_register",
                    generics,
                ),
                modules=modules,
                part=part,
                top="asynchronous_fifo",
                generics=generics,
                build_result_checkers=[
                    TotalLuts(EqualTo(76)),
                    Ffs(EqualTo(135)),
                    Ramb36(EqualTo(1)),
                    Ramb18(EqualTo(0)),
                    MaximumLogicLevel(EqualTo(8)),
                ],
            )
        )

        # Enabling drop_packet support actually decreases utilization. Some logic is added for
        # handling the drop_packet functionality, but one resync_counter instance is saved since
        # the read_level value is not used.
        generics.update(
            depth=generics["depth"] - 1, enable_output_register=False, enable_drop_packet=True
        )
        projects.append(
            TsfpgaExampleVivadoNetlistProject(
                name=self.test_case_name(
                    f"{self.library_name}.asynchronous_fifo.with_drop_packet", generics
                ),
                modules=modules,
                part=part,
                top="asynchronous_fifo",
                generics=generics,
                build_result_checkers=[
                    TotalLuts(EqualTo(66)),
                    Ffs(EqualTo(134)),
                    Ramb36(EqualTo(1)),
                    Ramb18(EqualTo(0)),
                    MaximumLogicLevel(EqualTo(6)),
                ],
            )
        )
