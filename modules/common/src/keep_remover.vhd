-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the tsfpga project.
-- https://tsfpga.com
-- https://gitlab.com/tsfpga/tsfpga
-- -------------------------------------------------------------------------------------------------
-- This entity removes strobe'd out lanes from the input, resulting in an output stream where all
-- lanes are always strobed (except for the last beat, potentially). The strobe on input can be
-- considered as the TKEEP signal in AXI-Stream terminology, and the output strobe would be
-- TKEEP/TSTRB.
--
-- The entity works by continously filling up a data buffer with data from the input. Only the lanes
-- that are strobed will be saved to the buffer. Note that input words may have all their lanes
-- strobed out (except for the last beat, see below).
-- When enough lanes are saved to fill a whole word, data is passed to the output by asserting
-- output_valid. When input_last is asserted for an input
-- word, an output word will be sent out, with output_last asserted, even if a whole strobed word
-- is not currently filled in the buffer.
--
-- The strobe unit data width is configurable via a generic. Most of the time it would be eight,
-- i.e. a byte strobe. But in some cases the strobe represents a wider quanta, in which case the
-- generic can be increased. Increasing the generic will drastically decrease the
-- resourse utilization, since that is the "atom" of data that is handled internally.
--
-- The handling of input_last presents a corner case.
-- Lets assume that data_width is 16 and strobe_unit_width is 8.
-- Furthermore, there is one atom of data available in the buffer, and input stream has both lanes
-- strobed. In this case, one input word shall result in two output words. The output word
-- comes from a whole word being filled in the buffer. The second word comes from a half filled word
-- in the buffer, but input_last being asserted.
-- This is solved by having a small state machine that pads input data with an extra word when
-- this corner case arises. The padding stage makes it possible to have a very simple data buffer
-- stage, with low resource utilization.
--
-- The entity achieves full throughput, except for the corner case mentioned above, where it might
-- stall one cycle on the input.
--
-- Limitations:
--
-- * 'input_last' may not be asserted on an input word that has all lanes strobed out.
-- * There may never be a '1' above a '0' in the input strobe. E.g. "0111" is allowed,
--   but "1100" is not.
-- -------------------------------------------------------------------------------------------------

library ieee;
context ieee.ieee_std_context;

library common;
use common.types_pkg.all;


entity keep_remover is
  generic (
    data_width : positive;
    strobe_unit_width : positive
  );
  port (
    clk : in std_logic;
    --
    input_ready : out std_logic := '0';
    input_valid : in std_logic;
    input_last : in std_logic;
    input_data : in std_logic_vector(data_width - 1 downto 0);
    input_keep : in std_logic_vector(data_width / strobe_unit_width - 1 downto 0);
    --
    output_ready : in std_logic;
    output_valid : out std_logic := '0';
    output_last : out std_logic := '0';
    output_data : out std_logic_vector(data_width - 1 downto 0) := (others => '0');
    output_strobe : out std_logic_vector(data_width / strobe_unit_width - 1 downto 0) :=
      (others => '0')
  );
end entity;

architecture a of keep_remover is

  -- The unit of data that we will be working with
  constant atom_width : positive := strobe_unit_width;

  -- +1 for 'strobe' bit and 'last' bit
  constant packed_atom_width : positive := atom_width + 1 + 1;

  constant num_atoms_per_word : positive := input_keep'length;

  -- Since there is a pipeline step in this entity, we must be able to hold at least two maximum
  -- size input words in order to preserve full throughput.
  constant max_num_words_in_buffer : positive := 2;
  constant max_num_atoms_in_buffer : positive := max_num_words_in_buffer * num_atoms_per_word;

  signal padded_input_ready, padded_input_valid, padded_input_last : std_logic := '0';
  signal padded_input_data : std_logic_vector(input_data'range) := (others => '0');
  signal padded_input_keep : std_logic_vector(input_keep'range) := (others => '0');

  signal num_atoms_in_buffer : natural range 0 to max_num_atoms_in_buffer := 0;
  signal num_atoms_written_in_current_word : natural range 0 to num_atoms_per_word := 0;

begin

  assert data_width mod strobe_unit_width = 0
    report "Data width must be a multiple of strobe unit width." severity failure;


  ------------------------------------------------------------------------------
  assert_input : process
  begin
    wait until input_valid = '1' and rising_edge(clk);

    assert (or input_keep) or not input_last report
      "'last' may not be asserted on a strobed out word";

    for strobe_idx in input_keep'range loop
      if input_keep(strobe_idx) = '0' then
        assert (or input_keep(input_keep'high downto strobe_idx)) = '0'
          report "There must never be a '1' above a '0' in the input strobe";
      end if;
    end loop;
  end process;


  ------------------------------------------------------------------------------
  pad_block : block
    signal num_atoms_strobed : natural range 0 to num_atoms_per_word := 0;

    signal num_atoms_written_in_current_word_plus_this_write :
      natural range 0 to 2 * num_atoms_per_word - 1 := 0;

    signal last_input_needs_padding : std_logic := '0';

    type state_t is (let_data_pass, handle_last);
    signal state : state_t := let_data_pass;
  begin

    num_atoms_strobed <= count_ones(input_keep);

    num_atoms_written_in_current_word <= num_atoms_in_buffer mod num_atoms_per_word;

    num_atoms_written_in_current_word_plus_this_write <=
      num_atoms_written_in_current_word + num_atoms_strobed;

    -- The current input word, along with handling of last, will result in more than one
    -- word being written to buffer
    last_input_needs_padding <=
      to_sl(num_atoms_written_in_current_word_plus_this_write > num_atoms_per_word);


    ------------------------------------------------------------------------------
    pad_input_fsm : process
    begin
      wait until rising_edge(clk);

      case state is
        when let_data_pass =>
          if
            padded_input_ready
            and padded_input_valid
            and input_last
            and last_input_needs_padding
          then
            state <= handle_last;
          end if;

        when handle_last =>
        -- Let one extra word pass and then go back to default state
          if padded_input_ready and padded_input_valid then
            state <= let_data_pass;
          end if;

      end case;
    end process;


    ------------------------------------------------------------------------------
    pad_input_assign : process(all)
    begin
      padded_input_data <= input_data;

      case state is
        when let_data_pass =>
          input_ready <= padded_input_ready;

          padded_input_valid <= input_valid;

          padded_input_keep <= input_keep;

          if input_valid and input_last and last_input_needs_padding then
            -- We will send an extra word, where 'last' will be asserted
            padded_input_last <= '0';
          else
            padded_input_last <= input_last;
          end if;

        when handle_last =>
          input_ready <= '0';

          padded_input_valid <= '1';

          -- None of these atoms should be sent to output, they are all padding
          padded_input_keep <= (others => '0');
          padded_input_last <= '1';
      end case;

    end process;

  end block;


  ------------------------------------------------------------------------------
  processing_block : block

    -- Data buffer as a long SLV, containing many packed atoms.
    -- Note that an array of records (data, strobe, last) result in greater resource utilization
    -- that this SLV.
    constant data_buffer_length : positive := max_num_atoms_in_buffer * packed_atom_width;
    signal data_buffer : std_logic_vector(data_buffer_length - 1 downto 0) := (others => '0');

    subtype atom_pointer_t is natural range 0 to max_num_atoms_in_buffer - 1;
    subtype word_pointer_t is natural range 0 to max_num_words_in_buffer - 1;

    signal write_pointer : atom_pointer_t := 0;
    -- We always read whole words, so a narrower pointer can be used
    signal read_pointer : word_pointer_t := 0;

    function pack(
      atom_data : std_logic_vector(atom_width - 1 downto 0);
      atom_strobe : std_logic;
      atom_last : std_logic
    ) return std_logic_vector is
      variable result : std_logic_vector(packed_atom_width - 1 downto 0) := (others => '0');
    begin
      result(atom_data'range) := atom_data;
      result(result'high - 1) := atom_strobe;
      result(result'high) := atom_last;

      return result;
    end function;

    procedure unpack(
      packed : in std_logic_vector(packed_atom_width - 1 downto 0);
      atom_data : out std_logic_vector(atom_width - 1 downto 0);
      atom_strobe : out std_logic;
      atom_last : out std_logic
    ) is
    begin
      atom_data := packed(atom_data'range);
      atom_strobe := packed(packed'high - 1);
      atom_last := packed(packed'high);
    end procedure;

  begin

    ------------------------------------------------------------------------------
    main : process
      variable atom_write_idx : atom_pointer_t := 0;

      variable data_to_write : std_logic_vector(atom_width - 1 downto 0) := (others => '0');
      variable strobe_to_write, last_to_write : std_logic := '0';

      variable packed_atom : std_logic_vector(packed_atom_width - 1 downto 0) := (others => '0');
      variable data_buffer_next : std_logic_vector(data_buffer'range) := (others=> '0');

      variable num_atoms_needed_to_fill_current_word : natural := 0;

      variable num_atoms_to_read, num_atoms_to_write : natural range 0 to num_atoms_per_word := 0;
      variable num_words_to_read : natural range 0 to 1 := 0;
    begin
      wait until rising_edge(clk);

      -- Note that all atoms are written to the buffer, but the write pointer is only incremented
      -- with the number of atoms that are strobed.
      data_buffer_next := data_buffer;
      for atom_idx in 0 to num_atoms_per_word - 1 loop
        atom_write_idx := (write_pointer + atom_idx) mod max_num_atoms_in_buffer;

        data_to_write := padded_input_data((atom_idx + 1) * atom_width - 1 downto atom_idx * atom_width);
        strobe_to_write := padded_input_keep(atom_idx);
        last_to_write := padded_input_last;

        packed_atom := pack(
          data_to_write,
          strobe_to_write,
          last_to_write
        );

        data_buffer_next(
          (atom_write_idx + 1) * packed_atom_width - 1 downto atom_write_idx * packed_atom_width
        ) := packed_atom;
      end loop;

      num_atoms_to_write := 0;
      if padded_input_ready and padded_input_valid then
        if padded_input_last then
          num_atoms_needed_to_fill_current_word :=
            num_atoms_per_word - num_atoms_written_in_current_word;

          num_atoms_to_write := num_atoms_needed_to_fill_current_word;

          assert num_atoms_to_write >= count_ones(padded_input_keep);
        else
          num_atoms_to_write := count_ones(padded_input_keep);
        end if;

        data_buffer <= data_buffer_next;
      end if;

      num_atoms_to_read := 0;
      num_words_to_read := 0;
      if output_ready and output_valid then
        num_atoms_to_read := num_atoms_per_word;
        num_words_to_read := 1;
      end if;

      write_pointer <= (write_pointer + num_atoms_to_write) mod max_num_atoms_in_buffer;

      read_pointer <= (read_pointer + num_words_to_read) mod max_num_words_in_buffer;

      num_atoms_in_buffer <=
        num_atoms_in_buffer
        + num_atoms_to_write
        - num_atoms_to_read;
    end process;

    padded_input_ready <=
      to_sl(num_atoms_in_buffer <= (max_num_atoms_in_buffer - num_atoms_per_word));

    output_valid <= to_sl(num_atoms_in_buffer >= num_atoms_per_word);


    ------------------------------------------------------------------------------
    assign_output : process(all)
      variable atom_read_idx : atom_pointer_t := 0;

      variable packed_atom : std_logic_vector(packed_atom_width - 1 downto 0) := (others => '0');
      variable unpacked_data : std_logic_vector(atom_width - 1 downto 0) := (others => '0');
      variable unpacked_strobe, unpacked_last : std_logic := '0';

      variable is_last : std_logic := '0';
    begin
      is_last := '0';

      for atom_idx in 0 to num_atoms_per_word - 1 loop
        atom_read_idx := read_pointer * num_atoms_per_word + atom_idx;

        packed_atom := data_buffer(
          (atom_read_idx + 1) * packed_atom_width - 1 downto atom_read_idx * packed_atom_width
        );
        unpack(packed_atom, unpacked_data, unpacked_strobe, unpacked_last);

        output_data((atom_idx + 1) * atom_width - 1 downto atom_idx * atom_width) <= unpacked_data;
        output_strobe(atom_idx) <= unpacked_strobe;

        is_last := is_last or unpacked_last;
      end loop;

      output_last <= is_last;
    end process;

  end block;

end architecture;
