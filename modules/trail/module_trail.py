# --------------------------------------------------------------------------------------------------
# Copyright (c) Lukas Vik. All rights reserved.
#
# This file is part of the hdl-modules project, a collection of reusable, high-quality,
# peer-reviewed VHDL building blocks.
# https://hdl-modules.com
# https://github.com/hdl-modules/hdl-modules
# --------------------------------------------------------------------------------------------------

# Third party libraries
from tsfpga.module import BaseModule


class Module(BaseModule):
    def setup_vunit(self, vunit_proj, **kwargs):  # pylint: disable=unused-argument
        self.setup_trail_pkg_tests(vunit_proj=vunit_proj)

    def setup_trail_pkg_tests(self, vunit_proj):
        tb_trail_pkg = vunit_proj.library(self.library_name).test_bench("tb_trail_pkg")
        test_slv_conversion = tb_trail_pkg.test("test_slv_conversion")

        tb_trail_pipeline = vunit_proj.library(self.library_name).test_bench("tb_trail_pipeline")

        for data_width in [8, 16, 32, 64]:
            for address_width in [7, 24, 40]:
                generics = dict(address_width=address_width, data_width=data_width)

                self.add_vunit_config(
                    test=test_slv_conversion, generics=generics, set_random_seed=True
                )
                self.add_vunit_config(
                    test=tb_trail_pipeline, generics=generics, set_random_seed=True
                )
