# --------------------------------------------------------------------------------------------------
# Copyright (c) Lukas Vik. All rights reserved.
#
# This file is part of the tsfpga project.
# https://tsfpga.com
# https://gitlab.com/tsfpga/tsfpga
# --------------------------------------------------------------------------------------------------

from tsfpga.module import BaseModule


class Module(BaseModule):
    def setup_vunit(self, vunit_proj, **kwargs):  # pylint: disable=unused-argument
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
