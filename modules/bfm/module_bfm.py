# --------------------------------------------------------------------------------------------------
# Copyright (c) Lukas Vik. All rights reserved.
#
# This file is part of the hdl_modules project.
# https://hdl-modules.com
# https://gitlab.com/tsfpga/hdl_modules
# --------------------------------------------------------------------------------------------------

import random

from tsfpga.module import BaseModule


class Module(BaseModule):
    def setup_vunit(self, vunit_proj, **kwargs):  # pylint: disable=unused-argument
        self.setup_axi_bfm_pkg_tests(vunit_proj=vunit_proj)
        self.setup_axi_read_bfm_tests(vunit_proj=vunit_proj)
        self.setup_axi_write_bfm_tests(vunit_proj=vunit_proj)

        self.setup_axi_stream_bfm_tests(vunit_proj=vunit_proj)

        self.setup_handshake_bfm_tests(vunit_proj=vunit_proj)

    def setup_axi_bfm_pkg_tests(self, vunit_proj):
        tb = vunit_proj.library(self.library_name).test_bench("tb_axi_bfm_pkg")
        self.add_vunit_config(test=tb, set_random_seed=True)

    def setup_axi_read_bfm_tests(self, vunit_proj):
        tb = vunit_proj.library(self.library_name).test_bench("tb_axi_read_bfm")

        for data_width in [16, 32]:
            self.add_vunit_config(
                test=tb, set_random_seed=True, generics=dict(data_width=data_width)
            )

    def setup_axi_write_bfm_tests(self, vunit_proj):
        tb = vunit_proj.library(self.library_name).test_bench("tb_axi_write_bfm")

        for data_width in [16, 32]:
            for data_before_address in [True, False]:
                for set_axi3_w_id in [True, False]:
                    generics = dict(
                        data_width=data_width,
                        data_before_address=data_before_address,
                        set_axi3_w_id=set_axi3_w_id,
                    )
                    self.add_vunit_config(test=tb, set_random_seed=True, generics=generics)

    def setup_axi_stream_bfm_tests(self, vunit_proj):
        test = vunit_proj.library(self.library_name).test_bench("tb_axi_stream_bfm")
        random.seed()

        for data_width in [8, 16, 32]:
            generics = dict(
                data_width=data_width,
                master_stall_probability_percent=random.randrange(90),
                slave_stall_probability_percent=random.randrange(90),
            )

            self.add_vunit_config(test=test, set_random_seed=True, generics=generics)

    def setup_handshake_bfm_tests(self, vunit_proj):
        tb = vunit_proj.library(self.library_name).test_bench("tb_handshake_bfm")

        test = tb.get_tests("test_full_master_throughput")[0]
        self.add_vunit_config(
            test,
            generics=dict(
                data_width=0, master_stall_probability_percent=0, slave_stall_probability_percent=50
            ),
        )

        test = tb.get_tests("test_full_slave_throughput")[0]
        self.add_vunit_config(
            test,
            generics=dict(
                data_width=0, master_stall_probability_percent=50, slave_stall_probability_percent=0
            ),
        )

        test = tb.get_tests("test_random_data")[0]
        self.add_vunit_config(
            test,
            generics=dict(
                data_width=16,
                master_stall_probability_percent=50,
                slave_stall_probability_percent=50,
            ),
        )
