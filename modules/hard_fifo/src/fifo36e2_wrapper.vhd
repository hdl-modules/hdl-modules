-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the hdl-modules project, a collection of reusable, high-quality,
-- peer-reviewed VHDL building blocks.
-- https://hdl-modules.com
-- https://github.com/hdl-modules/hdl-modules
-- -------------------------------------------------------------------------------------------------
-- Wrapper around the Xilinx UltraScale+ FIFO36E2 primitive, with convenient AXI-Stream-like
-- interface.
--
-- .. note::
--   The ``almost_full`` / ``almost_empty`` signals from the FIFO seem to work well. They are not
--   routed out at the moment since they do not have a simulation test case.
--
-- .. warning::
--   The ``level`` signal from the FIFO is not routed either.
--   This is because there appears to be glitches in the read/write count signals:
--
--   .. image:: fifo_glitches.png
--
--   Hopefully this is only an issue with the ``unisim`` simulation model, and works
--   correctly in the hardware.
-- -------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library unisim;
use unisim.vcomponents.all;

use work.hard_fifo_pkg.all;


entity fifo36e2_wrapper is
  generic (
    data_width : positive;
    is_asynchronous : boolean;
    enable_output_register : boolean
  );
  port (
    clk_read : in std_ulogic;
    read_ready : in std_ulogic;
    read_valid : out std_ulogic := '0';
    read_data : out std_ulogic_vector(data_width - 1 downto 0) := (others => '0');
    --# {{}}
    clk_write : in std_ulogic;
    write_ready : out std_ulogic := '0';
    write_valid : in std_ulogic;
    write_data : in std_ulogic_vector(data_width - 1 downto 0)
  );
end entity;

architecture a of fifo36e2_wrapper is

  constant fifo_width : positive := get_fifo_width(target_width=>data_width);
  constant fifo_depth : positive := get_fifo_depth(target_width=>data_width);

  -- Get value for the CLOCK_DOMAINS generic
  impure function get_clock_domains return string is
  begin
    if is_asynchronous then
      return "INDEPENDENT";
    end if;
    return "COMMON";
  end function;

  -- Get value for the REGISTER_MODE generic
  impure function get_register_mode return string is
  begin
    if enable_output_register then
      return "REGISTERED";
    end if;

    -- There is also a "DO_PIPELINE" option
    return "UNREGISTERED";
  end function;

  -- When wider than eight, one bit per byte is stored via the data parity port
  constant parity_port_width : natural := fifo_width / 9;
  constant data_port_width : positive := write_data'length - parity_port_width;

  -- Self-reset the circuit with an SRL
  signal reset_pipe : std_ulogic_vector(0 to 16 - 1) := (others => '1');
  signal reset : std_ulogic := '1';

  signal full, empty, wren, rden, wrerr, rderr, almost_full, almost_empty : std_ulogic := '0';
  signal din, dout : std_ulogic_vector(64 - 1 downto 0) := (others => '0');
  signal dinp, doutp : std_ulogic_vector(8 - 1 downto 0) := (others => '0');

  -- These seem to work well. Add generic, route these to ports and add test when there is a
  -- use case
  constant almost_full_level : positive range 1 to fifo_depth := 1;
  constant almost_empty_level : positive range 1 to fifo_depth := 1;

  -- When simulating there are glitches in the level signals.
  -- Hopefully/probably this is only an issue with the unisim simulation model, and works
  -- correctly in the hardware.
  signal wrcount, rdcount : std_ulogic_vector(14 - 1 downto 0) := (others => '0');
  signal read_level, write_level : natural range 0 to get_fifo_depth(target_width=>data_width) := 0;

begin

  assert almost_full_level <= fifo_depth
    report "Almost full level (" & integer'image(almost_full_level)
    & ") greater than depth (" & integer'image(fifo_depth) & ")"
    severity failure;

  assert almost_empty_level <= fifo_depth
    report "Almost empty level (" & integer'image(almost_empty_level)
    & ") greater than depth (" & integer'image(fifo_depth) & ")"
    severity failure;


  ------------------------------------------------------------------------------
  reset_proc : process
  begin
    -- UG473 figure 2-2 indicates that when in dual clock mode, the reset shall be driven by
    -- write clock. Also UG974 page 293.
    wait until rising_edge(clk_write);

    reset_pipe <= '0' & reset_pipe(reset_pipe'left to reset_pipe'right - 1);
  end process;

  reset <= reset_pipe(reset_pipe'right);


  ------------------------------------------------------------------------------
  write_assertions : process
  begin
    wait until rising_edge(clk_write);

    assert not wrerr report "Write while in reset or write to full FIFO";
  end process;


  ------------------------------------------------------------------------------
  read_assertions : process
  begin
    wait until rising_edge(clk_read);

    assert not rderr report "Read while in reset or read from empty FIFO";
  end process;


  ------------------------------------------------------------------------------
  FIFO36E2_inst : FIFO36E2
    generic map (
      CLOCK_DOMAINS => get_clock_domains,
      FIRST_WORD_FALL_THROUGH => "TRUE",
      PROG_EMPTY_THRESH => almost_empty_level,
      PROG_FULL_THRESH => almost_full_level,
      -- "EXTENDED_DATACOUNT", "RAW_PNTR", "SIMPLE_DATACOUNT", or "SYNC_PNTR"
      RDCOUNT_TYPE => "SIMPLE_DATACOUNT",
      READ_WIDTH => fifo_width,
      REGISTER_MODE => get_register_mode,
      WRCOUNT_TYPE => "SIMPLE_DATACOUNT",
      WRITE_WIDTH => fifo_width
    )
    port map (
      -- Only used when CASCADE_ORDER generic is set
      CASDIN => (others => '0'),
      CASDINP => (others => '0'),
      CASDOMUX => '0',
      CASDOMUXEN => '0',
      CASNXTRDEN => '0',
      CASOREGIMUX => '0',
      CASOREGIMUXEN => '0',
      CASPRVEMPTY => '0',

      DIN => din,
      DINP => dinp,
      DOUT => dout,
      DOUTP => doutp,
      EMPTY => empty,
      FULL => full,
      INJECTDBITERR => '0',
      INJECTSBITERR => '0',
      PROGEMPTY => almost_empty,
      PROGFULL => almost_full,
      RDCLK => clk_read,
      RDCOUNT => rdcount,
      RDEN => rden,
      RDERR => rderr,
      -- Not really sure what this signal is. The handshaking works properly with this static
      -- setting, both when output register is disabled and enabled.
      REGCE => '1',
      RST => reset,
      RSTREG => reset,
      SLEEP => '0',
      WRCLK => clk_write,
      WRCOUNT => wrcount,
      wren => wren,
      wrerr => wrerr
    );


  -- At this point I am not sure what would happen if we "read" from an empty FIFO (as we can in
  -- AXI-Stream). So for now we expend one LUT per control signal to guard from this.
  rden <= read_ready and not empty;

  read_valid <= not empty;

  write_ready <= not (full or reset);

  wren <= write_ready and write_valid;


  ------------------------------------------------------------------------------
  assign_data : process(all)
  begin
    din(data_port_width - 1 downto 0) <= write_data(data_port_width - 1 downto 0);
    dinp(parity_port_width - 1 downto 0) <=
      write_data(write_data'high downto write_data'length - parity_port_width);

    read_data(data_port_width - 1 downto 0) <= dout(data_port_width - 1 downto 0);
    read_data(read_data'high downto read_data'length - parity_port_width) <=
      doutp(parity_port_width - 1 downto 0);
  end process;


  ------------------------------------------------------------------------------
  read_level <= to_integer(unsigned(rdcount));

  write_level <= to_integer(unsigned(wrcount));

end architecture;
