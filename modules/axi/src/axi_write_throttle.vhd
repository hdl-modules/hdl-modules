-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the tsfpga project.
-- https://tsfpga.com
-- https://gitlab.com/tsfpga/tsfpga
-- -------------------------------------------------------------------------------------------------
-- Performs throttling of an AXI bus by limiting the number of outstanding
-- transactions.
--
-- This entity is to be used in conjuction with a data FIFO on the input.w side.
-- Using the level from that FIFO, the throttling will make sure that an address
-- transactio is not done until all data for that transaction is available in
-- the FIFO. This avoids stalling on the throttled_m2s.w channel.
--
-- To achieve this it keeps track of the number of outstanding beats
-- that have been negotiated but not yet sent.
-- -------------------------------------------------------------------------------------------------

library ieee;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;

library axi;
use axi.axi_pkg.all;

library common;
use common.types_pkg.all;

library math;
use math.math_pkg.all;


entity axi_write_throttle is
  generic(
    data_fifo_depth : positive;
    max_burst_length_beats : positive;
    id_width : natural;
    addr_width : positive;
    -- The AW channel is pipelined one step to improve poor timing, mainly on AWVALID.
    -- If this generic is set to false, the pipelining will be of a simpler model that has lower
    -- logic footprint, but only allow a transaction every third clock cycle. If it is set to true,
    -- the pipeline will support a transaction every clock cycle, at the cost of a greater
    -- logic footprint.
    full_aw_throughput : boolean
  );
  port(
    clk : in std_logic;
    --
    data_fifo_level : in integer range 0 to data_fifo_depth;
    --
    input_m2s : in axi_write_m2s_t := axi_write_m2s_init;
    input_s2m : out axi_write_s2m_t := axi_write_s2m_init;
    --
    throttled_m2s : out axi_write_m2s_t := axi_write_m2s_init;
    throttled_s2m : in axi_write_s2m_t := axi_write_s2m_init
  );
end entity;

architecture a of axi_write_throttle is

  signal pipelined_m2s_aw : axi_m2s_a_t := axi_m2s_a_init;
  signal pipelined_s2m_aw : axi_s2m_a_t := axi_s2m_a_init;

  signal address_transaction, data_transaction : std_logic := '0';

  -- The bits of the AWLEN field that shall be taken into account
  constant len_width : positive := num_bits_needed(max_burst_length_beats - 1);
  subtype len_range is integer range len_width - 1 downto 0;

  -- +1 in range for sign bit
  signal minus_burst_length_beats : signed(len_width + 1 - 1 downto 0) :=
    (others => '0');

  -- Since W transactions can happen before AW transaction,
  -- the counters can become negative as well as positive.
  subtype data_counter_t is integer range -data_fifo_depth to data_fifo_depth;

  -- Negation of:
  -- Data beats that are available in the FIFO, but have not yet been claimed by
  -- an address transaction.
  signal minus_num_beats_available_but_not_negotiated : data_counter_t := 0;

  -- Number of data beats that have been negotiated through an address transaction,
  -- but have not yet been sent via data transactions. Aka outstanding beats.
  signal num_beats_negotiated_but_not_sent : data_counter_t := 0;

begin

  ------------------------------------------------------------------------------
  pipeline : block
    constant m2s_length : positive := axi_m2s_a_sz(id_width=>id_width, addr_width=>addr_width);
    signal input_m2s_aw_slv, pipelined_m2s_aw_slv :
      std_logic_vector(m2s_length - 1 downto 0) := (others => '0');
    signal pipelined_valid : std_logic := '0';
  begin

    input_m2s_aw_slv <= to_slv(data=>input_m2s.aw, id_width=>id_width, addr_width=>addr_width);


    ------------------------------------------------------------------------------
    handshake_pipeline_inst : entity common.handshake_pipeline
      generic map (
        data_width => input_m2s_aw_slv'length,
        -- Choosable by user, since it affects footprint.
        full_throughput => full_aw_throughput,
        -- The goal of this pipeline is to improve timing of the control bits, so this one must
        -- be false, even though it will increase footprint.
        allow_poor_input_ready_timing => false
      )
      port map (
        clk => clk,
        --
        input_ready => input_s2m.aw.ready,
        input_valid => input_m2s.aw.valid,
        input_data => input_m2s_aw_slv,
        --
        output_ready => pipelined_s2m_aw.ready,
        output_valid => pipelined_valid,
        output_data => pipelined_m2s_aw_slv
      );


    ------------------------------------------------------------------------------
    assign_aw : process(all)
    begin
      pipelined_m2s_aw <= to_axi_m2s_a(
        data=>pipelined_m2s_aw_slv,
        id_width=>id_width,
        addr_width=>addr_width
      );
      pipelined_m2s_aw.valid <= pipelined_valid;
    end process;

  end block;


  -- Two complement inversion: inv(len) = - len - 1 = - (len + 1) = - burst_length_beats
  minus_burst_length_beats <= not signed('0' & pipelined_m2s_aw.len(len_range));

  ------------------------------------------------------------------------------
  assign_throttled_bus : process(all)
    variable block_address_transactions : boolean;
  begin
    throttled_m2s.aw <= pipelined_m2s_aw;
    pipelined_s2m_aw <= throttled_s2m.aw;

    throttled_m2s.w <= input_m2s.w;
    input_s2m.w <= throttled_s2m.w;

    throttled_m2s.b <= input_m2s.b;
    input_s2m.b <= throttled_s2m.b;

    -- The original condition would have been
    --
    -- block_address_transactions =
    --   burst_length_beats > num_beats_available_but_not_negotiated
    --
    -- where num_beats_available_but_not_negotiated =
    --   data_fifo_level - num_beats_negotiated_but_not_sent
    --
    -- where num_beats_negotiated_but_not_sent was given by accumulating
    --   to_int(address_transaction) * burst_length_beats - to_int(data_transaction)
    --
    -- However this created a very long critical path from AWLEN to AWVALID. The
    -- bytes_per_beat = AWLEN + 1 term, used in two places was replaced with -inv(AWLEN).
    -- The minus sign was moved to the right side of the expression, which changed the subtraction
    -- order. This makes the signals and their ranges a bit harder to understand, but it improves
    -- the critical path a lot.
    block_address_transactions :=
      minus_burst_length_beats < minus_num_beats_available_but_not_negotiated;
    if block_address_transactions then
      throttled_m2s.aw.valid <= '0';
      pipelined_s2m_aw.ready <= '0';
    end if;
  end process;


  ------------------------------------------------------------------------------
  count : process
    variable num_beats_negotiated_but_not_sent_int : data_counter_t := 0;
    variable aw_term : signed(minus_burst_length_beats'range) := (others => '0');
  begin
    wait until rising_edge(clk);

    -- This muxing results in a shorter critical path than doing
    -- e.g. minus_burst_length_beats * to_int(address_transaction).
    -- LUT usage stayed the same.
    if address_transaction then
      aw_term := minus_burst_length_beats;
    else
      aw_term := (others => '0');
    end if;

    num_beats_negotiated_but_not_sent_int := num_beats_negotiated_but_not_sent
      - to_integer(aw_term)
      - to_int(data_transaction);

    minus_num_beats_available_but_not_negotiated <=
      num_beats_negotiated_but_not_sent_int - data_fifo_level;

    num_beats_negotiated_but_not_sent <= num_beats_negotiated_but_not_sent_int;
  end process;

  address_transaction <= throttled_s2m.aw.ready and throttled_m2s.aw.valid;
  data_transaction <= throttled_s2m.w.ready and throttled_m2s.w.valid;

end architecture;
