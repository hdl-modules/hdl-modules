# --------------------------------------------------------------------------------------------------
# Copyright (c) Lukas Vik. All rights reserved.
#
# This file is part of the hdl-modules project, a collection of reusable, high-quality,
# peer-reviewed VHDL building blocks.
# https://hdl-modules.com
# https://github.com/hdl-modules/hdl-modules
# --------------------------------------------------------------------------------------------------

from __future__ import annotations

from typing import TYPE_CHECKING, Any

from tsfpga.module import BaseModule

if TYPE_CHECKING:
    from vunit.ui import VUnit


class Module(BaseModule):
    def setup_vunit(
        self,
        vunit_proj: VUnit,
        **kwargs: Any,  # noqa: ANN401, ARG002
    ) -> None:
        self.setup_bfm_pkg_tests(vunit_proj=vunit_proj)
        self.setup_axi_bfm_pkg_tests(vunit_proj=vunit_proj)
        self.setup_axi_read_bfm_tests(vunit_proj=vunit_proj)
        self.setup_axi_write_bfm_tests(vunit_proj=vunit_proj)

        self.setup_axi_stream_bfm_tests(vunit_proj=vunit_proj)

        self.setup_handshake_bfm_tests(vunit_proj=vunit_proj)

    def setup_bfm_pkg_tests(self, vunit_proj: VUnit) -> None:
        tb = vunit_proj.library(self.library_name).test_bench("tb_integer_array_bfm_pkg")
        self.add_vunit_config(test=tb, set_random_seed=True)

    def setup_axi_bfm_pkg_tests(self, vunit_proj: VUnit) -> None:
        tb = vunit_proj.library(self.library_name).test_bench("tb_axi_bfm_pkg")
        self.add_vunit_config(test=tb, set_random_seed=True)

    def setup_axi_read_bfm_tests(self, vunit_proj: VUnit) -> None:
        tb = vunit_proj.library(self.library_name).test_bench("tb_axi_read_bfm")

        for data_width in [16, 32]:
            self.add_vunit_config(
                test=tb, set_random_seed=True, generics={"data_width": data_width}
            )

    def setup_axi_write_bfm_tests(self, vunit_proj: VUnit) -> None:
        tb = vunit_proj.library(self.library_name).test_bench("tb_axi_write_bfm")

        for data_width in [16, 32]:
            for data_before_address in [True, False]:
                for enable_axi3 in [True, False]:
                    generics = {
                        "data_width": data_width,
                        "data_before_address": data_before_address,
                        "enable_axi3": enable_axi3,
                    }
                    self.add_vunit_config(test=tb, set_random_seed=True, generics=generics)

    def setup_axi_stream_bfm_tests(self, vunit_proj: VUnit) -> None:
        tb = vunit_proj.library(self.library_name).test_bench("tb_axi_stream_bfm")
        for data_width in [8, 16, 32]:
            generics = {"data_width": data_width}
            self.add_vunit_config(test=tb, generics=generics, set_random_seed=True)

    def setup_handshake_bfm_tests(self, vunit_proj: VUnit) -> None:
        tb = vunit_proj.library(self.library_name).test_bench("tb_handshake_bfm")

        for test in tb.get_tests():
            master_stall_probability_percent = (
                0 if test.name == "test_full_master_throughput" else 50
            )
            slave_stall_probability_percent = 0 if test.name == "test_full_slave_throughput" else 50
            generics = {
                "master_stall_probability_percent": master_stall_probability_percent,
                "slave_stall_probability_percent": slave_stall_probability_percent,
            }

            self.add_vunit_config(test, generics=generics, set_random_seed=True)
