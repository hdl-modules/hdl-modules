-- -------------------------------------------------------------------------------------------------
-- Copyright (c) Lukas Vik. All rights reserved.
--
-- This file is part of the hdl-modules project, a collection of reusable, high-quality,
-- peer-reviewed VHDL building blocks.
-- https://hdl-modules.com
-- https://github.com/hdl-modules/hdl-modules
-- -------------------------------------------------------------------------------------------------
-- Pipeline the ``AW``, ``W`` and ``B`` channels of an AXI write bus.
-- The generics can be used to control throughput settings, which affects the logic footprint.
-- -------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library common;

use work.axi_pkg.all;


entity axi_write_pipeline is
  generic (
    addr_width : positive range 1 to axi_a_addr_sz;
    id_width : natural range 0 to axi_id_sz;
    data_width : positive range 8 to axi_data_sz;
    -- Can be changed from default in order to decrease logic utilization, at the cost of lower
    -- throughput. See handshake_pipeline for details.
    full_address_throughput : boolean := true;
    full_data_throughput : boolean := true
  );
  port (
    clk : in std_ulogic;
    --# {{}}
    left_m2s : in axi_write_m2s_t;
    left_s2m : out axi_write_s2m_t := axi_write_s2m_init;
    --# {{}}
    right_m2s : out axi_write_m2s_t := axi_write_m2s_init;
    right_s2m : in axi_write_s2m_t
  );
end entity;

architecture a of axi_write_pipeline is

begin

  ------------------------------------------------------------------------------
  aw_block : block
    constant a_width : positive := axi_m2s_a_sz(id_width=>id_width, addr_width=>addr_width);

    signal input_data, output_data : std_ulogic_vector(a_width - 1 downto 0) := (others => '0');
    signal output_valid : std_ulogic := '0';
  begin

    ------------------------------------------------------------------------------
    assign : process(all)
    begin
      input_data <= to_slv(data=>left_m2s.aw, id_width=>id_width, addr_width=>addr_width);

      right_m2s.aw <= to_axi_m2s_a(data=>output_data, id_width=>id_width, addr_width=>addr_width);
      right_m2s.aw.valid <= output_valid;
    end process;


    ------------------------------------------------------------------------------
    handshake_pipeline_inst : entity common.handshake_pipeline
      generic map (
        data_width => input_data'length,
        full_throughput => full_address_throughput,
        pipeline_control_signals => true,
        pipeline_data_signals => true
      )
      port map(
        clk => clk,
        --
        input_ready => left_s2m.aw.ready,
        input_valid => left_m2s.aw.valid,
        input_data => input_data,
        --
        output_ready => right_s2m.aw.ready,
        output_valid => output_valid,
        output_data => output_data
      );

  end block;


  ------------------------------------------------------------------------------
  w_block : block
    -- Assume AXI4 (no WID)
    constant w_width : positive := axi_m2s_w_sz(data_width=>data_width, id_width=>0);

    signal input_data, output_data : std_ulogic_vector(w_width - 1 downto 0) := (others => '0');
    signal output_valid : std_ulogic := '0';
  begin

    ------------------------------------------------------------------------------
    assign : process(all)
    begin
      input_data <= to_slv(data=>left_m2s.w, data_width=>data_width);

      right_m2s.w <= to_axi_m2s_w(data=>output_data, data_width=>data_width);
      right_m2s.w.valid <= output_valid;
    end process;


    ------------------------------------------------------------------------------
    handshake_pipeline_inst : entity common.handshake_pipeline
      generic map (
        data_width => input_data'length,
        full_throughput => full_data_throughput,
        pipeline_control_signals => true,
        pipeline_data_signals => true
      )
      port map(
        clk => clk,
        --
        input_ready => left_s2m.w.ready,
        input_valid => left_m2s.w.valid,
        input_data => input_data,
        --
        output_ready => right_s2m.w.ready,
        output_valid => output_valid,
        output_data => output_data
      );

  end block;


  ------------------------------------------------------------------------------
  b_block : block
    constant b_width : positive := axi_s2m_b_sz(id_width => id_width);

    signal input_data, output_data : std_ulogic_vector(b_width - 1 downto 0) := (others => '0');
    signal output_valid : std_ulogic := '0';
  begin

    ------------------------------------------------------------------------------
    assign : process(all)
    begin
      input_data <= to_slv(data=>right_s2m.b, id_width=>id_width);

      left_s2m.b <= to_axi_s2m_b(data=>output_data, id_width=>id_width);
      left_s2m.b.valid <= output_valid;
    end process;


    ------------------------------------------------------------------------------
    handshake_pipeline_inst : entity common.handshake_pipeline
      generic map (
        data_width => input_data'length,
        full_throughput => full_address_throughput,
        pipeline_control_signals => true,
        pipeline_data_signals => true
      )
      port map(
        clk => clk,
        --
        input_ready => right_m2s.b.ready,
        input_valid => right_s2m.b.valid,
        input_data => input_data,
        --
        output_ready => left_m2s.b.ready,
        output_valid => output_valid,
        output_data => output_data
      );

  end block;

end architecture;
