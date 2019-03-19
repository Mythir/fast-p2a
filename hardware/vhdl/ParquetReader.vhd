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
use ieee.std_logic_misc.all;

library work;

-- Fletcher
use work.Utils.all;
use work.Arrow.all;
use work.Columns.all;
use work.Interconnect.all;
use work.Wrapper.all;

-- Ptoa
use work.Encoding.all;
use work.Thrift.all;
use work.Ingestion.all;
use work.Alignment.all;

entity ParquetReader is
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
    NUM_USER_REGS                              : natural;
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
end ParquetReader;

architecture Implementation of ParquetReader is
  
  -- UserCoreController signals
  signal uctrl_done                            : std_logic;
  signal uctrl_busy                            : std_logic;
  signal uctrl_idle                            : std_logic;
  signal uctrl_reset                           : std_logic;
  signal uctrl_stop                            : std_logic;
  signal uctrl_start                           : std_logic;
  signal uctrl_control                         : std_logic_vector(REG_WIDTH-1 downto 0);
  signal uctrl_status                          : std_logic_vector(REG_WIDTH-1 downto 0);
  
  -- Metadata signals
  signal mdi_rl_byte_length                    : std_logic_vector(31 downto 0);
  signal mdi_dl_byte_length                    : std_logic_vector(31 downto 0);
  signal mdi_dc_uncomp_size                    : std_logic_vector(31 downto 0);
  signal mdi_dc_comp_size                      : std_logic_vector(31 downto 0);
  signal mdi_dd_num_values                     : std_logic_vector(31 downto 0);

  ----------------------------------------------------------------------------
  -- Streams
  ----------------------------------------------------------------------------
  -- Ingester to DataAligner data
  signal ing_da_valid                          : std_logic;
  signal ing_da_ready                          : std_logic;
  signal ing_da_data                           : std_logic_vector(BUS_DATA_WIDTH-1 downto 0);

  -- Ingester to DataAligner alignment
  signal prod_align_valid                      : std_logic;
  signal prod_align_ready                      : std_logic;
  signal prod_align_data                       : std_logic_vector(log2ceil(BUS_DATA_WIDTH/8)-1 downto 0);


begin

  -- Controller instance.
  UserCoreController_inst: UserCoreController
    generic map (
      REG_WIDTH                                => REG_WIDTH
    )
    port map (
      acc_clk                                  => acc_clk,
      acc_reset                                => acc_reset,
      bus_clk                                  => bus_clk,
      bus_reset                                => bus_reset,
      status                                   => regs_out(2*REG_WIDTH-1 downto REG_WIDTH),
      control                                  => regs_in(REG_WIDTH-1 downto 0),
      start                                    => uctrl_start,
      stop                                     => uctrl_stop,
      reset                                    => uctrl_reset,
      idle                                     => uctrl_idle,
      busy                                     => uctrl_busy,
      done                                     => uctrl_done
    );

    Ingester_inst: Ingester
    generic map(
      BUS_DATA_WIDTH      => BUS_DATA_WIDTH,
      BUS_ADDR_WIDTH      => BUS_ADDR_WIDTH,
      BUS_LEN_WIDTH       => BUS_LEN_WIDTH,
      BUS_BURST_MAX_LEN   => BUS_BURST_MAX_LEN,
      BUS_FIFO_DEPTH      => BUS_BURST_MAX_LEN
    )
    port map(
      clk                 => bus_clk,
      reset               => bus_reset,
      bus_rreq_valid      => mst_rreq_valid,
      bus_rreq_ready      => mst_rreq_ready,
      bus_rreq_addr       => mst_rreq_addr,
      bus_rreq_len        => mst_rreq_len,
      bus_rdat_valid      => mst_rdat_valid,
      bus_rdat_ready      => mst_rdat_ready,
      bus_rdat_data       => mst_rdat_data,
      bus_rdat_last       => mst_rdat_last,
      out_valid           => ing_da_valid,
      out_ready           => ing_da_ready,
      out_data            => ing_da_data,
      pa_valid            => ,
      pa_ready            => ,
      pa_data             => ,
      start               => ctrl_start,
      stop                => ctrl_stop,
      base_address        => ,
      data_size           => 
    );

  DataAligner_inst: DataAligner
    generic map(
      BUS_DATA_WIDTH              => BUS_DATA_WIDTH,
      NUM_CONSUMERS               => 2,
      NUM_SHIFT_STAGES            => log2ceil(BUS_DATA_WIDTH/8)
    )
    port map(
      clk                         => bus_clk,
      reset                       => bus_reset,
      in_valid                    => ing_da_valid,
      in_ready                    => ing_da_ready,
      in_data                     => ing_da_data,
      out_valid                   => ,
      out_ready                   => ,
      out_data                    => ,
      bytes_consumed              => ,
      bc_valid                    => ,
      bc_ready                    => ,
      prod_alignment              => ,
      pa_valid                    => ,
      pa_ready                    => 
    );

  MetadataInterpreter_inst: V2MetadataInterpreter
    generic map(
      BUS_DATA_WIDTH => BUS_DATA_WIDTH
    )
    port map(
      clk                 => bus_clk,
      hw_reset            => bus_reset,
      in_valid            => ,
      in_ready            => ,
      in_data             => ,
      da_valid            => ,
      da_ready            => ,
      da_bytes_consumed   => ,
      rl_byte_length      => mdi_rl_byte_length,
      dl_byte_length      => mdi_dl_byte_length,
      dc_uncomp_size      => mdi_dc_uncomp_size,
      dc_comp_size        => mdi_dc_comp_size,
      dd_num_values       => mdi_dd_num_values
    );
end architecture;
