-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the tsfpga project.
-- https://tsfpga.com
-- https://gitlab.com/tsfpga/tsfpga
-- -------------------------------------------------------------------------------------------------
-- The goal of this entity is to process an AXI-Stream so that bursts where 'last' is asserted on
-- a word that is completely strobed out are modified so that 'last' is instead asserted on the last
-- word which does have a strobe.
--
-- As a consequence of this, all words in the stream that are completely strobed out are dropped
-- by this entity.
-- -------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

library common;
use common.types_pkg.all;


entity strobe_on_last is
  generic (
    data_width : positive
  );
  port (
    clk : in std_logic;
    --
    input_ready : out std_logic := '0';
    input_valid : in std_logic;
    input_last : in std_logic;
    input_data : in std_logic_vector(data_width - 1 downto 0);
    input_strobe : in std_logic_vector(data_width / 8 - 1 downto 0);
    --
    output_ready : in std_logic;
    output_valid : out std_logic := '0';
    output_last : out std_logic := '0';
    output_data : out std_logic_vector(data_width - 1 downto 0) := (others => '0');
    output_strobe : out std_logic_vector(data_width / 8 - 1 downto 0) :=
      (others => '0')
  );
end entity;

architecture a of strobe_on_last is

  constant strobe_all_zero : std_logic_vector(input_strobe'range) := (others => '0');

  signal input_stream_ready, input_stream_valid : std_logic := '0';

  signal pipelined_ready, pipelined_valid, pipelined_last : std_logic := '0';

begin

  ------------------------------------------------------------------------------
  drop_strobed_out_input_words : process(all)
  begin
    if input_strobe = strobe_all_zero then
      input_ready <= '1';
      input_stream_valid <= '0';
    else
      input_ready <= input_stream_ready;
      input_stream_valid <= input_valid;
    end if;
  end process;


  ------------------------------------------------------------------------------
  handshake_pipeline_block : block
  begin
    -- A handshake pipeline implementation that is very similar to the "full throughput but bad
    -- input_ready timing" mode of handshake_pipeline. It is implemented here since this entity
    -- is very dependent on the specific timing attributes of this pipeline.

    input_stream_ready <= pipelined_ready or not pipelined_valid;


    ------------------------------------------------------------------------------
    pipeline_data : process
    begin
      wait until rising_edge(clk);

      if input_stream_ready then
        pipelined_valid <= input_stream_valid;
        pipelined_last <= input_last;
        output_data <= input_data;
        output_strobe <= input_strobe;
      end if;
    end process;

  end block;


  ------------------------------------------------------------------------------
  output_block : block
    type state_t is (let_data_pass, send_output_last);
    signal state : state_t := let_data_pass;
  begin

    ------------------------------------------------------------------------------
    output_fsm : process
    begin
      wait until rising_edge(clk);

      case state is
        when let_data_pass =>
          if (
            pipelined_valid
            and not pipelined_last
            and input_valid
            and input_last
            and to_sl(input_strobe = strobe_all_zero)
          ) then
            -- Input word is strobed out, which means that it shall be dropped, but it has 'last'
            -- set, so 'last' shall instead be set on the currently pipelined word.
            -- Note that the currently pipelined word might be the last of a previous burst.
            -- I.e. the input burst is of length one.
            -- In that case the strobed out input word with 'last' shall simply be dropped.
            state <= send_output_last;
          end if;

        when send_output_last =>
          if output_ready and output_valid then
            -- The input word is dropped instantly, but we have to wait for the output transaction
            -- before procedding.
            state <= let_data_pass;
          end if;
      end case;

    end process;


    ------------------------------------------------------------------------------
    assign_output : process(all)
    begin
      case state is

        when let_data_pass =>
          if (
            pipelined_valid
            and (pipelined_last or (input_valid and to_sl(input_strobe /= strobe_all_zero)))
          ) then
            -- If we are currently on 'last', or if the input word has strobed lanes, then
            -- we can just let data pass. This is the standard state.
            pipelined_ready <= output_ready;
            output_valid <= pipelined_valid;
            output_last <= pipelined_last;

          else
            -- In other cases we have to wait for an input word that shows strobed lanes or 'last',
            -- before we can release the output word.
            pipelined_ready <= '0';
            output_valid <= '0';
            output_last <= '-';
          end if;

        when send_output_last =>
          -- Let data pass but force 'last'
          pipelined_ready <= output_ready;
          output_valid <= pipelined_valid;
          output_last <= '1';

      end case;

    end process;

  end block;

end architecture;
