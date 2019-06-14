
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

-- This file was automatically generated by FletchGen. Modify this file
-- at your own risk.

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.all;

library work;
-- Fletcher
use work.Interconnect_pkg.all;
use work.Wrapper_pkg.all;

-- Ptoa
use work.Ptoa.all;


entity ptoa_wrapper is
  generic(
    BUS_ADDR_WIDTH                             : natural;
    BUS_DATA_WIDTH                             : natural;
    BUS_STROBE_WIDTH                           : natural;
    BUS_LEN_WIDTH                              : natural;
    BUS_BURST_STEP_LEN                         : natural;
    BUS_BURST_MAX_LEN                          : natural;
    ---------------------------------------------------------------------------
    INDEX_WIDTH                                : natural;
    ---------------------------------------------------------------------------
    NUM_ARROW_BUFFERS                          : natural;
    NUM_REGS                                   : natural;
    REG_WIDTH                                  : natural;
    ---------------------------------------------------------------------------
    TAG_WIDTH                                  : natural
  );
  port(
    acc_reset                                  : in std_logic;
    bus_clk                                    : in std_logic;
    bus_reset                                  : in std_logic;
    acc_clk                                    : in std_logic;
    ---------------------------------------------------------------------------
    mst_rreq_valid                             : out std_logic;
    mst_rreq_ready                             : in std_logic;
    mst_rreq_addr                              : out std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
    mst_rreq_len                               : out std_logic_vector(BUS_LEN_WIDTH-1 downto 0);
    ---------------------------------------------------------------------------
    mst_rdat_valid                             : in std_logic;
    mst_rdat_ready                             : out std_logic;
    mst_rdat_data                              : in std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
    mst_rdat_last                              : in std_logic;
    ---------------------------------------------------------------------------
    mst_wreq_valid                             : out std_logic;
    mst_wreq_len                               : out std_logic_vector(BUS_LEN_WIDTH-1 downto 0);
    mst_wreq_addr                              : out std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
    mst_wreq_ready                             : in std_logic;
    ---------------------------------------------------------------------------
    mst_wdat_valid                             : out std_logic;
    mst_wdat_ready                             : in std_logic;
    mst_wdat_data                              : out std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
    mst_wdat_strobe                            : out std_logic_vector(BUS_STROBE_WIDTH-1 downto 0);
    mst_wdat_last                              : out std_logic;
    ---------------------------------------------------------------------------
    regs_in                                    : in std_logic_vector(NUM_REGS*REG_WIDTH-1 downto 0);
    regs_out                                   : out std_logic_vector(NUM_REGS*REG_WIDTH-1 downto 0);
    regs_out_en                                : out std_logic_vector(NUM_REGS-1 downto 0)
  );
end ptoa_wrapper;

architecture behv of ptoa_wrapper is
  ---------------------------------------
  -- Register offsets
  ---------------------------------------
  constant REG_CONTROL                       : natural := 0;
  constant REG_STATUS                        : natural := 1;
  constant REG_NUM_VAL                       : natural := 2;
  constant REG_PAGE_ADDR0                    : natural := 3;
  constant REG_PAGE_ADDR1                    : natural := 4;
  constant REG_MAX_SIZE0                     : natural := 5;
  constant REG_MAX_SIZE1                     : natural := 6;
  constant REG_VAL_ADDR0                     : natural := 7;
  constant REG_VAL_ADDR1                     : natural := 8;
  constant REG_OFF_ADDR0                     : natural := 9;
  constant REG_OFF_ADDR1                     : natural := 10;

  ---------------------------------------
  -- Fletcher UserCoreController signals
  ---------------------------------------
  signal uctrl_start                         : std_logic;
  signal uctrl_stop                          : std_logic;
  signal uctrl_reset                         : std_logic;
  signal uctrl_done                          : std_logic;

  ---------------------------------------
  -- Fletcher read/write arbiter signals
  ---------------------------------------
  signal bsv_rreq_len                        : std_logic_vector(BUS_LEN_WIDTH-1 downto 0);
  signal bsv_rreq_addr                       : std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
  signal bsv_rreq_ready                      : std_logic_vector(0 downto 0);
  signal bsv_rreq_valid                      : std_logic_vector(0 downto 0);

  signal bsv_rdat_valid                      : std_logic_vector(0 downto 0);
  signal bsv_rdat_ready                      : std_logic_vector(0 downto 0);
  signal bsv_rdat_data                       : std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
  signal bsv_rdat_last                       : std_logic_vector(0 downto 0);

  signal bsv_wreq_len                        : std_logic_vector(BUS_LEN_WIDTH-1 downto 0);
  signal bsv_wreq_valid                      : std_logic_vector(0 downto 0);
  signal bsv_wreq_ready                      : std_logic_vector(0 downto 0);
  signal bsv_wreq_addr                       : std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);

  signal bsv_wdat_valid                      : std_logic_vector(0 downto 0);
  signal bsv_wdat_last                       : std_logic_vector(0 downto 0);
  signal bsv_wdat_strobe                     : std_logic_vector(BUS_STROBE_WIDTH-1 downto 0);
  signal bsv_wdat_data                       : std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
  signal bsv_wdat_ready                      : std_logic_vector(0 downto 0);

  -- ParquetReader reset
  signal pr_reset                            : std_logic;

begin
  
  -- Only the status register needs to be written to
  regs_out_en(REG_CONTROL)     <= '0';
  regs_out_en(REG_STATUS)      <= '1';
  regs_out_en(REG_NUM_VAL)     <= '0';
  regs_out_en(REG_PAGE_ADDR0)  <= '0';
  regs_out_en(REG_PAGE_ADDR1)  <= '0';
  regs_out_en(REG_MAX_SIZE0)   <= '0';
  regs_out_en(REG_MAX_SIZE1)   <= '0';
  regs_out_en(REG_VAL_ADDR0)   <= '0';
  regs_out_en(REG_VAL_ADDR1)   <= '0';
  regs_out_en(REG_OFF_ADDR0)   <= '0';
  regs_out_en(REG_OFF_ADDR1)   <= '0';

  -- Reset the ParquetReader when the UserCoreController or the top level requests it
  pr_reset <= uctrl_reset or bus_reset;

  -- Fletcher controller as a stand-in for future ptoa specific controller
  UserCoreController_inst: UserCoreController
    generic map (
      REG_WIDTH                                => REG_WIDTH
    )
    port map (
      kcd_clk                                  => acc_clk,
      kcd_reset                                => acc_reset,
      bcd_clk                                  => bus_clk,
      bcd_reset                                => bus_reset,
      status                                   => regs_out((REG_STATUS+1)*REG_WIDTH-1 downto REG_WIDTH*REG_STATUS),
      control                                  => regs_in((REG_CONTROL+1)*REG_WIDTH-1 downto REG_WIDTH*REG_CONTROL),
      start                                    => uctrl_start,
      stop                                     => uctrl_stop,
      reset                                    => uctrl_reset,
      idle                                     => '0',
      busy                                     => '0',
      done                                     => uctrl_done
    );

  prim32_reader_inst: ParquetReader
    generic map(
      BUS_ADDR_WIDTH                           => BUS_ADDR_WIDTH,
      BUS_DATA_WIDTH                           => BUS_DATA_WIDTH,
      BUS_STROBE_WIDTH                         => BUS_STROBE_WIDTH,
      BUS_LEN_WIDTH                            => BUS_LEN_WIDTH,
      BUS_BURST_STEP_LEN                       => BUS_BURST_STEP_LEN,
      BUS_BURST_MAX_LEN                        => BUS_BURST_MAX_LEN,
      ---------------------------------------------------------------------------------
      INDEX_WIDTH                              => INDEX_WIDTH,
      ---------------------------------------------------------------------------------
      TAG_WIDTH                                => TAG_WIDTH,
      CFG                                      => "listprim(8;lepc=4,epc=64)",
      ENCODING                                 => "DELTA_LENGTH",
      --CFG                                      => "prim(32;epc=8)",
      --ENCODING                                 => "DELTA",
      COMPRESSION_CODEC                        => "UNCOMPRESSED"
    )
    port map(
      clk                                      => bus_clk,
      reset                                    => pr_reset,
      bus_rreq_valid                           => bsv_rreq_valid(0),
      bus_rreq_ready                           => bsv_rreq_ready(0),
      bus_rreq_addr                            => bsv_rreq_addr,
      bus_rreq_len                             => bsv_rreq_len,
      bus_rdat_valid                           => bsv_rdat_valid(0),
      bus_rdat_ready                           => bsv_rdat_ready(0),
      bus_rdat_data                            => bsv_rdat_data,
      bus_rdat_last                            => bsv_rdat_last(0),
      bus_wreq_valid                           => bsv_wreq_valid(0),
      bus_wreq_len                             => bsv_wreq_len,
      bus_wreq_addr                            => bsv_wreq_addr,
      bus_wreq_ready                           => bsv_wreq_ready(0),
      bus_wdat_valid                           => bsv_wdat_valid(0),
      bus_wdat_ready                           => bsv_wdat_ready(0),
      bus_wdat_data                            => bsv_wdat_data,
      bus_wdat_strobe                          => bsv_wdat_strobe,
      bus_wdat_last                            => bsv_wdat_last(0),
      base_pages_ptr                           => regs_in((REG_PAGE_ADDR1+1)*REG_WIDTH-1 downto REG_WIDTH*REG_PAGE_ADDR0),
      max_data_size                            => regs_in((REG_MAX_SIZE1+1)*REG_WIDTH-1 downto REG_WIDTH*REG_MAX_SIZE0),
      total_num_values                         => regs_in((REG_NUM_VAL+1)*REG_WIDTH-1 downto REG_WIDTH*REG_NUM_VAL),
      values_buffer_addr                       => regs_in((REG_VAL_ADDR1+1)*REG_WIDTH-1 downto REG_WIDTH*REG_VAL_ADDR0),
      offsets_buffer_addr                      => regs_in((REG_OFF_ADDR1+1)*REG_WIDTH-1 downto REG_WIDTH*REG_OFF_ADDR0),
      start                                    => uctrl_start,
      stop                                     => uctrl_stop,
      done                                     => uctrl_done
    );

  -- Fletcher BusWriteArbiter
  BusWriteArbiterVec_inst: BusWriteArbiterVec
    generic map (
      BUS_ADDR_WIDTH                           => BUS_ADDR_WIDTH,
      BUS_LEN_WIDTH                            => BUS_LEN_WIDTH,
      BUS_DATA_WIDTH                           => BUS_DATA_WIDTH,
      BUS_STROBE_WIDTH                         => BUS_STROBE_WIDTH,
      NUM_SLAVE_PORTS                          => 1,
      MAX_OUTSTANDING                          => 16
    )
    port map (
      bcd_clk                                  => bus_clk,
      bcd_reset                                => bus_reset,
      bsv_wdat_valid                           => bsv_wdat_valid,
      bsv_wdat_ready                           => bsv_wdat_ready,
      bsv_wdat_data                            => bsv_wdat_data,
      bsv_wdat_strobe                          => bsv_wdat_strobe,
      bsv_wdat_last                            => bsv_wdat_last,
      bsv_wreq_valid                           => bsv_wreq_valid,
      bsv_wreq_ready                           => bsv_wreq_ready,
      bsv_wreq_addr                            => bsv_wreq_addr,
      bsv_wreq_len                             => bsv_wreq_len,
      mst_wreq_valid                           => mst_wreq_valid,
      mst_wreq_ready                           => mst_wreq_ready,
      mst_wreq_addr                            => mst_wreq_addr,
      mst_wreq_len                             => mst_wreq_len,
      mst_wdat_valid                           => mst_wdat_valid,
      mst_wdat_ready                           => mst_wdat_ready,
      mst_wdat_data                            => mst_wdat_data,
      mst_wdat_strobe                          => mst_wdat_strobe,
      mst_wdat_last                            => mst_wdat_last
    );

  -- Fletcher BusReadArbiter
  BusReadArbiterVec_inst: BusReadArbiterVec
    generic map (
      BUS_ADDR_WIDTH                           => BUS_ADDR_WIDTH,
      BUS_LEN_WIDTH                            => BUS_LEN_WIDTH,
      BUS_DATA_WIDTH                           => BUS_DATA_WIDTH,
      NUM_SLAVE_PORTS                          => 1,
      MAX_OUTSTANDING                          => 16
    )
    port map (
      bcd_clk                                  => bus_clk,
      bcd_reset                                => bus_reset,
      bsv_rreq_valid                           => bsv_rreq_valid,
      bsv_rreq_ready                           => bsv_rreq_ready,
      bsv_rreq_addr                            => bsv_rreq_addr,
      bsv_rreq_len                             => bsv_rreq_len,
      bsv_rdat_valid                           => bsv_rdat_valid,
      bsv_rdat_ready                           => bsv_rdat_ready,
      bsv_rdat_data                            => bsv_rdat_data,
      bsv_rdat_last                            => bsv_rdat_last,
      mst_rreq_valid                           => mst_rreq_valid,
      mst_rreq_ready                           => mst_rreq_ready,
      mst_rreq_addr                            => mst_rreq_addr,
      mst_rreq_len                             => mst_rreq_len,
      mst_rdat_valid                           => mst_rdat_valid,
      mst_rdat_ready                           => mst_rdat_ready,
      mst_rdat_data                            => mst_rdat_data,
      mst_rdat_last                            => mst_rdat_last
    );

end architecture;