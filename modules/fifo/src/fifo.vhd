-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the hdl-modules project, a collection of reusable, high-quality,
-- peer-reviewed VHDL building blocks.
-- https://hdl-modules.com
-- https://github.com/hdl-modules/hdl-modules
-- -------------------------------------------------------------------------------------------------
-- Synchronous (one clock) First In First Out (FIFO) data buffering stage with AXI-Stream-like
-- handshaking interface.
-- This implementation is very versatile in terms of features that can be enabled.
-- Despite this it is very optimized when used in its barebone configuration, and will result in a
-- very small logic footprint.
--
-- Features that can be enabled:
--
-- * If ``enable_last`` is set to ``true``, the ``write_last`` signal will be concatenated with
--   ``write_data`` and stored in RAM, and then passed on to ``read_last``. Without this,
--   ``read_last`` will have an undefined value and ``write_last`` will not be used.
--
-- * FIFO packet mode is enabled by setting the generic ``enable_packet_mode`` to ``true``.
--   When this mode is enabled, ``read_valid`` will not be asserted until the whole "packet"
--   has been written to FIFO, as indicated by ``write_valid and write_last``.
--
-- * The FIFO supports dropping packets that are in the progress of being written.
--   If the ``enable_drop_packet`` generic is set to ``true``, the ``drop_packet`` port
--   can be used to drop the current packet, i.e. all words written since the last
--   ``write_valid and write_last`` happened.
--
--   The port can be asserted at any time, regardless of e.g. ``write_ready`` or ``write_valid``.
--
-- * Additionally there is a "peek read" mode available that is enabled by setting the
--   ``enable_peek_mode`` generic to ``true``. It makes it possible to read a packet multiple times.
--   If the ``read_peek_mode`` signal is asserted when ``read_ready`` is asserted, the current
--   packet will not be popped from the FIFO, but can instead be read again.
--   Once the readout encounters ``read_last``, the readout will return again to the first word of
--   the packet.
--   Note that the ``read_peek_mode`` value may not be changed during the readout of a packet.
--   It must be static for all words in a packet, but may be updated after ``read_last``.
--
-- * There is an option to enable an output register using the ``enable_output_register`` generic.
--   This can be used to improve timing since the routing delay on the data output of a block RAM is
--   usually quite high.
--   Most block RAM primitives have a "hard" output register that can be used.
--   It has been verified (with :ref:`tsfpga:netlist_build` in CI) that the implementation in this
--   file will map to the hard output register in Xilinx 7-series devices,
--   and hence not consume extra flip-flops.
--
--   .. note::
--     The "peek read" mode can not be used when output register is enabled.
-- -------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library common;
use common.attribute_pkg.all;
use common.types_pkg.all;

library math;
use math.math_pkg.all;


entity fifo is
  generic (
    width : positive;
    depth : positive;
    -- Changing these levels from default value will increase logic footprint
    almost_full_level : natural range 0 to depth := depth;
    almost_empty_level : natural range 0 to depth := 0;
    -- Set to true in order to use 'read_last' and 'write_last'
    enable_last : boolean := false;
    -- If enabled, 'read_valid' will not be asserted until a full packet is available in
    -- FIFO. I.e. when 'write_last' has been received. Must set 'enable_last' as well to use this.
    enable_packet_mode : boolean := false;
    -- Set to true in order to use the 'drop_packet' port. Must set 'enable_packet_mode' as
    -- well to use this.
    enable_drop_packet : boolean := false;
    -- Set to true in order to read words without popping from FIFO using the 'read_peek_mode' port.
    -- Must set 'enable_packet_mode' as well to use this.
    -- Can not be used in conjunction with 'enable_output_register'.
    enable_peek_mode : boolean := false;
    -- Use an extra output register. This will be integrated in the memory if block RAM is used.
    -- Increases latency but improves timing on the data path.
    -- When enabled, the output register is included in the 'depth',
    -- meaning that the RAM depth is 'depth - 1'.
    -- The "peek read" mode can not be used when this is enabled.
    enable_output_register : boolean := false;
    -- Select what FPGA primitives will be used to implement the FIFO memory.
    ram_type : ram_style_t := ram_style_auto
  );
  port (
    clk : in std_ulogic;
    --# {{}}
    -- When 'packet_mode' is enabled, this value will still reflect the number of words that are in
    -- the FIFO RAM. This is not necessarily the same as the number of words that can be read, in
    -- this mode.
    level : out natural range 0 to depth := 0;

    --# {{}}
    read_ready : in std_ulogic;
    -- '1' if FIFO is not empty
    read_valid : out std_ulogic := '0';
    read_data : out std_ulogic_vector(width - 1 downto 0) := (others => '0');
    -- Must set 'enable_last' generic in order to use this
    read_last : out std_ulogic := '0';
    -- When this is asserted, packets can be read multiple times from the FIFO.
    -- Must set 'enable_peek_mode' generic in order to use this.
    read_peek_mode : in std_ulogic := '0';
    -- '1' if there are 'almost_empty_level' or fewer words available to read
    almost_empty : out std_ulogic := '1';

    --# {{}}
    -- '1' if FIFO is not full
    write_ready : out std_ulogic := '1';
    write_valid : in std_ulogic;
    write_data : in std_ulogic_vector(width - 1 downto 0);
    -- Must set 'enable_last' generic in order to use this
    write_last : in std_ulogic := '0';
    -- '1' if there are 'almost_full_level' or more words available in the FIFO
    almost_full : out std_ulogic := '0';
    -- Drop the current packet (all words that have been written since the previous write_last).
    -- Must set 'enable_drop_packet' generic in order to use this.
    drop_packet : in std_ulogic := '0'
  );
end entity;

architecture a of fifo is

  constant memory_depth : positive := depth - to_int(enable_output_register);

  -- Need one extra bit in the addresses to be able to make the distinction if the FIFO
  -- is full or empty (where the addresses would otherwise be equal).
  subtype fifo_addr_t is u_unsigned(num_bits_needed(2 * memory_depth - 1) - 1 downto 0);
  signal read_addr_next, read_addr, read_addr_peek : fifo_addr_t := (others => '0');
  signal write_addr_next, write_addr, write_addr_next_if_not_drop, write_addr_start_of_packet :
    fifo_addr_t := (others => '0');

  -- The part of the address that actually goes to the BRAM address port
  subtype bram_addr_range is natural range num_bits_needed(memory_depth - 1) - 1 downto 0;

  signal num_lasts_in_fifo : natural range 0 to depth := 0;

  signal should_drop_packet, should_peek_read : std_ulogic := '0';

  signal read_ready_ram, read_valid_ram, read_last_ram, read_valid_ram_pre : std_ulogic := '0';
  signal read_data_ram : std_ulogic_vector(width - 1 downto 0) := (others => '0');
  signal word_in_output_register : natural range 0 to 1 := 0;

  signal write_last_transaction_p1 : std_ulogic := '0';
  signal unsure_if_we_have_full_packet, unsure_if_we_have_full_packet_p1 : std_ulogic := '0';

begin

  ------------------------------------------------------------------------------
  assert is_power_of_two(memory_depth)
    report "RAM depth must be a power of two."
    severity failure;

  assert enable_last or (not enable_packet_mode)
    report "Must set enable_last for packet mode"
    severity failure;

  assert enable_packet_mode or (not enable_drop_packet)
    report "Must set enable_packet_mode for drop packet support"
    severity failure;

  assert enable_packet_mode or (not enable_peek_mode)
    report "Must set enable_packet_mode for peek mode support"
    severity failure;

  assert not (enable_output_register and enable_peek_mode)
    report "Output register is not supported in peek mode"
    severity failure;


  ------------------------------------------------------------------------------
  assertions : process
  begin
    wait until rising_edge(clk);

    assert enable_peek_mode or read_peek_mode = '0'
      report "Must enable 'peek_mode' using generic";

    assert enable_drop_packet or drop_packet = '0'
      report "Must enable 'drop_packet' using generic";
  end process;


  -- These flags will update one cycle after the write/read that puts them over/below the line.
  -- Except for the fringe cases:
  --
  -- When almost_full_level is 'depth' and a read puts it below the line there will be a two
  -- cycle latency. For a write that puts it above the line there is always one cycle latency.
  --
  -- When almost_empty_level is zero and a write puts it over the line there will be a two
  -- cycle latency. For a read that puts it below the line there is always one cycle latency.

  ------------------------------------------------------------------------------
  assign_almost_full : if almost_full_level = depth generate
    almost_full <= not write_ready;
  else generate
    almost_full <= to_sl(level > almost_full_level - 1);
  end generate;


  ------------------------------------------------------------------------------
  assign_almost_empty : if almost_empty_level = 0 generate
    almost_empty <= not read_valid;
  else generate
    almost_empty <= to_sl(level < almost_empty_level + 1);
  end generate;


  should_drop_packet <= to_sl(enable_drop_packet) and drop_packet;
  should_peek_read <= to_sl(enable_peek_mode) and read_peek_mode;


  ------------------------------------------------------------------------------
  status : process
    variable num_lasts_in_fifo_next : natural range 0 to depth := 0;
    variable word_in_output_register_next : natural range 0 to 1 := 0;
  begin
    wait until rising_edge(clk);

    if enable_packet_mode then
      -- We do _not_ want to look at the read_last_ram signal here, as it is part of the
      -- read data, and using it would make it impossible to use the RAM output_register.
      -- If enable_output_register is not set, read_* and the read_*_ram signals are the same.
      --
      -- Note that we use a pipelined indicator for the last beat being written.
      -- I.e. we get a pessimistic estimation for the number of packets that are in the FIFO.
      -- This is so that valid write data always has time to propagate through the RAM
      -- to the read side before this counter indicates that there is a packet available.
      -- This is needed for packets that are one beat long.
      num_lasts_in_fifo_next := (
        num_lasts_in_fifo
        + to_int(write_last_transaction_p1)
        - to_int(read_ready and read_valid and read_last and not should_peek_read)
      );
      write_last_transaction_p1 <=
        write_ready and write_valid and write_last and not should_drop_packet;

      if enable_output_register then
        -- Note that further conditions are applied in the combinatorial assignment
        -- of 'read_valid_ram'.
        -- The condition for 'valid' here is almost the same as the one below for when output
        -- register is not enabled.
        -- The difference is that we can use the one cycle old 'num_lasts_in_fifo' here, which might
        -- make us assert 'valid' even though the 'last' beat was just popped.
        -- However the further conditions for assigning 'read_valid_ram' are pessimistic in this
        -- regard and will not let anything through in this scenario.
        -- Hence we can save a little bit of LUTs here.
        read_valid_ram_pre <= to_sl(num_lasts_in_fifo /= 0);

        -- This is only needed in this specific mode.
        unsure_if_we_have_full_packet_p1 <= unsure_if_we_have_full_packet;
      else
        -- Look at 'num_lasts_in_fifo_next' to see if we actually have a full packet in the
        -- the RAM.
        -- Note that the read that pops the 'last' word might just have happened,
        -- hence we can not look at the registered 'num_lasts_in_fifo'.
        read_valid_ram_pre <= to_sl(num_lasts_in_fifo_next /= 0);
      end if;

      num_lasts_in_fifo <= num_lasts_in_fifo_next;
    else
      -- Note that 'write_addr' is pipelined one step, so we know that the data has propagated
      -- through the RAM to the read side.
      read_valid_ram_pre <= to_sl(read_addr_next /= write_addr);
    end if;

    -- Note that write_ready looks at the write_addr_next that will be used if there is
    -- no packet drop, even when drop_packet functionality is enabled. This is done to ease the
    -- timing of write_ready which is often critical.
    -- There is a functional difference only in the special case when the FIFO
    -- goes full in the same cycle as drop_packet is sent. In that case, write_ready will be low
    -- for one cycle and then go high the next.
    --
    -- Similarly write_ready looks at read_addr rather than read_addr_next, which eases the timing
    -- of read_ready_ram. There is a function difference when the FIFO is full and a read performed
    -- makes the FIFO ready for another write. In this case, write_ready will be low
    -- for one extra cycle after the read occurs, and then go high the next.
    write_ready <= to_sl(
      read_addr(bram_addr_range) /= write_addr_next_if_not_drop(bram_addr_range)
      or read_addr(read_addr'high) =  write_addr_next_if_not_drop(write_addr_next'high));

    if enable_drop_packet then
      if write_ready and write_valid and write_last and not should_drop_packet then
        write_addr_start_of_packet <= write_addr_next;
      end if;
    end if;

    -- These signals however must have the updated values to be valid for the next cycle.
    write_addr <= write_addr_next;

    if enable_peek_mode then
      -- In peek mode we maintain two addresses for read. The 'read_addr' points to where the
      -- current packet starts. This is the address that affects 'write_ready', so that data that
      -- is not yet popped may not be overwritten.
      -- The read_addr_peek is the address that controls where we read in the memory.
      -- This one can be ahead of 'read_addr' and will revert back to 'read_addr' once the whole
      -- packet has been read out.
      read_addr_peek <= read_addr_next;

      if not read_peek_mode then
        -- If not peek reading, the read address shall be updated as normal.
        read_addr <= read_addr_next;
      end if;
    else
      read_addr <= read_addr_next;
    end if;

    -- Keep track of if there is a word in the output register, if it is included
    if enable_output_register then
      word_in_output_register_next :=
        word_in_output_register
        -- One word is added on handshake on the input
        + to_int(read_ready_ram and read_valid_ram)
        -- And one word is removed on handshake on the output
        - to_int(read_ready and read_valid);

      word_in_output_register <= word_in_output_register_next;
    end if;

    -- The level count shall always be correct, and hence uses the updated values. Note that this
    -- can create some wonky situations, e.g. when level read as 1023 for a 1024 deep FIFO
    -- but write_ready is false.
    -- Also in packet_mode, the level is incremented for words that might be dropped later.
    level <=
      (to_integer(write_addr_next - read_addr_next) mod (2 * memory_depth))
      + word_in_output_register_next;

  end process;


  write_addr_next_if_not_drop <= write_addr + to_int(write_ready and write_valid);
  write_addr_next <=
    write_addr_start_of_packet when should_drop_packet else write_addr_next_if_not_drop;


  ------------------------------------------------------------------------------
  read_addr_calc : if enable_peek_mode generate

    ------------------------------------------------------------------------------
    calc_peek_addr : process(all)
    begin
      if read_ready_ram and read_valid_ram then
        if read_last_ram and read_peek_mode then
          -- Go back to where the packet we just read out started, so it can be read again
          read_addr_next <= read_addr;
        else
          read_addr_next <= read_addr_peek + 1;
        end if;
      else
        read_addr_next <= read_addr_peek;
      end if;
    end process;

  else generate

    read_addr_next <= read_addr + to_int(read_ready_ram and read_valid_ram);

  end generate;


  -- When output register is enabled in packet mode, it is very hard to keep track
  -- of how many 'last's we have, in the RAM or in the output register.
  -- The 'unsure_if_we_have_full_packet' signals, which are only assigned in that specific mode,
  -- help out with this.
  read_valid_ram <= (
    read_valid_ram_pre
    and (not unsure_if_we_have_full_packet)
    and (not unsure_if_we_have_full_packet_p1)
  );


  ------------------------------------------------------------------------------
  set_full_packet_status : if enable_output_register and enable_packet_mode generate

    -- Pessimistic estimation of whether we have a full packet, either
    -- * fully in RAM, or
    -- * partially in RAM with one word in output register, or
    -- * packet of length one fully in output register.
    --
    -- This is all needed due to the fact that we cant utilize 'read_last_ram' since that would
    -- make usage of RAM output register impossible.
    --
    -- There is a tradeoff between LUT, FF, logic depth, and write->read_valid latency going
    -- on here.
    -- We could save some logic depth by making this assignment clocked and changing the
    -- relation to "<= 2".
    -- This would however increase the latency, and the improvement in logic depth was very
    -- marginal.
    -- We could also assign 'num_lasts_in_fifo' combinatorially, which would save FF.
    -- This however resulted in horribly bad logic depth.
    unsure_if_we_have_full_packet <= (
      read_ready
      and read_valid
      and read_last
      and to_sl(num_lasts_in_fifo <= 1)
    );

  end generate;


  ------------------------------------------------------------------------------
  memory_block : block
    constant memory_word_width : positive := width + to_int(enable_last);
    subtype word_t is std_ulogic_vector(memory_word_width - 1 downto 0);
    type mem_t is array (natural range <>) of word_t;

    signal mem : mem_t(0 to memory_depth - 1) := (others => (others => '0'));
    attribute ram_style of mem : signal is to_attribute(ram_type);

    signal memory_read_data, memory_write_data : word_t := (others => '0');
  begin

    read_data_ram <= memory_read_data(read_data_ram'range);
    memory_write_data(write_data'range) <= write_data;


    ------------------------------------------------------------------------------
    assign_data : if enable_last generate
      read_last_ram <= memory_read_data(memory_read_data'high);
      memory_write_data(memory_write_data'high) <= write_last;
    end generate;


    ------------------------------------------------------------------------------
    memory : process
    begin
      wait until rising_edge(clk);

      memory_read_data <= mem(to_integer(read_addr_next) mod memory_depth);

      if write_ready and write_valid then
        mem(to_integer(write_addr) mod memory_depth) <= memory_write_data;
      end if;
    end process;

  end block;


  ------------------------------------------------------------------------------
  handshake_pipeline : entity common.handshake_pipeline
    generic map (
      data_width => width,
      full_throughput => true,
      pipeline_control_signals => false,
      -- A pipeline stage will only be added if enable_output_register is true
      -- otherwise this will be a simple route-through
      pipeline_data_signals => enable_output_register
    )
    port map (
      clk => clk,
      --
      input_ready => read_ready_ram,
      input_valid => read_valid_ram,
      input_last => read_last_ram,
      input_data => read_data_ram,
      --
      output_ready => read_ready,
      output_valid => read_valid,
      output_last => read_last,
      output_data => read_data
    );

end architecture;
