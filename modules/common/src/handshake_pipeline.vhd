-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the hdl-modules project, a collection of reusable, high-quality,
-- peer-reviewed VHDL building blocks.
-- https://hdl-modules.com
-- https://github.com/hdl-modules/hdl-modules
-- -------------------------------------------------------------------------------------------------
-- Handshake pipeline. Is used to ease the timing of a streaming data interface by inserting
-- register stages on the data and/or control signals.
--
-- There are many modes available, with different characteristics, that are enabled
-- with different combinations of ``full_throughput``, ``pipeline_control_signals``
-- and ``pipeline_data_signals``.
-- See the descriptions within the code for more details about throughput and fanout.
-- -------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;


entity handshake_pipeline is
  generic (
    data_width : natural;
    -- Setting to false can save logic footprint, at the cost of lower throughput
    full_throughput : boolean := true;
    -- Ensures that there is no combinatorial path between valid and ready on input and output.
    -- Will result in higher logic footprint.
    pipeline_control_signals : boolean := true;
    -- Ensures that there is no combinatorial path from data, strobe and last on input to output.
    -- Will result in higher logic footprint.
    pipeline_data_signals : boolean := true;
    -- In the typical use case where we want a "byte strobe", this would be eight.
    -- In other cases, for example when the data is packed, we might use a higher value.
    -- Must assign a valid value if input/output strobe is to be used.
    strobe_unit_width : positive := 8
  );
  port (
    clk : in std_ulogic;
    --# {{}}
    input_ready : out std_ulogic := '0';
    input_valid : in std_ulogic;
    -- Optional to connect.
    input_last : in std_ulogic := '-';
    input_data : in std_ulogic_vector(data_width - 1 downto 0) := (others => '-');
    -- Optional to connect. Must set valid 'strobe_unit_width' generic value in order to use this.
    input_strobe : in std_ulogic_vector(data_width / strobe_unit_width - 1 downto 0) :=
      (others => '-');
    --# {{}}
    output_ready : in std_ulogic;
    output_valid : out std_ulogic := '0';
    output_last : out std_ulogic := '0';
    output_data : out std_ulogic_vector(data_width - 1 downto 0) := (others => '0');
    output_strobe : out std_ulogic_vector(data_width / strobe_unit_width - 1 downto 0) :=
      (others => '0')
  );
end entity;

architecture a of handshake_pipeline is

begin

  ------------------------------------------------------------------------------
  choose_mode : if full_throughput and pipeline_data_signals and pipeline_control_signals generate

    -- This mode is a full skid-aside buffer, aka skid buffer.
    --
    -- It makes sure that all output signals (data as well as control signals) are driven by
    -- a register.  It does so while sustaining full throughput. It has the best timing
    -- characteristics but also the largest logic footprint.

    signal input_ready_int : std_ulogic := '1';

    type state_t is (wait_for_input_valid, full_handshake_throughput, wait_for_output_ready);
    signal state : state_t := wait_for_input_valid;

    signal input_last_skid : std_ulogic := '0';
    signal input_data_skid : std_ulogic_vector(input_data'range) := (others => '0');
    signal input_strobe_skid : std_ulogic_vector(input_strobe'range) := (others => '0');

  begin

    input_ready <= input_ready_int;


    ------------------------------------------------------------------------------
    main : process
    begin
      wait until rising_edge(clk);

      case state is
        when wait_for_input_valid =>
          if input_valid then
            -- input_ready is '1', so if we get here an input transaction has occurred
            output_valid <= '1';
            output_last <= input_last;
            output_data <= input_data;
            output_strobe <= input_strobe;

            state <= full_handshake_throughput;
          end if;

        when full_handshake_throughput =>
          -- input_ready and output_valid are always '1' in this state

          if input_valid and output_ready then
            -- Input and output transactions have occurred. Update data register.
            output_last <= input_last;
            output_data <= input_data;
            output_strobe <= input_strobe;

          elsif output_ready then
            -- Output transaction has occurred, but no input transaction
            output_valid <= '0';

            state <= wait_for_input_valid;

          elsif input_valid then
            -- Input transaction has occurred, but no output transaction
            -- Values from input transaction will be saved in the skid-aside buffer while we wait
            -- for output_ready.
            input_ready_int <= '0';

            state <= wait_for_output_ready;
          end if;

        when wait_for_output_ready =>
          if output_ready then
            -- output_valid is '1', so if we get here an output transaction has occurred
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
  elsif full_throughput and pipeline_data_signals and (not pipeline_control_signals) generate

    -- In this mode, the data and control signals are driven by registers, except for input_ready
    -- which will have an increased critical path. It still maintains full throughput,
    -- and has a much smaller footprint than the full skid-aside buffer.
    --
    -- It is suitable in situations where there is a complex net driving the data, which needs to
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
  elsif (not full_throughput) and pipeline_data_signals and pipeline_control_signals generate

    -- All signals are driven by registers, which results in the best timing but also the lowest
    -- throughput. This mode will be able to maintain a one third throughput.

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


  ------------------------------------------------------------------------------
  elsif (not full_throughput) and pipeline_data_signals and (not pipeline_control_signals) generate

    -- All signals are driven by registers, except input_ready which will have an increased
    -- critical path. This mode will be able to maintain a one half throughput.
    --
    -- Compared to the "full_throughput and pipeline_data_signals and not pipeline_control_signals"
    -- above, this one has a lower load on the input_ready.
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
  elsif (not pipeline_data_signals) and pipeline_control_signals generate

    -- Control signals are pipelined while data, last and strobe signals
    -- are driven directly from input to output.
    -- This mode will be able to maintain a third throughput.

    type state_t is (wait_for_input_valid, wait_for_output_ready);
    signal state : state_t := wait_for_input_valid;

  begin

    assert not full_throughput
      report "Does not support full throughput when only pipelining control signals"
      severity failure;


    ------------------------------------------------------------------------------
    main : process
    begin
      wait until rising_edge(clk);

      case state is
        when wait_for_input_valid =>
          input_ready <= '0';

          -- Proceed to output the input data, but only if we are not waiting for a pop
          -- of the previous input
          if input_valid and not input_ready then
            -- Input is valid, so signal that it can be used for output.
            -- We don't pop it from the input yet, because we don't want an extra register stage
            -- for data in this mode.
            output_valid <= '1';
            state <= wait_for_output_ready;
          end if;

        when wait_for_output_ready =>
          assert output_valid report "Should not be able to get here without valid output";
          assert input_valid report "Should not be able to get here without valid input";

          -- Wait for output ready and then pop the input
          if output_ready then
            -- Pop the input word next cycle
            input_ready <= '1';
            output_valid <= '0';
            state <= wait_for_input_valid;
          end if;

      end case;
    end process;

    output_data <= input_data;
    output_strobe <= input_strobe;
    output_last <= input_last;

  elsif (not pipeline_data_signals) and (not pipeline_control_signals) generate

    -- This mode will simply create a passthrough.
    -- This may be handy if you want to see how removing a pipeline stage affects timing.

    input_ready <= output_ready;
    output_valid <= input_valid;
    output_data <= input_data;
    output_strobe <= input_strobe;
    output_last <= input_last;

  end generate;

end architecture;
