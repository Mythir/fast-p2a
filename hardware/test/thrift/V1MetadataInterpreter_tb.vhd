
-- Copyright 2018 Delft University of Technology
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--     http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;

-- Todo: Description

entity MetadataInterpreter_tb is
end MetadataInterpreter_tb;

architecture tb of MetadataInterpreter_tb is
  constant clk_period                : time    := 10 ns;
  constant METADATA_WIDTH            : natural := 512;
  constant BUS_ADDR_WIDTH            : natural := 64;
  constant BUS_DATA_WIDTH            : natural := 512;
  constant BUS_LEN_WIDTH             : natural := 8;
  constant NUM_REGS                  : natural := 11;
  constant CYCLE_COUNT_WIDTH         : natural := 8;

  signal clk                         :  std_logic;
  signal hw_reset                    :  std_logic;
  signal mst_rreq_valid              :  std_logic;
  signal mst_rreq_ready              :  std_logic;
  signal mst_rreq_addr               :  std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
  signal mst_rreq_len                :  std_logic_vector(BUS_LEN_WIDTH-1 downto 0);
  signal mst_rdat_valid              :  std_logic;
  signal mst_rdat_ready              :  std_logic;
  signal mst_rdat_data               :  std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
  signal mst_rdat_last               :  std_logic;
  signal ctrl_done                   :  std_logic;
  signal ctrl_busy                   :  std_logic;
  signal ctrl_idle                   :  std_logic;
  signal ctrl_reset                  :  std_logic;
  signal ctrl_stop                   :  std_logic;
  signal ctrl_start                  :  std_logic;
  signal md_uncomp_size              :  std_logic_vector(31 downto 0);
  signal md_comp_size                :  std_logic_vector(31 downto 0);
  signal md_num_values               :  std_logic_vector(31 downto 0);
  signal cycle_count                 :  std_logic_vector(CYCLE_COUNT_WIDTH-1 downto 0);
  signal regs_out_en                 :  std_logic_vector(NUM_REGS-1 downto 0);
  signal md_addr                     :  std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
begin
  dut : entity work.MetadataInterpreter
  generic map(
    METADATA_WIDTH => METADATA_WIDTH,
    BUS_ADDR_WIDTH => BUS_ADDR_WIDTH,
    BUS_DATA_WIDTH => BUS_DATA_WIDTH,
    BUS_LEN_WIDTH  => BUS_LEN_WIDTH,
    NUM_REGS       => NUM_REGS)
  port map(
    clk             => clk,             
    hw_reset        => hw_reset,        
    mst_rreq_valid  => mst_rreq_valid,  
    mst_rreq_ready  => mst_rreq_ready,  
    mst_rreq_addr   => mst_rreq_addr,   
    mst_rreq_len    => mst_rreq_len,
    mst_rdat_valid  => mst_rdat_valid,  
    mst_rdat_ready  => mst_rdat_ready,  
    mst_rdat_data   => mst_rdat_data,   
    mst_rdat_last   => mst_rdat_last,   
    ctrl_done       => ctrl_done,       
    ctrl_busy       => ctrl_busy,       
    ctrl_idle       => ctrl_idle,       
    ctrl_reset      => ctrl_reset,      
    ctrl_stop       => ctrl_stop,       
    ctrl_start      => ctrl_start,      
    md_uncomp_size  => md_uncomp_size,  
    md_comp_size    => md_comp_size,    
    md_num_values   => md_num_values,   
    cycle_count     => cycle_count,
    regs_out_en     => regs_out_en,    
    md_addr         => md_addr         
  );

  -- Don't care about these signals
  mst_rdat_last <= '0';
  ctrl_reset <= '0';
  ctrl_stop <= '0';
  md_addr <= (others => '0');

  values_p: process is
  begin
    mst_rreq_ready <= '0';
    mst_rdat_valid <= '0';
    mst_rdat_data <= (others => '0');

    loop
      wait until rising_edge(clk);
      exit when hw_reset = '0';
    end loop;

    mst_rreq_ready <= '1';

    loop
      wait until rising_edge(clk);
      exit when mst_rreq_valid = '1';
    end loop;

    mst_rreq_ready <= '0';

    mst_rdat_valid <= '1';
    -- Page header of a plain encoded and SNAPPY compressed data page with 10000 values.
    mst_rdat_data(BUS_DATA_WIDTH - 1 downto BUS_DATA_WIDTH - (50 * 4)) <= x"15001590e20915dcc3072c15a09c011500150615061c000000";
    mst_rdat_data(BUS_DATA_WIDTH - (50 * 4) -1 downto 64) <= (others => '0');
    -- Write a value to other side of bus to check if correct side of bus is being read
    mst_rdat_data(63 downto 0) <= x"deadbeefabcd0000";

    loop
      wait until rising_edge(clk);
      exit when mst_rdat_ready = '1';
    end loop;

    mst_rdat_valid <= '0';
    mst_rdat_data <= (others => '0');

    wait;
  end process;

  clk_p :process
  begin
    clk <= '0';
    wait for clk_period/2;
    clk <= '1';
    wait for clk_period/2;
  end process;

  reset_p: process is
  begin
    ctrl_start <= '0';
    hw_reset <= '1';
    wait for 10 ns;
    wait until rising_edge(clk);
    hw_reset <= '0';
    wait for 10 ns;
    ctrl_start <= '1';
    wait;
  end process;
end architecture;
