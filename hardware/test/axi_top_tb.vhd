
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

entity axi_top_tb is
end axi_top_tb;

architecture tb of axi_top_tb is
  constant clk_period     : time    := 10 ns;
  constant BUS_ADDR_WIDTH              : natural := 64;
  constant BUS_DATA_WIDTH              : natural := 512;
  constant BUS_STROBE_WIDTH            : natural := 64;
  constant BUS_LEN_WIDTH               : natural := 8;
  constant BUS_BURST_MAX_LEN           : natural := 64;
  constant BUS_BURST_STEP_LEN          : natural := 1;
  constant SLV_BUS_ADDR_WIDTH          : natural := 32;
  constant SLV_BUS_DATA_WIDTH          : natural := 32;
  constant TAG_WIDTH                   : natural := 1;
  constant NUM_ARROW_BUFFERS           : natural := 1;
  constant NUM_USER_REGS               : natural := 3;
  constant NUM_REGS                    : natural := 11;
  constant REG_WIDTH                   : natural := SLV_BUS_DATA_WIDTH;

  signal acc_clk                     :  std_logic;
  signal acc_reset                   :  std_logic;
  signal bus_clk                     :  std_logic;
  signal bus_reset_n                 :  std_logic;
  signal m_axi_araddr                :  std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
  signal m_axi_arlen                 :  std_logic_vector(7 downto 0);
  signal m_axi_arvalid               :  std_logic;
  signal m_axi_arready               :  std_logic;
  signal m_axi_arsize                :  std_logic_vector(2 downto 0);
  signal m_axi_rdata                 :  std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
  signal m_axi_rresp                 :  std_logic_vector(1 downto 0);
  signal m_axi_rlast                 :  std_logic;
  signal m_axi_rvalid                :  std_logic;
  signal m_axi_rready                :  std_logic;
  signal m_axi_awvalid               :  std_logic;
  signal m_axi_awready               :  std_logic;
  signal m_axi_awaddr                :  std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
  signal m_axi_awlen                 :  std_logic_vector(7 downto 0);
  signal m_axi_awsize                :  std_logic_vector(2 downto 0);
  signal m_axi_wvalid                :  std_logic;
  signal m_axi_wready                :  std_logic;
  signal m_axi_wdata                 :  std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
  signal m_axi_wlast                 :  std_logic;
  signal m_axi_wstrb                 :  std_logic_vector(BUS_DATA_WIDTH/8-1 downto 0);
  signal s_axi_awvalid               : std_logic;
  signal s_axi_awready               :  std_logic;
  signal s_axi_awaddr                : std_logic_vector(SLV_BUS_ADDR_WIDTH-1 downto 0);
  signal s_axi_wvalid                : std_logic;
  signal s_axi_wready                :  std_logic;
  signal s_axi_wdata                 : std_logic_vector(SLV_BUS_DATA_WIDTH-1 downto 0);
  signal s_axi_wstrb                 : std_logic_vector((SLV_BUS_DATA_WIDTH/8)-1 downto 0);
  signal s_axi_bvalid                :  std_logic;
  signal s_axi_bready                : std_logic;
  signal s_axi_bresp                 :  std_logic_vector(1 downto 0);
  signal s_axi_arvalid               : std_logic;
  signal s_axi_arready               :  std_logic;
  signal s_axi_araddr                : std_logic_vector(SLV_BUS_ADDR_WIDTH-1 downto 0);
  signal s_axi_rvalid                :  std_logic;
  signal s_axi_rready                : std_logic;
  signal s_axi_rdata                 :  std_logic_vector(SLV_BUS_DATA_WIDTH-1 downto 0);
  signal s_axi_rresp                 :  std_logic_vector(1 downto 0);
begin
  dut: entity work.axi_top
  generic map(
    BUS_ADDR_WIDTH     => BUS_ADDR_WIDTH,    
    BUS_DATA_WIDTH     => BUS_DATA_WIDTH,    
    BUS_STROBE_WIDTH   => BUS_STROBE_WIDTH,  
    BUS_LEN_WIDTH      => BUS_LEN_WIDTH,     
    BUS_BURST_MAX_LEN  => BUS_BURST_MAX_LEN, 
    BUS_BURST_STEP_LEN => BUS_BURST_STEP_LEN,
    SLV_BUS_ADDR_WIDTH => SLV_BUS_ADDR_WIDTH,
    SLV_BUS_DATA_WIDTH => SLV_BUS_DATA_WIDTH,
    TAG_WIDTH          => TAG_WIDTH,         
    NUM_ARROW_BUFFERS  => NUM_ARROW_BUFFERS, 
    NUM_USER_REGS      => NUM_USER_REGS,     
    NUM_REGS           => NUM_REGS,          
    REG_WIDTH          => REG_WIDTH)
  port map(
    acc_clk            => acc_clk,
    acc_reset          => acc_reset,
    bus_clk            => bus_clk,
    bus_reset_n        => bus_reset_n,
    m_axi_araddr       => m_axi_araddr,
    m_axi_arlen        => m_axi_arlen,
    m_axi_arvalid      => m_axi_arvalid,
    m_axi_arready      => m_axi_arready,
    m_axi_arsize       => m_axi_arsize,
    m_axi_rdata        => m_axi_rdata,
    m_axi_rresp        => m_axi_rresp,
    m_axi_rlast        => m_axi_rlast,
    m_axi_rvalid       => m_axi_rvalid,
    m_axi_rready       => m_axi_rready,
    m_axi_awvalid      => m_axi_awvalid,
    m_axi_awready      => m_axi_awready,
    m_axi_awaddr       => m_axi_awaddr,
    m_axi_awlen        => m_axi_awlen,
    m_axi_awsize       => m_axi_awsize,
    m_axi_wvalid       => m_axi_wvalid,
    m_axi_wready       => m_axi_wready,
    m_axi_wdata        => m_axi_wdata,
    m_axi_wlast        => m_axi_wlast,
    m_axi_wstrb        => m_axi_wstrb,
    s_axi_awvalid      => s_axi_awvalid,
    s_axi_awready      => s_axi_awready,
    s_axi_awaddr       => s_axi_awaddr,
    s_axi_wvalid       => s_axi_wvalid,
    s_axi_wready       => s_axi_wready,
    s_axi_wdata        => s_axi_wdata,
    s_axi_wstrb        => s_axi_wstrb,
    s_axi_bvalid       => s_axi_bvalid,
    s_axi_bready       => s_axi_bready,
    s_axi_bresp        => s_axi_bresp,
    s_axi_arvalid      => s_axi_arvalid,
    s_axi_arready      => s_axi_arready,
    s_axi_araddr       => s_axi_araddr,
    s_axi_rvalid       => s_axi_rvalid,
    s_axi_rready       => s_axi_rready,
    s_axi_rdata        => s_axi_rdata,
    s_axi_rresp        => s_axi_rresp  
  );

  --Don't care about these signals
  acc_clk       <= '0';
  acc_reset     <= '0';
  s_axi_awvalid <= '0';
  s_axi_awaddr  <= (others => '0');
  s_axi_wvalid  <= '0';
  s_axi_wdata   <= (others => '0');
  s_axi_wstrb   <= (others => '0');
  s_axi_bready  <= '0';
  s_axi_arvalid <= '0';
  s_axi_araddr  <= (others => '0');
  s_axi_rready  <= '0';

  values_p: process is
  begin
    m_axi_arready <= '0';
    m_axi_rvalid <= '0';
    m_axi_rdata <= (others => '0');

    loop
      wait until rising_edge(bus_clk);
      exit when bus_reset_n = '1';
    end loop;

    m_axi_arready <= '1';

    loop
      wait until rising_edge(bus_clk);
      exit when m_axi_arvalid = '1';
    end loop;

    m_axi_arready <= '0';

    m_axi_rvalid <= '1';
    -- A dictionary page header pulled from a random Parquet file
    m_axi_rdata(BUS_DATA_WIDTH - 1 downto BUS_DATA_WIDTH - (34 * 4)) <= x"150415807d15807d4c15d00f1504120000";
    m_axi_rdata(BUS_DATA_WIDTH - (34 * 4) -1 downto 64) <= (others => '0');
    -- Write a value to other side of bus to check if correct side of bus is being read
    m_axi_rdata(63 downto 0) <= x"deadbeefabcd0000";

    loop
      wait until rising_edge(bus_clk);
      exit when m_axi_rready = '1';
    end loop;

    m_axi_rvalid <= '0';
    m_axi_rdata <= (others => '0');

    wait;
  end process;

  clk_p :process
  begin
    bus_clk <= '0';
    wait for clk_period/2;
    bus_clk <= '1';
    wait for clk_period/2;
  end process;

  reset_p: process is
  begin
    bus_reset_n <= '0';
    wait for 10 ns;
    wait until rising_edge(bus_clk);
    bus_reset_n <= '1';
    wait;
  end process;

end architecture;