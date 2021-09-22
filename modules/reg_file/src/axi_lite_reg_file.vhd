-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the tsfpga project.
-- https://tsfpga.com
-- https://gitlab.com/tsfpga/tsfpga
-- -------------------------------------------------------------------------------------------------
-- General register file controlled over AXI-Lite.
-- -------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library common;
use common.addr_pkg.all;

library axi;
use axi.axi_pkg.all;
use axi.axi_lite_pkg.all;

use work.reg_file_pkg.all;


entity axi_lite_reg_file is
  generic (
    regs : reg_definition_vec_t;
    default_values : reg_vec_t(regs'range) := (others => (others => '0'))
  );
  port (
    clk : in std_logic;
    -- Register control bus
    axi_lite_m2s : in axi_lite_m2s_t;
    axi_lite_s2m : out axi_lite_s2m_t := (
      read => (
        ar => (ready => '1'),
        r => axi_lite_s2m_r_init),
      write => (
        aw => (ready => '1'),
        w => axi_lite_s2m_w_init,
        b => axi_lite_s2m_b_init)
      );
    -- Register values
    regs_up : in reg_vec_t(regs'range) := default_values;
    regs_down : out reg_vec_t(regs'range) := default_values;
    -- Each bit is pulsed for one cycle when the corresponding register is read/written
    reg_was_read : out std_logic_vector(regs'range) := (others => '0');
    reg_was_written : out std_logic_vector(regs'range) := (others => '0')
  );
end entity;

architecture a of axi_lite_reg_file is

  constant addr_and_mask_vec : addr_and_mask_vec_t := to_addr_and_mask_vec(regs);

  signal reg_values : reg_vec_t(regs'range) := default_values;

  constant invalid_addr : integer := regs'length;
  subtype decoded_idx_t is integer range 0 to invalid_addr;

begin

  regs_down <= reg_values;


  ------------------------------------------------------------------------------
  read_block : block
    type read_state_t is (ar, r);
    signal read_state : read_state_t := ar;
    signal read_idx : decoded_idx_t := invalid_addr;
    signal valid_read_address : boolean := false;
  begin

    -- An address transaction has occured and the address points to a valid read register
    valid_read_address <= read_idx /= invalid_addr and is_read_type(regs(read_idx).reg_type);

    read_process : process
    begin
      wait until rising_edge(clk);

      axi_lite_s2m.read.r.valid <= '0';

      reg_was_read <= (others => '0');

      if valid_read_address then
        axi_lite_s2m.read.r.resp <= axi_resp_okay;

        if is_fabric_gives_value_type(regs(read_idx).reg_type) then
          axi_lite_s2m.read.r.data(reg_values(0)'range) <= regs_up(read_idx);
        else
          axi_lite_s2m.read.r.data(reg_values(0)'range) <= reg_values(read_idx);
        end if;
      else
        axi_lite_s2m.read.r.resp <= axi_resp_slverr;
        axi_lite_s2m.read.r.data <= (others => '-');
      end if;

      case read_state is
        when ar =>
          if axi_lite_m2s.read.ar.valid and axi_lite_s2m.read.ar.ready then
            axi_lite_s2m.read.ar.ready <= '0';
            read_idx <= decode(axi_lite_m2s.read.ar.addr, addr_and_mask_vec);

            read_state <= r;
          end if;

        when r =>
          axi_lite_s2m.read.r.valid <= '1';
          if axi_lite_m2s.read.r.ready and axi_lite_s2m.read.r.valid then
            axi_lite_s2m.read.r.valid <= '0';
            axi_lite_s2m.read.ar.ready <= '1';

            if valid_read_address then
              reg_was_read(read_idx) <= '1';
            end if;

            read_state <= ar;
          end if;
      end case;
    end process;
  end block;


  ------------------------------------------------------------------------------
  write_block : block
    type write_state_t is (aw, w, b);
    signal write_state : write_state_t := aw;
    signal write_idx : decoded_idx_t := invalid_addr;
    signal valid_write_address : boolean := false;
  begin

    -- Constrain initial state value to be valid enum. It seems the formal check will allow enums
    -- to assume invalid (initial) values.
    -- psl write_state_enum_should_be_valid : assert always
    --   (write_state = aw or write_state = w or write_state = b) @ rising_edge(clk);

    -- An address transaction has occured and the address points to a valid write register
    valid_write_address <= write_idx /= invalid_addr and is_write_type(regs(write_idx).reg_type);

    write_process : process
    begin
      wait until rising_edge(clk);

      reg_was_written <= (others => '0');

      if valid_write_address then
        axi_lite_s2m.write.b.resp <= axi_resp_okay;
      else
        axi_lite_s2m.write.b.resp <= axi_resp_slverr;
      end if;

      for list_idx in regs'range loop
        if is_write_pulse_type(regs(list_idx).reg_type) then
          -- Set default value zero. If a write occurs to this register, the value
          -- will be asserted for one cycle below.
          reg_values(list_idx) <= (others => '0');
        end if;
      end loop;

      case write_state is
        when aw =>
          if axi_lite_m2s.write.aw.valid and axi_lite_s2m.write.aw.ready then
            axi_lite_s2m.write.aw.ready <= '0';
            axi_lite_s2m.write.w.ready <= '1';

            write_idx <= decode(axi_lite_m2s.write.aw.addr, addr_and_mask_vec);
            write_state <= w;
          end if;

        when w =>
          if axi_lite_m2s.write.w.valid and axi_lite_s2m.write.w.ready then
            if valid_write_address then
              reg_values(write_idx) <= axi_lite_m2s.write.w.data(reg_values(0)'range);
              reg_was_written(write_idx) <= '1';
            end if;

            axi_lite_s2m.write.w.ready <= '0';
            axi_lite_s2m.write.b.valid <= '1';

            write_state <= b;
          end if;

        when b =>
          if axi_lite_m2s.write.b.ready and axi_lite_s2m.write.b.valid then
            axi_lite_s2m.write.aw.ready <= '1';
            axi_lite_s2m.write.b.valid <= '0';
            write_state <= aw;
          end if;
      end case;
    end process;
  end block;


  ------------------------------------------------------------------------------
  psl_block : block
    constant reg_was_accessed_zero : std_logic_vector(reg_was_read'range) := (others => '0');
  begin
    -- psl default clock is rising_edge(clk);
    --
    -- psl reg_was_written_should_pulse_only_one_clock_cycle : assert always
    --   {reg_was_written /= reg_was_accessed_zero} |=> (reg_was_written = reg_was_accessed_zero);
    --
    -- psl reg_was_read_should_pulse_only_one_clock_cycle : assert always
    --   {reg_was_read /= reg_was_accessed_zero} |=> (reg_was_read = reg_was_accessed_zero);
    --
    -- Asserting reg_was_read typically prompts something in the PL that changes the register value.
    -- Hence it is important that reg_was_read is asserted after the actual read (R) transaction
    -- has occured, and not e.g. after the AR transaction.
    -- psl reg_was_read_should_pulse_when_read_transaction_occurs : assert always
    --   (reg_was_read /= reg_was_accessed_zero) -> prev(axi_lite_m2s.read.r.ready and axi_lite_s2m.read.r.valid);
  end block;

end architecture;
