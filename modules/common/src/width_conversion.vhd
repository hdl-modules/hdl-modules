-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the tsfpga project.
-- https://tsfpga.com
-- https://gitlab.com/tsfpga/tsfpga
-- -------------------------------------------------------------------------------------------------
-- Width conversion of a data bus. Can handle downconversion (wide to thin) or upconversion (thin
-- to wide). The data widths must be a power-of-two multiple of each other. E.g. 4->16 is
-- supported while 8->24 is not.
--
-- There is a generic to enable strobing of data. The data and strobe will be passed on from
-- 'input' to 'output' side as is. This means that there might be output words where all strobe
-- lanes are zero.
--
-- We have done some experimentation with removing words that are strobed out, so that they never
-- reach the 'output' side. See comments in code. It increases the resource utilization by a lot,
-- and it is not super clear if it is correct behavior for the common use case.
--
-- When upconverting, the 'input' side burst length must align with the 'output' side data width.
-- If it is not, then the 'input' stream must be padded.
-- Consider the example when converting 32->64, and 'last' is asserted in the third 'input' word.
-- Unless the 'support_unaligned_burst_length' generic is set there will still only be one word sent
-- to the 'output'. If the generic is set, however, the 'input' stream will be padded so that a
-- whole 'output' word is filled. The padded lanes will have their 'strobe' set to zero.
-- -------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.types_pkg.all;


entity width_conversion is
  generic (
    input_width : positive;
    output_width : positive;
    -- Enable usage of the 'input_strobe' and 'output_strobe' ports.
    -- Will increase the logic footprint.
    enable_strobe : boolean := false;
    -- In the typical use case where we want a "byte strobe", this would be set to 8.
    -- In other cases, for example when the data is packed, we migh use a higher value.
    -- Must assign a positive value if 'enable_strobe' is true.
    strobe_unit_width : integer := -1;
    -- Enable if 'input' burst lengths are not a multiple of the 'output' width.
    -- Will increase the logic footprint.
    support_unaligned_burst_length : boolean := false
  );
  port (
    clk : in std_logic;
    --
    input_ready : out std_logic := '1';
    input_valid : in std_logic;
    input_last : in std_logic;
    input_data : in std_logic_vector(input_width - 1 downto 0);
    -- Optional word strobe. Must set 'enable_strobe' generic in order to use this.
    input_strobe : in std_logic_vector(input_width / strobe_unit_width - 1 downto 0) :=
      (others => '1');
    --
    output_ready : in std_logic;
    output_valid : out std_logic := '0';
    output_last : out std_logic;
    output_data : out std_logic_vector(output_width - 1 downto 0);
    -- Optional word strobe. Must set 'enable_strobe' generic in order to use this.
    output_strobe : out std_logic_vector(output_width / strobe_unit_width - 1 downto 0) :=
      (others => '1')
  );
end entity;

architecture a of width_conversion is

  function get_atom_width return positive is
  begin
    if enable_strobe then
      assert strobe_unit_width > 0
        report "Must set a valid strobe width when strobing is enabled."
        severity failure;
      return strobe_unit_width;
    end if;

    -- When converting e.g. 16->32 the data atom that is handled internally will be of width 16.
    -- This gives lower resource utilization than if it was e.g. always 8.
    return minimum(input_width, output_width);
  end function;
  constant atom_width : positive := get_atom_width;
  subtype atom_range is natural range atom_width - 1 downto 0;

  constant num_atoms_per_input : positive := input_width / atom_width;
  constant num_atoms_per_output : positive := output_width / atom_width;

  -- +1 for last
  constant packed_atom_width : positive := atom_width + 1 + to_int(enable_strobe);
  constant stored_atom_count_max : positive := num_atoms_per_input + num_atoms_per_output;

  constant shift_reg_length : positive := stored_atom_count_max * packed_atom_width;
  signal shift_reg : std_logic_vector(shift_reg_length - 1 downto 0) := (others => '0');

  signal num_atoms_stored : natural range 0 to stored_atom_count_max := 0;

  impure function pack(
    atom_data : std_logic_vector(atom_range);
    atom_strobe : std_logic;
    atom_last : std_logic
  ) return std_logic_vector is
    variable result : std_logic_vector(packed_atom_width - 1 downto 0) := (others => '0');
  begin
    result(atom_data'range) := atom_data;

    if enable_strobe then
      result(result'high - 1) := atom_strobe;
    end if;

    result(result'high) := atom_last;

    return result;
  end function;

  procedure unpack(
    packed : in std_logic_vector(packed_atom_width - 1 downto 0);
    atom_data : out std_logic_vector(atom_range);
    atom_strobe : out std_logic;
    atom_last : out std_logic
  ) is
  begin
    atom_data := packed(atom_data'range);

    if enable_strobe then
      atom_strobe := packed(packed'high - 1);
    end if;

    atom_last := packed(packed'high);
  end procedure;

  signal padded_input_ready, padded_input_valid, padded_input_last : std_logic := '0';
  signal padded_input_data : std_logic_vector(input_data'range) := (others => '0');
  signal padded_input_strobe : std_logic_vector(input_strobe'range) := (others => '0');

begin

  ------------------------------------------------------------------------------
  assert input_width /= output_width
    report "Do not use this module with equal widths" severity failure;

  assert input_width mod output_width = 0 or output_width mod input_width = 0
    report "Larger width has to be multiple of smaller." severity failure;

  assert (output_width / input_width) mod 2 = 0 and (input_width / output_width) mod 2 = 0
    report "Larger width has to be power of two multiple of smaller." severity failure;

  assert strobe_unit_width > 0 or not enable_strobe
    report "Must set a valid strobe width when strobing is enabled." severity failure;

  assert input_width < output_width or not support_unaligned_burst_length
    report "Unaligned burst length only makes sense when upconverting." severity failure;

  assert enable_strobe or not support_unaligned_burst_length
    report "Must enable strobing when doing unaligned bursts." severity failure;


  ------------------------------------------------------------------------------
  pad_input_data_generate : if support_unaligned_burst_length generate

    type state_t is (let_data_pass, send_padding);
    signal state : state_t := let_data_pass;

    constant input_beats_per_output_beat : natural := output_width / input_width;
    signal output_words_filled : natural range 0 to input_beats_per_output_beat := 0;

  begin

    ------------------------------------------------------------------------------
    assign : process(all)
    begin
      padded_input_data <= input_data;
      padded_input_last <= input_last;

      if state = let_data_pass then

        -- Passthrough.
        input_ready <= padded_input_ready;
        padded_input_valid <= input_valid;
        padded_input_strobe <= input_strobe;

      else -- send_padding

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
        if output_words_filled = input_beats_per_output_beat then
          output_words_filled <= 1;
        else
          output_words_filled <= output_words_filled + 1;
        end if;
      end if;

      case state is
        when let_data_pass =>
          if (
            padded_input_ready = '1'
            and padded_input_valid = '1'
            and padded_input_last = '1'
            and output_words_filled /= input_beats_per_output_beat - 1
          ) then
            state <= send_padding;
          end if;

        when send_padding =>
          if padded_input_ready and padded_input_valid then
            if output_words_filled = input_beats_per_output_beat - 1 then
              -- This transaction fills the last words out the output.
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

    variable atom_strobe, atom_last : std_logic := '0';
    variable num_atoms_strobed : natural range 0 to num_atoms_per_input := num_atoms_per_input;

    variable packed_data_to_shift_in : std_logic_vector(packed_atom_width - 1 downto 0) :=
      (others => '0');
    variable shift_reg_next : std_logic_vector(shift_reg'range) := (others => '0');
  begin
    wait until rising_edge(clk);

    num_atoms_next := num_atoms_stored;

    shift_reg_next := shift_reg;
    if padded_input_ready and padded_input_valid then
      if enable_strobe then
        num_atoms_strobed := count_ones(padded_input_strobe);
      end if;

      -- In order to remove words that are strobed out, num_atoms_strobed could be used instead
      -- of num_atoms_per_input below. This increases the LUT usage by a factor of four.
      num_atoms_next := num_atoms_next + num_atoms_per_input;

      for input_atom_idx in 0 to num_atoms_per_input - 1 loop
        if enable_strobe then
          -- When strobing, the atom size is always one strobe unit, so this indexing works.
          atom_strobe := padded_input_strobe(input_atom_idx);
        end if;

        -- Set 'last' only on the last strobed atom of the input word.
        if input_atom_idx = num_atoms_strobed - 1 then
          atom_last := padded_input_last;
        else
          atom_last := '0';
        end if;

        packed_data_to_shift_in := pack(
          atom_data=>padded_input_data(
            (input_atom_idx + 1) * atom_width - 1 downto input_atom_idx * atom_width
          ),
          atom_strobe=>atom_strobe,
          atom_last=>atom_last
        );
        shift_reg_next :=
          packed_data_to_shift_in
          & shift_reg_next(shift_reg_next'left downto packed_data_to_shift_in'length);
      end loop;
    end if;
    shift_reg <= shift_reg_next;

    if output_ready and output_valid then
      num_atoms_next := num_atoms_next - num_atoms_per_output;
    end if;

    num_atoms_stored <= num_atoms_next;
  end process;

  padded_input_ready <= to_sl(num_atoms_stored <= stored_atom_count_max - num_atoms_per_input);


  ------------------------------------------------------------------------------
  slice_output : process(all)
    variable output_atoms_base : natural range 0 to stored_atom_count_max := 0;

    variable packed_atom : std_logic_vector(packed_atom_width - 1 downto 0) := (others => '0');

    variable atom_data : std_logic_vector(atom_width - 1 downto 0) := (others => '0');
    variable atom_strobe, atom_last : std_logic_vector(num_atoms_per_output - 1 downto 0) :=
      (others => '0');
  begin
    output_valid <= to_sl(num_atoms_stored >= num_atoms_per_output);

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
          atom_strobe=>atom_strobe(output_atom_idx),
          atom_last=>atom_last(output_atom_idx)
        );

        output_data((output_atom_idx + 1) * atom_width - 1 downto output_atom_idx * atom_width) <=
          atom_data;
      else

        -- This is just so that the indexing does not go out of range. When the condition for
        -- output_valid is met, we will not end up here for any atom.
        output_data((output_atom_idx + 1) * atom_width - 1 downto output_atom_idx * atom_width) <=
          (others => '-');
        atom_strobe(output_atom_idx) := '-';
        atom_last(output_atom_idx) := '-';

      end if;
    end loop;

    if enable_strobe then
      -- The top atome might be strobed out and not have 'last' set. Instead it is found in one of
      -- the lower atoms.
      output_last <= or atom_last;
      output_strobe <= atom_strobe;
    else
      output_last <= atom_last(atom_last'high);
    end if;
  end process;

end architecture;
