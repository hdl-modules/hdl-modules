-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the hdl-modules project, a collection of reusable, high-quality,
-- peer-reviewed VHDL building blocks.
-- https://hdl-modules.com
-- https://github.com/hdl-modules/hdl-modules
-- -------------------------------------------------------------------------------------------------
-- Collection of types/functions for working with address decode/matching.
-- -------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library math;
use math.math_pkg.all;

use work.types_pkg.all;


package addr_pkg is

  constant addr_width : positive := 32;
  subtype addr_t is u_unsigned(addr_width - 1 downto 0);
  type addr_vec_t is array (integer range <>) of addr_t;

  function to_addr(value : natural) return addr_t;

  -- Perform basic sanity check of the provided addresses.
  -- Returns 'true' if everything is valid.
  function sanity_check_base_addresses(addrs : addr_vec_t) return boolean;

  type addr_and_mask_t is record
    addr : addr_t;
    mask : addr_t;
  end record;
  constant addr_and_mask_init : addr_and_mask_t := (
    addr => (others => '0'), mask => (others => '0')
  );
  type addr_and_mask_vec_t is array (integer range <>) of addr_and_mask_t;

  -- Return 'true' if the provided addresses matches the addr/mask.
  function match(addr : u_unsigned; addr_and_mask : addr_and_mask_t) return boolean;

  -- Return the addr/mask index that matches the provided address.
  function decode(addr : u_unsigned; addrs : addr_and_mask_vec_t) return natural;

  -- Return the number of bits that are needed to decode and handle the addresses.
  function addr_bits_needed(addrs : addr_and_mask_vec_t) return positive;

  -- Validity test of the address mask.
  -- Return 'false' if there is anything wrong.
  function sanity_check_address_and_mask(
    data : addr_and_mask_vec_t; verbose : boolean := true
  ) return boolean;

  -- Print the addr/mask information to console.
  procedure print_addr_and_mask_vec(data : addr_and_mask_vec_t);

  -- Calculate an address mask where an incoming address can be decoded to determine
  -- which of the provided addresses it matches.
  -- This function is simple and naive, compared to 'calculate_minimal_mask'.
  -- However, the difference between them never manifested itself as particularly many LUTs.
  -- The netlist build shrinks from 516 to 493 LUTs when using the minimal calculated mask.
  -- Since this address decoding is probably only done at one place in the FPGA design, when the
  -- register bus is being split, there is not a huge gain of introducing the complexity
  -- of 'calculate_minimal_mask'.
  function calculate_mask(addrs : addr_vec_t) return addr_and_mask_vec_t;

  -- Cost function to measure how well we have minimized the mask.
  -- A heuristic for how large the logic footprint will be.
  function get_mask_cost(data : addr_and_mask_vec_t) return natural;

  -- Calculate a minimal address mask where an incoming address can be decoded to determine
  -- which of the provided addresses it matches.
  -- The goal of minimizing the mask is that the logic footprint of decoding shall be as low
  -- as possible.
  -- Since this returns a minimal mask, it is not as resistant to erroneous incoming addresses
  -- as the regular 'calculate_mask'.
  -- For example, say that we have the base addresses 1000 and 3000 and an incoming address 2000.
  -- The mask from 'calculate_mask' will identify this as an error, while this mask will match
  -- it to 3000.
  -- This might be unintuitive for some users.
  function calculate_minimal_mask(addrs : addr_vec_t) return addr_and_mask_vec_t;

end package;

package body addr_pkg is

  function to_addr(value : natural) return addr_t is
    constant result : addr_t := to_unsigned(value, addr_width);
  begin
    return result;
  end function;

  function sanity_check_base_addresses(addrs : addr_vec_t) return boolean is
  begin
    for addr_idx in addrs'range loop
      for bit_idx in addrs(0)'range loop
        if addrs(addr_idx)(bit_idx) /= '0' and addrs(addr_idx)(bit_idx) /= '1' then
          report "Invalid character at address index "
            & integer'image(addr_idx)
            & ", bit index "
            & integer'image(bit_idx)
            & ": "
            & std_logic'image(addrs(addr_idx)(bit_idx))
            severity warning;

          return false;
        end if;
      end loop;

      for addr_test_idx in addrs'range loop
        if addr_idx /= addr_test_idx and addrs(addr_idx) = addrs(addr_test_idx) then
          report "Duplicate address found at indexes "
            & integer'image(addr_idx)
            & " and "
            & integer'image(addr_test_idx)
            & ": " & integer'image(to_integer(addrs(addr_idx)))
            severity warning;

          return false;
        end if;
      end loop;
    end loop;

    return true;
  end function;

  function match(addr : u_unsigned; addr_and_mask : addr_and_mask_t) return boolean is
    variable test_ok : boolean := true;
  begin
    for bit_idx in addr_and_mask.addr'range loop
      if addr_and_mask.mask(bit_idx) then
        test_ok := test_ok and (addr(bit_idx) = addr_and_mask.addr(bit_idx));
      end if;
    end loop;

    return test_ok;
  end function;

  function decode(addr : u_unsigned; addrs : addr_and_mask_vec_t) return natural is
    constant decode_fail : natural := addrs'length;
  begin
    for addr_idx in addrs'range loop
      if match(addr, addrs(addr_idx)) then
        return addr_idx;
      end if;
    end loop;

    return decode_fail;
  end function;

  function addr_bits_needed(addrs : addr_and_mask_vec_t) return positive is
    variable result : positive := 1;
  begin
    assert sanity_check_address_and_mask(addrs)
      report "Supplied address and mask are not valid. See printout above."
      severity failure;

    for addr_idx in addrs'range loop
      result := maximum(result, num_bits_needed(addrs(addr_idx).mask));
    end loop;

    -- Note that this function is used for e.g. AR/AW FIFO width calculations
    -- in axi_lite_to_vec.vhd.
    -- If the value returned is practically zero then there is no way to do register address
    -- decoding.
    -- Except for one special case, which is handled below.
    if result > 1 then
      return result;
    end if;

    -- We have, as in 'sanity_check_address_and_mask', the special case where there is only one
    -- base address on address zero.
    -- First of all, assert that we are actually in this special case, because if we ended up here
    -- otherwise then that is an error.
    assert addrs'length = 1 and addrs(0).addr = 0 and addrs(0).mask = 0
      report "Got unreasonable result despite not being in the only allowed special case"
      severity failure;

    -- In this special case we know really nothing about the register address ranges used.
    -- Hence do the default scenario and send all bits.
    return addrs(0).addr'length;
  end function;

  function sanity_check_address_and_mask(
    data : addr_and_mask_vec_t; verbose : boolean := true
  ) return boolean is
    variable address_masked, test_address_masked : addr_t := (others => '0');
  begin
    for addr_idx in data'range loop
      -- Mask of zero is not allowed, will match with every input address.
      if data(addr_idx).mask = 0 then
        if verbose then
          report "Mask is zero for index "
            & integer'image(addr_idx)
            & " (address " & integer'image(to_integer(data(addr_idx).addr))
            & ")."
            severity warning;
        end if;

        -- Mask of zero is allowed only in the special case where we have only one base address
        -- on address zero.
        -- In this case, an automatic mask calculator has no information to go on and has to set
        -- the mask to zero.
        -- In this case it must be considered fine that every incoming address will match with this.
        -- It is still a little bit odd, so we still want the warning printout above.
        if data'length /= 1 or data(0).addr /= 0 then
          return false;
        end if;
      end if;

      -- The loop below aims to test for address/mask overlap.
      -- Meaning, is there any conceivable input address that would match with more than
      -- one address/mask?
      --
      -- For example, consider the scenario that we have
      --  0 => addr = 0x1000, mask = 0x1000
      --  1 => addr = 0x3000, mask = 0x3000
      -- And an input address 0x3000.
      -- The input is probably intended for (1) but it will match with both (0) and (1).
      -- Hence it is ambiguous how to decode this, which is an error.
      -- This function will detect that and give an error for addr_idx=0 and addr_test_idx=1.
      --
      -- We interpret the error condition as this, in words:
      -- If any masked address A is equal to another address B masked with A's
      -- address mask, that is an error.
      for addr_test_idx in data'range loop
        if addr_idx /= addr_test_idx then
          address_masked := data(addr_idx).addr and data(addr_idx).mask;
          test_address_masked := data(addr_test_idx).addr and data(addr_idx).mask;

          if address_masked = test_address_masked then
            if verbose then
              report "Address/mask overlap for indexes "
                & integer'image(addr_idx)
                & " and "
                & integer'image(addr_test_idx)
                severity warning;
            end if;

            return false;
          end if;
        end if;
      end loop;
    end loop;

    return true;
  end function;

  procedure print_addr_and_mask_vec(data : addr_and_mask_vec_t) is
    function get_padded_index(index : natural) return string is
    begin
      if index < 10 then
        return " " & to_string(index);
      end if;
      return to_string(index);
    end function;
  begin
    report "Address and mask = (" severity note;
    for addr_idx in data'range loop
      report "  "
        & get_padded_index(addr_idx)
        & ": "
        & to_string(data(addr_idx).addr)
        & " "
        & to_string(data(addr_idx).mask)
        & " ,"
        severity note;
    end loop;
    report ")" severity note;
  end procedure;

  function calculate_mask(addrs : addr_vec_t) return addr_and_mask_vec_t is
    variable mask : addr_t := (others => '0');
    variable result : addr_and_mask_vec_t(addrs'range) := (others => addr_and_mask_init);
  begin
    -- Check that input is valid.
    assert sanity_check_base_addresses(addrs)
      report "The supplied address set is invalid. See messages above."
      severity failure;

    for addr_idx in addrs'range loop
      mask := mask or addrs(addr_idx);
      result(addr_idx).addr := addrs(addr_idx);
    end loop;

    for addr_idx in result'range loop
      result(addr_idx).mask := mask;
    end loop;

    assert sanity_check_address_and_mask(result)
      report "Calculated mask is not valid. This is an internal error."
      severity failure;

    return result;
  end function;

  function minimize_mask(
    addrs : addr_and_mask_vec_t;
    addr_idx : natural;
    loop_bits_high_to_low : boolean
  ) return addr_and_mask_vec_t is
    function get_bit_loop_range return std_ulogic_vector is
      constant result_high_to_low : std_ulogic_vector(addrs(0).mask'high downto 0) := (
        others => '0'
      );
      constant result_low_to_high : std_ulogic_vector(0 to addrs(0).mask'high) := (
        others => '0'
      );
    begin
      if loop_bits_high_to_low then
        return result_high_to_low;
      end if;

      return result_low_to_high;
    end function;
    constant bit_loop_range : std_ulogic_vector := get_bit_loop_range;

    variable masked : addr_t := (others => '0');
    variable result : addr_and_mask_vec_t(addrs'range) := addrs;
  begin
    masked := addrs(addr_idx).addr and addrs(addr_idx).mask;

    for bit_idx in bit_loop_range'range loop
      if result(addr_idx).mask(bit_idx) then
        -- Attempt to remove this bit from the mask.
        -- If this results in overlap, change back.
        result(addr_idx).mask(bit_idx) := '0';

        if not sanity_check_address_and_mask(data=>result, verbose=>false) then
          result(addr_idx).mask(bit_idx) := '1';
        end if;
      end if;
    end loop;

    return result;
  end function;

  function get_mask_cost(data : addr_and_mask_vec_t) return natural is
    variable result : natural := 0;
  begin
    for addr_idx in data'range loop
      result := result + count_ones(data(addr_idx).mask);
    end loop;

    return result;
  end function;

  function calculate_minimal_mask(addrs : addr_vec_t) return addr_and_mask_vec_t is
    variable mask : addr_t := (others => '0');
    variable initial, result_high_to_low, result_low_to_high, result : addr_and_mask_vec_t(
      addrs'range
    ) := (others => addr_and_mask_init);
  begin
    -- Check that input is valid.
    assert sanity_check_base_addresses(addrs)
      report "The supplied address set is invalid. See messages above."
      severity failure;

    -- Calculate and assign an initial mask.
    for addr_idx in addrs'range loop
      mask := mask or addrs(addr_idx);
      initial(addr_idx).addr := addrs(addr_idx);
    end loop;

    for addr_idx in initial'range loop
      initial(addr_idx).mask := mask;
    end loop;

    -- Check that initial result is valid.
    assert sanity_check_address_and_mask(initial)
      report "Calculated initial mask is not valid. This is an internal error."
      severity failure;

    result := initial;

    -- Minimize the initial result.
    -- The loop below will start on the lowest address index and proceed up.
    -- This ordering has not been shown to impact the result masks nor the cost in any way, in the
    -- three tests in the test bench.
    -- Switching the bit index loop in 'minimize_mask' yields different mask as well as cost.
    -- In the three test cases, one was the same, one was better high to low, one was better low
    -- to high.
    for addr_idx in initial'range loop
      result_high_to_low := minimize_mask(
        addrs=>result, addr_idx=>addr_idx, loop_bits_high_to_low=>true
      );
      result_low_to_high := minimize_mask(
        addrs=>result, addr_idx=>addr_idx, loop_bits_high_to_low=>false
      );

      if get_mask_cost(result_high_to_low) <= get_mask_cost(result_low_to_high) then
        result := result_high_to_low;
      else
        result := result_low_to_high;
      end if;
    end loop;

    -- Can use calls like the ones below to debug/inspect the process.
    print_addr_and_mask_vec(result);
    report "Cost = " & integer'image(get_mask_cost(result)) severity note;

    return result;
  end function;

end package body;
