-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the hdl-modules project, a collection of reusable, high-quality,
-- peer-reviewed VHDL building blocks.
-- https://hdl-modules.com
-- https://github.com/hdl-modules/hdl-modules
-- -------------------------------------------------------------------------------------------------
-- Width conversion of an AXI-Stream-like data bus.
-- Can handle downconversion (wide to thin) or upconversion (thin
-- to wide).
-- The data widths must be a power-of-two multiple of each other. E.g. 10->40 is
-- supported while 8->24 is not.
--
-- There is a generic to enable usage of the ``last`` signal. The ``last`` indicator will be passed
-- along with the data from the ``input`` to ``output`` side as-is. Note that enabling the
-- ``support_unaligned_packet_length`` generic will enable further processing of ``last``, but in
-- barebone configuration the signal is merely passed on.
--
-- There is a generic to enable strobing of data. The ``strobe`` will be passed on from
-- ``input`` to ``output`` side as-is. Note that enabling ``support_unaligned_packet_length``
-- generic will enable further processing of ``strobe``, but in barebone configuration the signal
-- is merely passed on.
-- This means, for example, that there might be output words where all strobe lanes are
-- zero when downconverting.
--
-- There are some limitations, and possible remedies, concerning packet length alignment, depending
-- on if we are doing upconversion or downconversion. See below.
--
--
-- Downconversion behavior
-- _______________________
--
-- When doing downconversion, one input beat will result in two or more output beats, depending
-- on width configuration. This means that the output packet length is always aligned with the input
-- data width. This is not always desirable when working with the ``strobe`` and ``last`` signals.
-- Say for example that we are converting a bus from 16 to 8, and ``input_last`` is asserted on a
-- beat where the lowest byte is strobed but the highest is not. In this case, we would want
-- ``output_last`` to be asserted on the second to last byte, and the last byte (which is strobed
-- out) to be removed.
-- This is achieved by enabling the ``support_unaligned_packet_length`` generic.
-- If the generic is not set, ``output_last`` will be asserted on the very last byte, which will
-- be strobed out.
--
--
-- Upconversion behavior
-- _____________________
--
-- When upconverting, two or more ``input`` beats result in one ``output`` beat, depending on width
-- configuration. This means that the input packet length must be aligned with the output
-- data width, so that each packet fills up a whole number of output words.
-- If this can not be guaranteed, then the ``support_unaligned_packet_length`` mode can be used.
-- When that is enabled, the input stream will be padded upon ``last`` indication so that a whole
-- output word is filled.
-- Consider the example of converting a bus from 8 to 16, and ``input`` last is asserted on the
-- third input beat. If ``support_unaligned_packet_length`` is disabled, there will be one output
-- beat sent and half an output beat left in the converter.
-- If the mode is enabled however, the input stream will be padded with another byte so that an
-- output beat can be sent. The padded parts will have ``strobe`` set to zero.
--
-- Note that the handling of unaligned packet lengths is highly dependent on the input stream being
-- well behaved. Specifically
--
--   1. There may never be input beats where ``input_strobe`` is all zeros.
--   2. For all beats except the one where ``input_last`` is asserted, ``input_strobe`` must be
--      asserted on all lanes.
--   3. There may never be a ``'1'`` above a ``'0'`` in the ``input_strobe``.
--
--
-- User signalling
-- _______________
--
-- By setting the ``user_width`` generic to a non-zero value, the ``input_user`` port can be used
-- to pass auxillary data along the bus.
--
-- When downconverting, i.e. when one input beat results in multiple output beats, the
-- ``output_user`` port will have the same width as the ``input_user`` port.
-- Each output beat will have the same ``user`` value as the input beat that created it.
--
-- When upconverting, i.e. when multiple input beats result in one output beat, the ``output_user``
-- port will have the same width as the ``input_user`` port multiplied by the conversion factor.
-- The ``output_user`` port will have the concatenated ``input_user`` values from all the input
-- beats that created the output beat.
-- -------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.types_pkg.all;
use work.width_conversion_pkg.all;


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
    -- In other cases, for example when the data is packed, we might use a higher value.
    -- Must assign a valid value if 'enable_strobe' is true.
    strobe_unit_width : positive := 8;
    -- Width of the 'input_user' port.
    user_width : natural := 0;
    -- Enable if 'input' packet lengths are not a multiple of the 'output' width.
    -- Must set 'enable_strobe' and 'enable_last' as well to use this.
    -- See header for details about how this works.
    -- Will increase the logic footprint.
    support_unaligned_packet_length : boolean := false
  );
  port (
    clk : in std_ulogic;
    --# {{}}
    input_ready : out std_ulogic := '0';
    input_valid : in std_ulogic;
    -- Optional packet 'last' signalling. Must set 'enable_last' generic in order to use this.
    input_last : in std_ulogic := '0';
    input_data : in std_ulogic_vector(input_width - 1 downto 0);
    -- Optional word strobe. Must set 'enable_strobe' generic in order to use this.
    input_strobe : in std_ulogic_vector(input_width / strobe_unit_width - 1 downto 0) := (
      others => '1'
    );
    -- Optional auxillary user data. Must set 'user_width' generic in order to use this.
    input_user : in std_ulogic_vector(user_width - 1 downto 0) := (others => '-');
    --# {{}}
    output_ready : in std_ulogic;
    output_valid : out std_ulogic := '0';
    -- Optional packet 'last' signalling. Must set 'enable_last' generic in order to use this.
    output_last : out std_ulogic := '0';
    output_data : out std_ulogic_vector(output_width - 1 downto 0) := (others => '0');
    -- Optional word strobe. Must set 'enable_strobe' generic in order to use this.
    output_strobe : out std_ulogic_vector(output_width / strobe_unit_width - 1 downto 0) := (
      others => '1'
    );
    -- Optional auxillary user data. Must set 'user_width' generic in order to use this.
    output_user : out std_ulogic_vector(
      width_conversion_output_user_width(
        input_user_width=>user_width, input_data_width=>input_width, output_data_width=>output_width
      ) - 1
      downto 0
    ) := (others => '0')
  );
end entity;

architecture a of width_conversion is

  constant is_upconversion : boolean := input_width < output_width;
  constant is_downconversion : boolean := input_width > output_width;

  constant enable_user : boolean := user_width > 0;

  -- When converting e.g. 16->32 the data atom that is handled internally will be of width 16.
  -- This gives lower resource utilization than if it was e.g. always 8.
  constant atom_data_width : positive := minimum(input_width, output_width);
  constant atom_strobe_width : positive := atom_data_width / strobe_unit_width;
  constant atom_user_width : natural := user_width;

  subtype atom_data_t is std_ulogic_vector(atom_data_width - 1 downto 0);
  subtype atom_strobe_t is std_ulogic_vector(atom_strobe_width - 1 downto 0);
  subtype atom_user_t is std_ulogic_vector(user_width - 1 downto 0);

  -- Would usually be 'input_bytes_per_beat', but since the strobe width is variable
  -- we can not call it 'byte'.
  constant input_width_strobes : positive := input_width / strobe_unit_width;
  constant input_width_atoms : positive := input_width / atom_data_width;
  constant output_width_atoms : positive := output_width / atom_data_width;

  constant packed_atom_width : positive := (
    atom_data_width + to_int(enable_last) + to_int(enable_strobe) * atom_strobe_width + user_width
  );
  subtype packed_atom_t is std_ulogic_vector(packed_atom_width - 1 downto 0);

  constant stored_atom_count_max : positive := input_width_atoms + output_width_atoms;
  constant shift_reg_length : positive := stored_atom_count_max * packed_atom_width;
  signal shift_reg : std_ulogic_vector(shift_reg_length - 1 downto 0) := (others => '0');

  signal num_atoms_stored : natural range 0 to stored_atom_count_max := 0;

  impure function pack(
    atom_data : atom_data_t;
    atom_strobe : atom_strobe_t;
    atom_last : std_ulogic;
    atom_user : atom_user_t
  ) return std_ulogic_vector is
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

    if enable_user then
      -- Could be more than one bit
      lo := hi + 1;
      hi := lo + atom_user'length - 1;
      result(hi downto lo) := atom_user;
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
    atom_last : out std_ulogic;
    atom_user : out atom_user_t
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

    if enable_user then
      -- Could be more than one bit
      lo := hi + 1;
      hi := lo + atom_user'length - 1;
      atom_user := packed(hi downto lo);
    end if;

    if enable_last then
      -- Only one bit
      hi := hi + 1;
      atom_last := packed(hi);
    end if;

    assert hi = packed'high report "Something wrong with widths" severity failure;
  end procedure;

  signal padded_input_ready, padded_input_valid, padded_input_last : std_ulogic := '0';
  signal padded_input_data : std_ulogic_vector(input_data'range) := (others => '0');
  signal padded_input_strobe : std_ulogic_vector(input_strobe'range) := (others => '0');
  signal padded_input_user : std_ulogic_vector(input_user'range) := (others => '0');

  signal output_ready_int, output_valid_int, output_last_int : std_ulogic := '0';
  signal output_strobe_int : std_ulogic_vector(output_strobe'range) := (others => '0');

begin

  ------------------------------------------------------------------------------
  assert input_width /= output_width
    report "Do not use this module with equal widths"
    severity failure;

  assert input_width mod output_width = 0 or output_width mod input_width = 0
    report "Larger width has to be multiple of smaller."
    severity failure;

  assert (output_width / input_width) mod 2 = 0 and (input_width / output_width) mod 2 = 0
    report "Larger width has to be power-of-two multiple of smaller."
    severity failure;

  assert (
      (not enable_strobe)
      or (input_width mod strobe_unit_width = 0 and output_width mod strobe_unit_width = 0)
    )
    report "Data width must be a multiple of strobe unit width."
    severity failure;

  assert enable_strobe or not support_unaligned_packet_length
    report "Must enable strobing when doing unaligned packets."
    severity failure;

  assert enable_last or not support_unaligned_packet_length
    report "Must enable 'last' when doing unaligned packets."
    severity failure;


  ------------------------------------------------------------------------------
  assertions : process
    constant strobe_init : std_ulogic_vector(input_strobe'range) := (others => '1');
  begin
    wait until rising_edge(clk);

    if input_valid then
      assert enable_last or input_last = '0'
        report "Must enable 'last' using generic"
        severity failure;

      assert enable_strobe or input_strobe = strobe_init
        report "Must enable 'strobe' using generic"
        severity failure;
    end if;
  end process;


  ------------------------------------------------------------------------------
  pad_input_data_generate : if is_upconversion and support_unaligned_packet_length generate
    type state_t is (let_data_pass, send_padding);
    signal state : state_t := let_data_pass;


    constant width_ratio : positive := output_width / input_width;
    signal beats_filled : natural range 0 to width_ratio - 1 := 0;
  begin

    ------------------------------------------------------------------------------
    assign : process(all)
    begin
      padded_input_data <= input_data;

      -- 'last' when in padding state does not matter.
      -- When in this unaligned mode, 'output_last' is set by OR'ing  the 'last' for each atom.
      padded_input_last <= input_last;

      padded_input_user <= input_user;

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
      wait until rising_edge(clk) and support_unaligned_packet_length;

      if padded_input_ready and padded_input_valid then
        beats_filled <= (beats_filled + 1) mod width_ratio;
      end if;

      case state is
        when let_data_pass =>
          if (
            padded_input_ready = '1'
            and padded_input_valid = '1'
            and padded_input_last = '1'
            and beats_filled /= width_ratio - 1
          ) then
            state <= send_padding;
          end if;

        when send_padding =>
          if padded_input_ready and padded_input_valid then
            if beats_filled = width_ratio - 1 then
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
    padded_input_user <= input_user;

  end generate;


  ------------------------------------------------------------------------------
  main : process
    variable num_atoms_next : natural range 0 to stored_atom_count_max;

    variable atom_last : std_ulogic := '0';
    variable atom_data : atom_data_t := (others => '0');
    variable atom_strobe : atom_strobe_t := (others => '0');
    variable atom_user : atom_user_t := (others => '0');

    variable strobe_idx_to_write_last : natural range 0 to input_width_strobes - 1 := 0;

    -- Default value: highest strobe lane.
    variable atom_idx_to_write_last : natural range 0 to input_width_atoms - 1 := (
      input_width_atoms - 1
    );

    variable packed_data_to_shift_in : packed_atom_t := (others => '0');
    variable shift_reg_next : std_ulogic_vector(shift_reg'range) := (others => '0');
  begin
    wait until rising_edge(clk);

    num_atoms_next := num_atoms_stored;

    shift_reg_next := shift_reg;
    if padded_input_ready and padded_input_valid then
      if is_downconversion and support_unaligned_packet_length then
        -- In this mode we have to put the 'last' indicator on the very last atom that is strobed.
        -- Atoms beyond that one will be stripped on the output.
        -- In other modes, the default value constant will be used for this variable.
        strobe_idx_to_write_last := count_ones(padded_input_strobe) - 1;
        atom_idx_to_write_last := strobe_idx_to_write_last / atom_strobe_width;
      end if;

      num_atoms_next := num_atoms_next + input_width_atoms;

      for input_atom_idx in 0 to input_width_atoms - 1 loop
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

        atom_user := padded_input_user;

        packed_data_to_shift_in := pack(
          atom_data=>atom_data,
          atom_strobe=>atom_strobe,
          atom_last=>atom_last,
          atom_user=>atom_user
        );
        shift_reg_next := (
          packed_data_to_shift_in
          & shift_reg_next(shift_reg_next'left downto packed_data_to_shift_in'length)
        );
      end loop;
    end if;
    shift_reg <= shift_reg_next;

    if output_ready_int and output_valid_int then
      num_atoms_next := num_atoms_next - output_width_atoms;
    end if;

    num_atoms_stored <= num_atoms_next;

    output_valid_int <= to_sl(num_atoms_next >= output_width_atoms);
  end process;

  padded_input_ready <= to_sl(num_atoms_stored <= stored_atom_count_max - input_width_atoms);


  ------------------------------------------------------------------------------
  slice_output : process(all)
    variable output_atoms_base : natural range 0 to stored_atom_count_max := 0;

    variable packed_atom : packed_atom_t := (others => '0');

    variable atoms_last : std_ulogic_vector(output_width_atoms - 1 downto 0) := (others => '0');
    variable atom_data : atom_data_t := (others => '0');
    variable atom_strobe : atom_strobe_t := (others => '0');
    variable atom_user : atom_user_t := (others => '0');
  begin

    output_atoms_base := stored_atom_count_max - num_atoms_stored;

    for output_atom_idx in 0 to output_width_atoms - 1 loop
      if output_atom_idx < num_atoms_stored then
        packed_atom := shift_reg(
          (output_atoms_base + output_atom_idx + 1) * packed_atom_width - 1
          downto (output_atoms_base + output_atom_idx) * packed_atom_width
        );

        unpack(
          packed=>packed_atom,
          atom_data=>atom_data,
          atom_strobe=>atom_strobe,
          atom_last=>atoms_last(output_atom_idx),
          atom_user=>atom_user
        );

      else

        -- This is just so that the indexing does not go out of range. When the condition for
        -- output_valid is met, we will not end up here for any atom.
        atom_data := (others => '-');
        atom_strobe := (others => '-');
        atoms_last(output_atom_idx) := '-';
        -- TODO
        atom_user := (others => '-');
      end if;

      output_data(
        (output_atom_idx + 1) * atom_data_width - 1 downto output_atom_idx * atom_data_width
      ) <= atom_data;

      output_strobe_int(
        (output_atom_idx + 1) * atom_strobe_width - 1 downto output_atom_idx * atom_strobe_width
      ) <= atom_strobe;

      output_user(
        (output_atom_idx + 1) * atom_user_width - 1 downto output_atom_idx * atom_user_width
      ) <= atom_user;
    end loop;

    if is_upconversion and support_unaligned_packet_length then
      -- The top atom might be strobed out and not have 'last' set.
      -- Instead it is found in one of the lower atoms.
      output_last_int <= or atoms_last;
    else
      output_last_int <= atoms_last(atoms_last'high);
    end if;
  end process;


  ------------------------------------------------------------------------------
  strip_output_data_generate : if is_downconversion and support_unaligned_packet_length generate
    signal strobe_all_zero : std_ulogic_vector(output_strobe'range) := (others => '0');
  begin

    -- The write processing will place 'last' indicator on the last atom that is strobed.
    -- There might come atoms after that, since this is downconversion.
    -- If those atoms add up to an output beat, that is removed here.
    -- This is highly dependent on the input stream being well-behaved.

    ------------------------------------------------------------------------------
    set_output : process(all)
    begin
      -- Pop strobed out words
      output_ready_int <= (
        output_ready or (output_valid_int and to_sl(output_strobe_int = strobe_all_zero))
      );

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
