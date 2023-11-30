-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the hdl-modules project, a collection of reusable, high-quality,
-- peer-reviewed VHDL building blocks.
-- https://hdl-modules.com
-- https://github.com/hdl-modules/hdl-modules
-- -------------------------------------------------------------------------------------------------
-- A VHDL context for including the packages in this library.
-- -------------------------------------------------------------------------------------------------

context common_context is
  library common;

  use common.addr_pkg.all;
  use common.attribute_pkg.all;
  use common.common_pkg.all;
  use common.time_pkg.all;
  use common.types_pkg.all;
end context;
