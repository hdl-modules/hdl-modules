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
        tb = vunit_proj.library(self.library_name).test_bench("tb_unsigned_divider")
        for dividend_width in [4, 7, 8]:
            for divisor_width in [4, 7, 8]:
                name = f"{dividend_width}_div_{divisor_width}"
                tb.add_config(
                    name=name,
                    generics={"dividend_width": dividend_width, "divisor_width": divisor_width},
                )
