-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the tsfpga project.
-- https://tsfpga.com
-- https://gitlab.com/tsfpga/tsfpga
-- -------------------------------------------------------------------------------------------------
-- Synchronous FIFO.
--
-- This FIFO implementation has an optional "peek read" mode that is enabled by setting the
-- enable_peek_mode generic. It makes it possible to read a packet multiple times.
-- If the read_peek_mode signal is asserted when read_ready is asserted, the current packet will
-- not be popped from the FIFO, but can instead be read again. Once the readout encounters
-- read_last, the readout will return again to the first word of the packet.
-- Note that the read_peek_mode value may not be changed during the readout of a packet.
-- It must be static for all words in a packet, but may be updated after read_last.
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
    almost_full_level : integer range 0 to depth := depth;
    almost_empty_level : integer range 0 to depth := 0;
    -- Set to true in order to use read_last and write_last
    enable_last : boolean := false;
    -- If enabled, read_valid will not be asserted until a full packet is available in
    -- FIFO. I.e. when write_last has been received. Must set enable_last as well to use this.
    enable_packet_mode : boolean := false;
    -- Set to true in order to use the drop_packet port. Must set enable_packet_mode as
    -- well to use this.
    enable_drop_packet : boolean := false;
    -- Set to true in order to read words without popping from FIFO using the read_peek_mode port.
    -- Must set enable_packet_mode as well to use this.
    enable_peek_mode : boolean := false;
    -- Select what FPGA primitives will be used to implement the FIFO memory.
    ram_type : ram_style_t := ram_style_auto
  );
  port (
    clk : in std_logic;
    -- When packet_mode is enabled, this value will still reflect the number of words that are in
    -- the FIFO RAM. This is not necessarily the same as the number of words that can be read, in
    -- this mode.
    level : out integer range 0 to depth := 0;

    read_ready : in std_logic;
    -- '1' if FIFO is not empty
    read_valid : out std_logic := '0';
    read_data : out std_logic_vector(width - 1 downto 0) := (others => '0');
    -- Must set enable_last generic in order to use this
    read_last : out std_logic := '0';
    -- When this is asserted, packets can be read multiple times from the FIFO.
    -- Must set enable_peek_mode generic in order to use this.
    read_peek_mode : in std_logic := '0';
    -- '1' if there are almost_empty_level or fewer words available to read
    almost_empty : out std_logic := '1';

    -- '1' if FIFO is not full
    write_ready : out std_logic := '1';
    write_valid : in std_logic;
    write_data : in std_logic_vector(width - 1 downto 0);
    -- Must set enable_last generic in order to use this
    write_last : in std_logic := '-';
    -- '1' if there are almost_full_level or more words available in the FIFO
    almost_full : out std_logic := '0';
    -- Drop the current packet (all words that have been writen since the previous write_last).
    -- Must set enable_drop_packet generic in order to use this.
    drop_packet : in std_logic := '0'
  );
end entity;

architecture a of fifo is

  -- Need one extra bit in the addresses to be able to make the distinction if the FIFO
  -- is full or empty (where the addresses would otherwise be equal).
  subtype fifo_addr_t is unsigned(num_bits_needed(2 * depth - 1) - 1 downto 0);
  signal read_addr_next, read_addr, read_addr_peek : fifo_addr_t := (others => '0');
  signal write_addr_next, write_addr, write_addr_next_if_not_drop, write_addr_start_of_packet :
    fifo_addr_t := (others => '0');

  -- The part of the address that actually goes to the BRAM address port
  subtype bram_addr_range is integer range num_bits_needed(depth - 1) - 1 downto 0;

  signal num_lasts_in_fifo : integer range 0 to depth := 0;

  signal should_drop_packet, should_peek_read : std_logic := '0';

begin

  assert is_power_of_two(depth) report "Depth must be a power of two" severity failure;

  assert enable_last or (not enable_packet_mode)
    report "Must set enable_last for packet mode" severity failure;
  assert enable_packet_mode or (not enable_drop_packet)
    report "Must set enable_packet_mode for drop packet support" severity failure;
  assert enable_packet_mode or (not enable_peek_mode)
    report "Must set enable_packet_mode for peek mode support" severity failure;


  -- These flags will update one cycle after the write/read that puts them over/below the line.
  -- Except for the fringe cases:
  --
  -- When almost_full_level is 'depth' and a read puts it below the line there will be a two
  -- cycle latency. For a write that puts it above the line there is always one cycle latency.
  --
  -- When almost_empty_level is zero and a write puts it over the line there will be a two
  -- cycle latency. For a read that puts it below the line there is always one cycle latency.

  assign_almost_full : if almost_full_level = depth generate
    almost_full <= not write_ready;
  else generate
    almost_full <= to_sl(level > almost_full_level - 1);
  end generate;

  assign_almost_empty : if almost_empty_level = 0 generate
    almost_empty <= not read_valid;
  else generate
    almost_empty <= to_sl(level < almost_empty_level + 1);
  end generate;

  should_drop_packet <= to_sl(enable_drop_packet) and drop_packet;
  should_peek_read <= to_sl(enable_peek_mode) and read_peek_mode;


  ------------------------------------------------------------------------------
  status : process
    variable num_lasts_in_fifo_next : integer range 0 to depth := 0;
  begin
    wait until rising_edge(clk);

    if enable_packet_mode then
      num_lasts_in_fifo_next := num_lasts_in_fifo
        + to_int(write_ready and write_valid and write_last and not should_drop_packet)
        - to_int(read_ready and read_valid and read_last and not should_peek_read);

      -- We look at num_lasts_in_fifo_next since we need to update read_valid the same cycle when
      -- the read happens.
      -- We also look at num_lasts_in_fifo since a write needs an additional clock
      -- cycle to propagate into the RAM. This is really only needed when the FIFO is empty and
      -- a packet of length one is written. With this condition, there will be a two cycle latency
      -- from write_last being written to read_valid being asserted.
      read_valid <= to_sl(num_lasts_in_fifo /= 0 and num_lasts_in_fifo_next /= 0);
      num_lasts_in_fifo <= num_lasts_in_fifo_next;
    else
      read_valid <= to_sl(read_addr_next /= write_addr);
    end if;

    -- Note that write_ready looks at the write_addr_next that will be used if there is
    -- no packet drop, even when drop_packet functionality is enabled. This is done to ease the
    -- timing of write_ready which is often critical.
    -- There is a functional difference only in the special case when the FIFO
    -- goes full in the same cycle as drop_packet is sent. In that case, write_ready will be low
    -- for one cycle and then go high the next.
    --
    -- Similarly write_ready looks at read_addr rather than read_addr_next, which eases the timing
    -- of read_ready. There is a function difference when the FIFO is full and a read performed
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

    -- The level count shall always be correct, and hence uses the updated values. Note that this
    -- can create some wonky situations, e.g. when level read as 1023 for a 1024 deep FIFO
    -- but write_ready is false.
    -- Also in packet_mode, the level is incremented for words that might be dropped later.
    level <= to_integer(write_addr_next - read_addr_next) mod (2 * depth);
  end process;


  write_addr_next_if_not_drop <= write_addr + to_int(write_ready and write_valid);
  write_addr_next <=
    write_addr_start_of_packet when should_drop_packet else write_addr_next_if_not_drop;


  ------------------------------------------------------------------------------
  read_addr_calc : if enable_peek_mode generate

    ------------------------------------------------------------------------------
    calc_peek_addr : process(all)
    begin
      if read_ready and read_valid then
        if read_last and read_peek_mode then
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

    read_addr_next <= read_addr + to_int(read_ready and read_valid);

  end generate;


  ------------------------------------------------------------------------------
  memory_block : block
    constant memory_word_width : integer := width + to_int(enable_last);
    subtype word_t is std_logic_vector(memory_word_width - 1 downto 0);
    type mem_t is array (integer range <>) of word_t;

    signal mem : mem_t(0 to depth - 1) := (others => (others => '0'));
    attribute ram_style of mem : signal is to_attribute(ram_type);

    signal memory_read_data, memory_write_data : word_t := (others => '0');
  begin

    read_data <= memory_read_data(read_data'range);
    memory_write_data(write_data'range) <= write_data;

    assign_data : if enable_last generate
      read_last <= memory_read_data(memory_read_data'high);
      memory_write_data(memory_write_data'high) <= write_last;
    end generate;

    memory : process
    begin
      wait until rising_edge(clk);

      memory_read_data <= mem(to_integer(read_addr_next) mod depth);

      if write_ready and write_valid then
        mem(to_integer(write_addr) mod depth) <= memory_write_data;
      end if;
    end process;
  end block;


  ------------------------------------------------------------------------------
  psl_block : block
    signal first_cycle : std_logic := '1';
    signal fill_level : unsigned(read_addr'range);
  begin

    fill_level <= write_addr - read_addr;

    ctrl : process
    begin
      wait until rising_edge(clk);
      first_cycle <= '0';
    end process;

    -- psl default clock is rising_edge(clk);
    --
    -- psl level_port_same_as_fill_level : assert always
    --   level = fill_level;
    --
    -- Constrains start state of read_addr and write_addr to be valid.
    -- psl level_within_range : assert always
    --   fill_level <= depth;
    --
    -- To constrain start state. Otherwise read_valid can start as one, and a read
    -- transaction occur, despite FIFO being empty.
    -- psl not_read_valid_unless_data_in_fifo : assert always
    --   not (read_valid = '1' and level = 0);
    --
    -- psl write_ready_false_if_full : assert always
    --   level = depth -> not write_ready;
    --
    -- Latency since data must propagate through BRAM.
    -- psl read_valid_goes_high_two_cycles_after_write : assert always
    --   (write_valid and write_ready) -> next[2] (read_valid);
    --
    -- psl read_valid_stays_high_until_read_ready : assert always
    --   (read_valid) -> (read_valid) until (read_ready);
    --
    -- psl read_data_should_be_stable_until_handshake_transaction : assert always
    --   (not first_cycle) and prev(read_valid and not read_ready) -> stable(read_data);
    --
    -- psl read_last_should_be_stable_until_handshake_transaction : assert always
    --   (not first_cycle) and prev(read_valid and not read_ready) -> stable(read_last);
    --
    -- psl read_valid_may_fall_only_after_handshake_transaction : assert always
    --   first_cycle = '0' and fell(read_valid) -> prev(read_ready);
    --
    -- psl level_should_stay_the_same_if_there_is_both_read_and_write : assert always
    --   {level = 2 and (read_ready and read_valid and write_ready and write_valid) = '1'}
    --     |=> level = 2;
    --
    -- psl level_should_decrease_cycle_after_read_if_there_is_no_write : assert always
    --   {level = 2 and (read_ready and read_valid and not write_valid) = '1'} |=> level = 1;
    --
    -- psl level_should_increase_cycle_after_write_if_there_is_no_read : assert always
    --   {level = 2 and (write_ready and write_valid and not read_ready) = '1'} |=> level = 3;

    -- The formal verification flow doesn't handle generics very well, so the
    -- check below is only done if the depth is 4.
    gen_if_depth_4 : if depth = 4 generate
    begin
      -- Check that write_ready is deasserted after 4 consecutive writes
      -- without reads.
      -- psl assert always
      --       {(write_valid and not read_ready)}[*4] |=> (not write_ready);
    end generate;
  end block;

end architecture;
