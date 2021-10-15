-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the tsfpga project.
-- https://tsfpga.com
-- https://gitlab.com/tsfpga/tsfpga
-- -------------------------------------------------------------------------------------------------
-- Width conversion of a data bus. Can handle downconversion (wide to thin) or upconversion (thin
-- to wide). The data widths must be a power-of-two multiple of each other. E.g. 10->40 is
-- supported while 8->24 is not.
--
-- There is a generic to enable usage of the 'last' signal. The 'last' indicator will be passed
-- along with the data from the 'input' to 'output' side as-is. Note that enabling
-- 'support_unaligned_burst_length' generic will enable further processing of 'last', but in
-- barebone configuration the signal is merely passed on.
--
-- There is a generic to enable strobing of data. The 'strobe' will be passed on from
-- 'input' to 'output' side as-is. Note that enabling 'support_unaligned_burst_length' generic will
-- enable further processing of 'strobe', but in barebone configuration the signal is merely
-- passed on. This means, for example, that there might be output words where all strobe lanes are
-- zero when downconverting.
--
-- There are some limitations, and possible remedies, concerning burst length alignment, depending
-- on if we are doing upconversion or downconversion:
--
-- Downconversion
--
-- When doing downconversion, one input beat will result in two or more output beats, depending
-- on width configuration. This means that the output burst length is always aligned with the input
-- data width. This is not always desirable when working with the 'strobe' and 'last' signals.
-- Say for example that we are converting a bus from 16 to 8, and 'input_last' is asserted on a
-- beat where the lowest byte is strobed but the highest is not. In this case, we would want
-- 'output_last' to be asserted on the second to last byte, and the last byte (which is strobed out)
-- to be removed. This is achieved by enabling the 'support_unaligned_burst_length' generic.
-- If the generic is not set, 'output_last' will be asserted on the very last byte, which will
-- be strobed out.
--
-- Upconversion
--
-- When upconverting, two or more 'input' beats result in one 'output' beat, depending on width
-- configuration. This means that the input burst length must be aligned with the output width,
-- so that each burst fills up a whole number of output words.
-- If this can not be guaranteed, then the 'support_unaligned_burst_length' mode can be used.
-- When that is enabled, the input stream will be padded upon 'last' indication so that a whole
-- output word is filled.
-- Consider the example of converting a bus from 8 to 16, and 'input' last is asserted on the
-- third input beat. If 'support_unaligned_burst_length' is disabled, there will be one output beat
-- sent and half an output beat left in the converter.
-- If the mode is enabled however, the input stream will be padded with another byte so that an
-- output beat can be sent. The padded parts will have 'strobe' set to zero.
--
-- Note that the handling of unaligned bursts is highly dependent on the input stream being well
-- behaved. Specifically
--
--   1. There may never be input beats where 'input_strobe' is all zeros.
--   2. For all beats except the one where 'input_last' is asserted, 'input_strobe' must be
--      asserted on all lanes.
-- -------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.types_pkg.all;


entity width_conversion is
  generic (
    input_width : positive;
    output_width : positive;
    -- Enable usage of the 'input_last' and 'output_last' ports.
    -- Will increase the logic footprint.
    enable_last : boolean := false;
    -- Enable usage of the 'input_strobe' and 'output_strobe' ports.
    -- Will increase the logic footprint.
    enable_strobe : boolean := false;
    -- In the typical use case where we want a "byte strobe", this would be eight.
    -- In other cases, for example when the data is packed, we migh use a higher value.
    -- Must assign a valid value if 'enable_strobe' is true.
    strobe_unit_width : positive := 8;
    -- Enable if 'input' burst lengths are not a multiple of the 'output' width.
    -- Must set 'enable_strobe' and 'enable_last' as well to use this.
    -- See header for details about how this works.
    -- Will increase the logic footprint.
    support_unaligned_burst_length : boolean := false
  );
  port (
    clk : in std_logic;
    --
    input_ready : out std_logic := '1';
    input_valid : in std_logic;
    -- Optional packet burst 'last' signalling. Must set 'enable_last' generic in order to use this.
    input_last : in std_logic := '0';
    input_data : in std_logic_vector(input_width - 1 downto 0);
    -- Optional word strobe. Must set 'enable_strobe' generic in order to use this.
    input_strobe : in std_logic_vector(input_width / strobe_unit_width - 1 downto 0) :=
      (others => '1');
    --
    output_ready : in std_logic;
    output_valid : out std_logic := '0';
    -- Optional packet burst 'last' signalling. Must set 'enable_last' generic in order to use this.
    output_last : out std_logic := '0';
    output_data : out std_logic_vector(output_width - 1 downto 0) := (others => '0');
    -- Optional word strobe. Must set 'enable_strobe' generic in order to use this.
    output_strobe : out std_logic_vector(output_width / strobe_unit_width - 1 downto 0) :=
      (others => '1')
  );
end entity;

architecture a of width_conversion is

  constant is_upconversion : boolean := input_width < output_width;
  constant is_downconversion : boolean := input_width > output_width;

  function get_atom_data_width return positive is
  begin
    if support_unaligned_burst_length then
      -- When in 'unaligned' mode we handle each strobe unit separately, and can not take advantage
      -- of a coarser indexing.
      return strobe_unit_width;
    end if;

    -- When converting e.g. 16->32 the data atom that is handled internally will be of width 16.
    -- This gives lower resource utilization than if it was e.g. always 8.
    return minimum(input_width, output_width);
  end function;
  constant atom_data_width : positive := get_atom_data_width;
  constant atom_strobe_width : positive := atom_data_width / strobe_unit_width;

  subtype atom_data_t is std_logic_vector(atom_data_width - 1 downto 0);
  subtype atom_strobe_t is std_logic_vector(atom_strobe_width - 1 downto 0);

  constant num_atoms_per_input : positive := input_width / atom_data_width;
  constant num_atoms_per_output : positive := output_width / atom_data_width;

  constant packed_atom_width : positive :=
    atom_data_width + to_int(enable_last) + to_int(enable_strobe) * atom_strobe_width;
  subtype packed_atom_t is std_logic_vector(packed_atom_width - 1 downto 0);

  constant stored_atom_count_max : positive := num_atoms_per_input + num_atoms_per_output;
  constant shift_reg_length : positive := stored_atom_count_max * packed_atom_width;
  signal shift_reg : std_logic_vector(shift_reg_length - 1 downto 0) := (others => '0');

  signal num_atoms_stored : natural range 0 to stored_atom_count_max := 0;

  impure function pack(
    atom_data : atom_data_t;
    atom_strobe : atom_strobe_t;
    atom_last : std_logic
  ) return std_logic_vector is
    variable result : packed_atom_t := (others => '0');
    variable hi, lo : natural := 0;
  begin
    hi := atom_data'length - 1;
    result(hi downto lo) := atom_data;

    if enable_strobe then
      -- Could be more than one bit
      lo := hi + 1;
      hi := lo + atom_strobe'length - 1;
      result(hi downto lo) := atom_strobe;
    end if;

    if enable_last then
      -- Only one bit
      hi := hi + 1;
      result(hi) := atom_last;
    end if;

    assert hi = result'high report "Something wrong with widths" severity failure;

    return result;
  end function;

  procedure unpack(
    packed : in packed_atom_t;
    atom_data : out atom_data_t;
    atom_strobe : out atom_strobe_t;
    atom_last : out std_logic
  ) is
    variable hi, lo : natural := 0;
  begin
    hi := atom_data'length - 1;
    atom_data := packed(hi downto lo);

    if enable_strobe then
      -- Could be more than one bit
      lo := hi + 1;
      hi := lo + atom_strobe'length - 1;
      atom_strobe := packed(hi downto lo);
    end if;

    if enable_last then
      -- Only one bit
      hi := hi + 1;
      atom_last := packed(hi);
    end if;

    assert hi = packed'high report "Something wrong with widths" severity failure;
  end procedure;

  signal padded_input_ready, padded_input_valid, padded_input_last : std_logic := '0';
  signal padded_input_data : std_logic_vector(input_data'range) := (others => '0');
  signal padded_input_strobe : std_logic_vector(input_strobe'range) := (others => '0');

  signal output_ready_int, output_valid_int, output_last_int : std_logic := '0';
  signal output_strobe_int : std_logic_vector(output_strobe'range) := (others => '0');

begin

  ------------------------------------------------------------------------------
  assert input_width /= output_width
    report "Do not use this module with equal widths" severity failure;

  assert input_width mod output_width = 0 or output_width mod input_width = 0
    report "Larger width has to be multiple of smaller." severity failure;

  assert (output_width / input_width) mod 2 = 0 and (input_width / output_width) mod 2 = 0
    report "Larger width has to be power of two multiple of smaller." severity failure;

  assert
    (not enable_strobe)
    or (input_width mod strobe_unit_width = 0 and output_width mod strobe_unit_width = 0)
    report "Data width must be a multiple of strobe unit width." severity failure;

  assert enable_strobe or not support_unaligned_burst_length
    report "Must enable strobing when doing unaligned bursts." severity failure;

  assert enable_last or not support_unaligned_burst_length
    report "Must enable 'last' when doing unaligned bursts." severity failure;


  ------------------------------------------------------------------------------
  pad_input_data_generate : if is_upconversion and support_unaligned_burst_length generate

    type state_t is (let_data_pass, send_padding);
    signal state : state_t := let_data_pass;

    constant input_beats_per_output_beat : natural := output_width / input_width;
    signal beats_filled : natural range 0 to input_beats_per_output_beat - 1 := 0;

  begin

    ------------------------------------------------------------------------------
    assign : process(all)
    begin
      padded_input_data <= input_data;
      -- 'last' when in padding state does not matter.
      -- When in this unaligned mode, 'output_last' is set by OR'ing  the 'last' for each atom.
      padded_input_last <= input_last;

      if state = let_data_pass then

        -- Passthrough.
        input_ready <= padded_input_ready;
        padded_input_valid <= input_valid;
        padded_input_strobe <= input_strobe;

      else

        -- send_padding
        input_ready <= '0';
        padded_input_valid <= '1';
        padded_input_strobe <= (others => '0');

      end if;
    end process;


    ------------------------------------------------------------------------------
    pad_input_data : process
    begin
      wait until rising_edge(clk) and support_unaligned_burst_length;

      if padded_input_ready and padded_input_valid then
        beats_filled <= (beats_filled + 1) mod input_beats_per_output_beat;
      end if;

      case state is
        when let_data_pass =>
          if (
            padded_input_ready = '1'
            and padded_input_valid = '1'
            and padded_input_last = '1'
            and beats_filled /= input_beats_per_output_beat - 1
          ) then
            state <= send_padding;
          end if;

        when send_padding =>
          if padded_input_ready and padded_input_valid then
            if beats_filled = input_beats_per_output_beat - 1 then
              -- This transaction fills the last atom(s) needed for a whole output beat
              state <= let_data_pass;
            end if;
          end if;

      end case;
    end process;

  else generate

    -- Passthrough.
    input_ready <= padded_input_ready;
    padded_input_valid <= input_valid;
    padded_input_last <= input_last;
    padded_input_data <= input_data;
    padded_input_strobe <= input_strobe;

  end generate;


  ------------------------------------------------------------------------------
  main : process
    variable num_atoms_next : natural range 0 to stored_atom_count_max;

    variable atom_data : atom_data_t := (others => '0');
    variable atom_strobe : atom_strobe_t := (others => '0');
    variable atom_last : std_logic := '0';

    variable atom_idx_to_write_last : natural range 0 to num_atoms_per_input - 1 :=
      num_atoms_per_input - 1;

    variable packed_data_to_shift_in : packed_atom_t := (others => '0');
    variable shift_reg_next : std_logic_vector(shift_reg'range) := (others => '0');
  begin
    wait until rising_edge(clk);

    num_atoms_next := num_atoms_stored;

    shift_reg_next := shift_reg;
    if padded_input_ready and padded_input_valid then
      if is_downconversion and support_unaligned_burst_length then
        -- In this mode we have to put the 'last' indicator on the very last atom that is strobed.
        -- Atoms beyond that one will be stripped on the output.
        -- In other modes, the default value constant will be used for this variable.
        -- Note also that when in 'unaligned' mode, the atom is always the strobe unit.
        -- Hence this indexing from strobe lane index to atom index works.
        atom_idx_to_write_last := count_ones(padded_input_strobe) - 1;
      end if;

      num_atoms_next := num_atoms_next + num_atoms_per_input;

      for input_atom_idx in 0 to num_atoms_per_input - 1 loop
        -- Set 'last' only on the last strobed atom of the input word
        -- (constant unless in 'unaligned' mode)
        if input_atom_idx = atom_idx_to_write_last then
          atom_last := padded_input_last;
        else
          atom_last := '0';
        end if;

        atom_data := padded_input_data(
          (input_atom_idx + 1) * atom_data_width - 1 downto input_atom_idx * atom_data_width
        );

        atom_strobe := padded_input_strobe(
          (input_atom_idx + 1) * atom_strobe_width - 1 downto input_atom_idx * atom_strobe_width
        );

        packed_data_to_shift_in := pack(
          atom_data=>atom_data,
          atom_strobe=>atom_strobe,
          atom_last=>atom_last
        );
        shift_reg_next :=
          packed_data_to_shift_in
          & shift_reg_next(shift_reg_next'left downto packed_data_to_shift_in'length);
      end loop;
    end if;
    shift_reg <= shift_reg_next;

    if output_ready_int and output_valid_int then
      num_atoms_next := num_atoms_next - num_atoms_per_output;
    end if;

    num_atoms_stored <= num_atoms_next;

    output_valid_int <= to_sl(num_atoms_next >= num_atoms_per_output);
  end process;

  padded_input_ready <= to_sl(num_atoms_stored <= stored_atom_count_max - num_atoms_per_input);


  ------------------------------------------------------------------------------
  slice_output : process(all)
    variable output_atoms_base : natural range 0 to stored_atom_count_max := 0;

    variable packed_atom : packed_atom_t := (others => '0');

    variable atoms_last : std_logic_vector(num_atoms_per_output - 1 downto 0) := (others => '0');
    variable atom_data : atom_data_t := (others => '0');
    variable atom_strobe : atom_strobe_t := (others => '0');
  begin

    output_atoms_base := stored_atom_count_max - num_atoms_stored;

    for output_atom_idx in 0 to num_atoms_per_output - 1 loop
      if output_atom_idx < num_atoms_stored then
        packed_atom := shift_reg(
          (output_atoms_base + output_atom_idx + 1) * packed_atom_width - 1
          downto (output_atoms_base + output_atom_idx) * packed_atom_width
        );

        unpack(
          packed=>packed_atom,
          atom_data=>atom_data,
          atom_strobe=>atom_strobe,
          atom_last=>atoms_last(output_atom_idx)
        );

      else

        -- This is just so that the indexing does not go out of range. When the condition for
        -- output_valid is met, we will not end up here for any atom.
        atom_data := (others => '-');
        atom_strobe := (others => '-');
        atoms_last(output_atom_idx) := '-';
      end if;

      output_data(
        (output_atom_idx + 1) * atom_data_width - 1 downto output_atom_idx * atom_data_width
      ) <= atom_data;

      output_strobe_int(
        (output_atom_idx + 1) * atom_strobe_width - 1 downto output_atom_idx * atom_strobe_width
      ) <= atom_strobe;
    end loop;

    if support_unaligned_burst_length then
      -- The top atom might be strobed out and not have 'last' set. Instead it is found in one of
      -- the lower atoms.
      output_last_int <= or atoms_last;
    else
      output_last_int <= atoms_last(atoms_last'high);
    end if;
  end process;


  ------------------------------------------------------------------------------
  strip_output_data_generate : if is_downconversion and support_unaligned_burst_length generate
    signal strobe_all_zero : std_logic_vector(output_strobe'range) := (others => '0');
  begin

    -- The write processing will place 'last' indicator on the last atom that is strobed.
    -- There might come atoms after that, since this is downconversion.
    -- If those atoms add up to an output beat, that is removed here.
    -- This is highly dependent on the input stream being well-behaved.

    ------------------------------------------------------------------------------
    set_output : process(all)
    begin
      -- Pop strobed out words
      output_ready_int <=
        output_ready or (output_valid_int and to_sl(output_strobe_int = strobe_all_zero));

      -- Do not pass on strobed out words
      output_valid <= output_valid_int and to_sl(output_strobe_int /= strobe_all_zero);

      if enable_last then
        output_last <= output_last_int;
      end if;

      if enable_strobe then
        output_strobe <= output_strobe_int;
      end if;
    end process;


  ------------------------------------------------------------------------------
  else generate

    -- Passthrough

    ------------------------------------------------------------------------------
    set_output : process(all)
    begin
      output_ready_int <= output_ready;
      output_valid <= output_valid_int;

      if enable_last then
        output_last <= output_last_int;
      end if;

      if enable_strobe then
        output_strobe <= output_strobe_int;
      end if;
    end process;

  end generate;

end architecture;
