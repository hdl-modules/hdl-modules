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
        tb = vunit_proj.library(self.library_name).test_bench("tb_axi_stream_pkg")
        for data_width in [24, 32, 64]:
            for user_width in [8, 16]:
                generics = {"data_width": data_width, "user_width": user_width}
                self.add_vunit_config(tb, generics=generics)

        tb = vunit_proj.library(self.library_name).test_bench("tb_axi_stream_fifo")
        tb.add_config(name="synchronous", generics={"depth": 16, "asynchronous": False})
        tb.add_config(name="asynchronous", generics={"depth": 16, "asynchronous": True})
