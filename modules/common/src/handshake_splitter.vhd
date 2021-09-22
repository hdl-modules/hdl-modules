-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the tsfpga project.
-- https://tsfpga.com
-- https://gitlab.com/tsfpga/tsfpga
-- -------------------------------------------------------------------------------------------------
-- Note that this block can break the AXI-Stream protocol. If one of the outputs
-- lowers ready, that will lower valid for the other output. Use only in situations
-- that can handle this.
-- -------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;


entity handshake_splitter is
  port (
    clk : in std_logic;
    --
    input_ready : out std_logic;
    input_valid : in std_logic;
    --
    output0_ready : in std_logic;
    output0_valid : out std_logic := '0';
    --
    output1_ready : in std_logic;
    output1_valid : out std_logic := '0'
  );
end entity;

architecture a of handshake_splitter is
begin

  input_ready <= output0_ready and output1_ready;

  output0_valid <= input_valid and output1_ready;
  output1_valid <= input_valid and output0_ready;

end architecture;
