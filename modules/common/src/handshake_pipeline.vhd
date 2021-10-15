-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the tsfpga project.
-- https://tsfpga.com
-- https://gitlab.com/tsfpga/tsfpga
-- -------------------------------------------------------------------------------------------------
-- Handshake pipeline. Is used to ease the timing of a streaming data interface by inserting
-- register stages on the data and, in some modes, the control signals.
--
-- There are many modes available, with different characteristics.
-- See the descriptions within the code.
-- -------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;


entity handshake_pipeline is
  generic (
    data_width : integer;
    -- Setting to false can save logic footprint, at the cost of lower throughput
    full_throughput : boolean := true;
    -- Can result in smaller logic footprint and higher througphput, at the cost of worse timing
    -- on the input_ready signal.
    allow_poor_input_ready_timing : boolean := false;
    -- In the typical use case where we want a "byte strobe", this would be eight.
    -- In other cases, for example when the data is packed, we migh use a higher value.
    -- Must assign a valid value if input/output strobe is to be used.
    strobe_unit_width : positive := 8
  );
  port (
    clk : in std_logic;
    --
    input_ready : out std_logic := '0';
    input_valid : in std_logic;
    -- Optional to connect.
    input_last : in std_logic := '-';
    input_data : in std_logic_vector(data_width - 1 downto 0);
    -- Optional to connect. Must set valid 'strobe_unit_width' generic value in order to use this.
    input_strobe : in std_logic_vector(data_width / strobe_unit_width - 1 downto 0) :=
      (others => '-');
    --
    output_ready : in std_logic;
    output_valid : out std_logic := '0';
    output_last : out std_logic := '0';
    output_data : out std_logic_vector(data_width - 1 downto 0) := (others => '0');
    output_strobe : out std_logic_vector(data_width / strobe_unit_width - 1 downto 0) :=
      (others => '0')
  );
end entity;

architecture a of handshake_pipeline is

begin

  ------------------------------------------------------------------------------
  choose_mode : if full_throughput and allow_poor_input_ready_timing generate

    -- In this mode, the data and control signals are driven by registers, except for input_ready
    -- which will have an increased critical path. It still maintaints full throughput,
    -- and has a much smaller footprint than the full skid-aside buffer.
    --
    -- It is suitable in situtations where there is a complex net driving the data, which needs to
    -- be pipelined in order to achieve timing closure, but the timing of the control signals is
    -- not critical.

    input_ready <= output_ready or not output_valid;


    ------------------------------------------------------------------------------
    main : process
    begin
      wait until rising_edge(clk);

      if input_ready then
        output_valid <= input_valid;
        output_last <= input_last;
        output_data <= input_data;
        output_strobe <= input_strobe;
      end if;
    end process;


  ------------------------------------------------------------------------------
  elsif full_throughput and not allow_poor_input_ready_timing generate

    -- This mode is a full skid-aside buffer, aka skid buffer.
    --
    -- It makes sure that all output signals (data as well as control signals) are driven by
    -- a register.  It does so while sustaining full throughput. It has the best timing
    -- characteristics but also the largest logic footprint.

    signal input_ready_int : std_logic := '1';

    type state_t is (wait_for_input_valid, full_handshake_throughput, wait_for_output_ready);
    signal state : state_t := wait_for_input_valid;

    signal input_last_skid : std_logic := '0';
    signal input_data_skid : std_logic_vector(input_data'range) := (others => '0');
    signal input_strobe_skid : std_logic_vector(input_strobe'range) := (others => '0');

  begin

    input_ready <= input_ready_int;


    ------------------------------------------------------------------------------
    main : process
    begin
      wait until rising_edge(clk);

      case state is
        when wait_for_input_valid =>
          if input_valid then
            -- input_ready is '1', so if we get here an input transaction has occured
            output_valid <= '1';
            output_last <= input_last;
            output_data <= input_data;
            output_strobe <= input_strobe;

            state <= full_handshake_throughput;
          end if;

        when full_handshake_throughput =>
          -- input_ready and output_valid are always '1' in this state

          if input_valid and output_ready then
            -- Input and output transactions have occured. Update data register.
            output_last <= input_last;
            output_data <= input_data;
            output_strobe <= input_strobe;

          elsif output_ready then
            -- Output transaction has occured, but no input transaction
            output_valid <= '0';

            state <= wait_for_input_valid;

          elsif input_valid then
            -- Input transaction has occured, but no output transaction
            -- Values from input transaction will be saved in the skid-aside buffer while we wait for output_ready.
            input_ready_int <= '0';

            state <= wait_for_output_ready;
          end if;

        when wait_for_output_ready =>
          if output_ready then
            -- output_valid is '1', so if we get here an output transaction has occured
            input_ready_int <= '1';

            output_last <= input_last_skid;
            output_data <= input_data_skid;
            output_strobe <= input_strobe_skid;

            state <= full_handshake_throughput;
          end if;
      end case;

      if input_ready and input_valid then
        input_last_skid <= input_last;
        input_data_skid <= input_data;
        input_strobe_skid <= input_strobe;
      end if;
    end process;


  ------------------------------------------------------------------------------
  elsif (not full_throughput) and allow_poor_input_ready_timing generate

    -- All signals are driven by registers, except input_ready which will have an increased
    -- critical path. This mode will be able to maintain a one half throughput.
    --
    -- Compared to the first mode in this file, this one has a lower load on the input_ready.
    -- This results in somewhat better timing on the input_ready signal, at the cost of
    -- lower throughput.

  begin

    input_ready <= output_ready and output_valid;


    ------------------------------------------------------------------------------
    main : process
    begin
      wait until rising_edge(clk);

      output_valid <= input_valid and not (output_valid and output_ready);
      output_last <= input_last;
      output_data <= input_data;
      output_strobe <= input_strobe;
    end process;


  ------------------------------------------------------------------------------
  elsif (not full_throughput) and (not allow_poor_input_ready_timing) generate

    -- All signals are driven by registers, which results in the best timing but also the lowest
    -- throughput. This mode will be able to maintain a one third throughput.

  begin


    ------------------------------------------------------------------------------
    main : process
    begin
      wait until rising_edge(clk);

      input_ready <= output_ready and output_valid;
      -- Since there is a one cycle latency on output_valid, and a one cycle latency on input_ready,
      -- we have to stall for two cycles after a transaction, to allow the "input" master to update
      -- data and valid.
      output_valid <= input_valid and not (output_valid and output_ready) and not input_ready;
      output_last <= input_last;
      output_data <= input_data;
      output_strobe <= input_strobe;
    end process;

  end generate;

end architecture;
