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
use work.Arrays.all;
use work.Interconnect.all;
use work.Wrapper.all;
use work.ArrayConfigParse.all;

-- Ptoa
use work.Encoding.all;
use work.Thrift.all;
use work.Ingestion.all;
use work.Alignment.all;

-- This ParquetReader is currently set up to work for Parquet arrays containing primitives (int32, int64, float, double).
-- Therefore, CFG should be of the form "prim(<width>)" (see Fletcher's ArrayConfig.vhd). In the future, once more
-- CFG's are supported, this file will be expanded with generate statements ensuring the correct functionality (or version) of the
-- ValuesDecoder, rep level decoder, def level encoder are selected.

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
    TAG_WIDTH                                  : natural;
    CFG                                        : string;
    ENCODING                                   : string;
    COMPRESSION_CODEC                          : string
  );
  port(
    clk                                        : in  std_logic;
    reset                                      : in  std_logic;
    ---------------------------------------------------------------------------
    bus_rreq_valid                             : out std_logic;
    bus_rreq_ready                             : in  std_logic;
    bus_rreq_addr                              : out std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
    bus_rreq_len                               : out std_logic_vector(BUS_LEN_WIDTH-1 downto 0);
    ---------------------------------------------------------------------------
    bus_rdat_valid                             : in  std_logic;
    bus_rdat_ready                             : out std_logic;
    bus_rdat_data                              : in  std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
    bus_rdat_last                              : in  std_logic;
    ---------------------------------------------------------------------------
    bus_wreq_valid                             : out std_logic;
    bus_wreq_len                               : out std_logic_vector(BUS_LEN_WIDTH-1 downto 0);
    bus_wreq_addr                              : out std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
    bus_wreq_ready                             : in  std_logic;
    ---------------------------------------------------------------------------
    bus_wdat_valid                             : out std_logic;
    bus_wdat_ready                             : in  std_logic;
    bus_wdat_data                              : out std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
    bus_wdat_strobe                            : out std_logic_vector(BUS_STROBE_WIDTH-1 downto 0);
    bus_wdat_last                              : out std_logic;
    ---------------------------------------------------------------------------
    -- Pointer to the first page in a contiguous list of Parquet pages in memory
    base_pages_ptr                             : in  std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
    -- Total size in bytes of the contiuous list of Parquet pages
    max_data_size                              : in  std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
    -- How many values to read from the pages before stopping
    total_num_values                           : in  std_logic_vector(31 downto 0);
    -- Pointer to Arrow values buffer
    values_buffer_addr                         : in  std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
    ---------------------------------------------------------------------------
    start                                      : in  std_logic;
    stop                                       : in  std_logic;
    ---------------------------------------------------------------------------
    done                                       : out std_logic
  );
end ParquetReader;

architecture Implementation of ParquetReader is

  constant PRIM_WIDTH                          : natural := strtoi(parse_arg(CFG, 0));
  constant ELEMENTS_PER_CYCLE                  : natural := parse_param(CFG, "epc", 1);

  -- Metadata signals
  signal mdi_rl_byte_length                    : std_logic_vector(31 downto 0);
  signal mdi_dl_byte_length                    : std_logic_vector(31 downto 0);
  signal mdi_dc_uncomp_size                    : std_logic_vector(31 downto 0);
  signal mdi_dc_comp_size                      : std_logic_vector(31 downto 0);
  signal mdi_dd_num_values                     : std_logic_vector(31 downto 0);

  ----------------------------------------------------------------------------
  -- Streams
  ----------------------------------------------------------------------------
  ----------------------------------
  -- Ingester <-> DataAligner
  ----------------------------------
  -- Ingester to DataAligner data
  signal ing_da_valid                          : std_logic;
  signal ing_da_ready                          : std_logic;
  signal ing_da_data                           : std_logic_vector(BUS_DATA_WIDTH-1 downto 0);

  -- Ingester to DataAligner alignment
  signal prod_align_valid                      : std_logic;
  signal prod_align_ready                      : std_logic;
  signal prod_align_data                       : std_logic_vector(log2ceil(BUS_DATA_WIDTH/8)-1 downto 0);

  ----------------------------------
  -- DataAligner <-> consumers
  ----------------------------------
  constant NUM_CONSUMERS                       : natural := 2;

  -- DataAligner to consumers data
  signal da_cons_valid                         : std_logic_vector(NUM_CONSUMERS-1 downto 0);
  signal da_cons_ready                         : std_logic_vector(NUM_CONSUMERS-1 downto 0);
  signal da_cons_data                          : std_logic_vector(BUS_DATA_WIDTH-1 downto 0);

  -- Consumers to DataAligner bytes_consumed/alignment
  signal bytes_cons_valid                      : std_logic_vector(NUM_CONSUMERS-1 downto 0);
  signal bytes_cons_ready                      : std_logic_vector(NUM_CONSUMERS-1 downto 0);
  signal bytes_cons_data                       : std_logic_vector(NUM_CONSUMERS*(log2ceil(BUS_DATA_WIDTH/8)+1)-1 downto 0);

  ----------------------------------
  -- ValuesDecoder <-> ArrayWriter
  ----------------------------------
  -- Command stream
  signal cmd_valid                             : std_logic;
  signal cmd_ready                             : std_logic;
  signal cmd_firstIdx                          : std_logic_vector(INDEX_WIDTH-1 downto 0);
  signal cmd_lastIdx                           : std_logic_vector(INDEX_WIDTH-1 downto 0);
  signal cmd_ctrl                              : std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
  signal cmd_tag                               : std_logic_vector(TAG_WIDTH-1 downto 0);

  -- Unlock stream
  signal unl_valid                             : std_logic;
  signal unl_ready                             : std_logic;
  signal unl_tag                               : std_logic_vector(TAG_WIDTH-1 downto 0);

  -- Data stream
  signal vd_cw_valid                           : std_logic_vector(0 downto 0);
  signal vd_cw_ready                           : std_logic_vector(0 downto 0);
  signal vd_cw_last                            : std_logic_vector(0 downto 0);
  signal vd_cw_data                            : std_logic_vector(log2ceil(ELEMENTS_PER_CYCLE+1) + ELEMENTS_PER_CYCLE*PRIM_WIDTH - 1 downto 0);
  signal vd_cw_dvalid                          : std_logic_vector(0 downto 0);

begin

  Ingester_inst: Ingester
    generic map(
      BUS_DATA_WIDTH      => BUS_DATA_WIDTH,
      BUS_ADDR_WIDTH      => BUS_ADDR_WIDTH,
      BUS_LEN_WIDTH       => BUS_LEN_WIDTH,
      BUS_BURST_MAX_LEN   => BUS_BURST_MAX_LEN,
      BUS_FIFO_DEPTH      => 5*BUS_BURST_MAX_LEN
    )
    port map(
      clk                 => clk,
      reset               => reset,
      bus_rreq_valid      => bus_rreq_valid,
      bus_rreq_ready      => bus_rreq_ready,
      bus_rreq_addr       => bus_rreq_addr,
      bus_rreq_len        => bus_rreq_len,
      bus_rdat_valid      => bus_rdat_valid,
      bus_rdat_ready      => bus_rdat_ready,
      bus_rdat_data       => bus_rdat_data,
      bus_rdat_last       => bus_rdat_last,
      out_valid           => ing_da_valid,
      out_ready           => ing_da_ready,
      out_data            => ing_da_data,
      pa_valid            => prod_align_valid,
      pa_ready            => prod_align_ready,
      pa_data             => prod_align_data,
      start               => start,
      stop                => stop,
      base_address        => base_pages_ptr,
      data_size           => max_data_size
    );

  DataAligner_inst: DataAligner
    generic map(
      BUS_DATA_WIDTH      => BUS_DATA_WIDTH,
      NUM_CONSUMERS       => NUM_CONSUMERS,
      NUM_SHIFT_STAGES    => log2ceil(BUS_DATA_WIDTH/8)
    )
    port map(
      clk                 => clk,
      reset               => reset,
      in_valid            => ing_da_valid,
      in_ready            => ing_da_ready,
      in_data             => ing_da_data,
      out_valid           => da_cons_valid,
      out_ready           => da_cons_ready,
      out_data            => da_cons_data,
      bytes_consumed      => bytes_cons_data,
      bc_valid            => bytes_cons_valid,
      bc_ready            => bytes_cons_ready,
      prod_alignment      => prod_align_data,
      pa_valid            => prod_align_valid,
      pa_ready            => prod_align_ready
    );

  MetadataInterpreter_inst: V2MetadataInterpreter
    generic map(
      BUS_DATA_WIDTH => BUS_DATA_WIDTH
    )
    port map(
      clk                 => clk,
      hw_reset            => reset,
      in_valid            => da_cons_valid(0),
      in_ready            => da_cons_ready(0),
      in_data             => da_cons_data,
      da_valid            => bytes_cons_valid(0),
      da_ready            => bytes_cons_ready(0),
      da_bytes_consumed   => bytes_cons_data(log2ceil(BUS_DATA_WIDTH/8) downto 0),
      rl_byte_length      => mdi_rl_byte_length,
      dl_byte_length      => mdi_dl_byte_length,
      dc_uncomp_size      => mdi_dc_uncomp_size,
      dc_comp_size        => mdi_dc_comp_size,
      dd_num_values       => mdi_dd_num_values
    );

  ValuesDecoder_inst: ValuesDecoder
    generic map(
      BUS_DATA_WIDTH              => BUS_DATA_WIDTH,
      BUS_ADDR_WIDTH              => BUS_ADDR_WIDTH,
      INDEX_WIDTH                 => INDEX_WIDTH,
      MIN_INPUT_BUFFER_DEPTH      => 16,
      CMD_TAG_WIDTH               => TAG_WIDTH,
      ENCODING                    => ENCODING,
      COMPRESSION_CODEC           => COMPRESSION_CODEC,
      ELEMENTS_PER_CYCLE          => ELEMENTS_PER_CYCLE,
      PRIM_WIDTH                  => PRIM_WIDTH
    )
    port map(
      clk                         => clk,
      reset                       => reset,
      ctrl_start                  => start,
      ctrl_done                   => done,
      in_valid                    => da_cons_valid(1),
      in_ready                    => da_cons_ready(1),
      in_data                     => da_cons_data,
      compressed_size             => mdi_dc_comp_size,
      uncompressed_size           => mdi_dc_uncomp_size,
      total_num_values            => total_num_values,
      page_num_values             => mdi_dd_num_values,
      values_buffer_addr          => values_buffer_addr,
      bc_data                     => bytes_cons_data(2*log2ceil(BUS_DATA_WIDTH/8)+1 downto log2ceil(BUS_DATA_WIDTH/8)+1),
      bc_ready                    => bytes_cons_ready(1),
      bc_valid                    => bytes_cons_valid(1),
      cmd_valid                   => cmd_valid,
      cmd_ready                   => cmd_ready,
      cmd_firstIdx                => cmd_firstIdx,
      cmd_lastIdx                 => cmd_lastIdx,
      cmd_ctrl                    => cmd_ctrl,
      cmd_tag                     => cmd_tag,
      unl_valid                   => unl_valid,
      unl_ready                   => unl_ready,
      unl_tag                     => unl_tag,
      out_valid                   => vd_cw_valid(0),
      out_ready                   => vd_cw_ready(0),
      out_last                    => vd_cw_last(0),
      out_dvalid                  => vd_cw_dvalid(0),
      out_data                    => vd_cw_data
    );

  fletcher_cw_inst: ArrayWriter
    generic map (
      BUS_ADDR_WIDTH              => BUS_ADDR_WIDTH,
      BUS_LEN_WIDTH               => BUS_LEN_WIDTH,
      BUS_DATA_WIDTH              => BUS_DATA_WIDTH,
      BUS_STROBE_WIDTH            => BUS_STROBE_WIDTH,
      BUS_BURST_STEP_LEN          => BUS_BURST_STEP_LEN,
      BUS_BURST_MAX_LEN           => BUS_BURST_MAX_LEN,
      INDEX_WIDTH                 => INDEX_WIDTH,
      CFG                         => CFG,
      CMD_TAG_ENABLE              => true,
      CMD_TAG_WIDTH               => TAG_WIDTH
    )
    port map (
      bus_clk                     => clk,
      bus_reset                   => reset,
      acc_clk                     => clk,
      acc_reset                   => reset,
      cmd_valid                   => cmd_valid,
      cmd_ready                   => cmd_ready,
      cmd_firstIdx                => cmd_firstIdx,
      cmd_lastIdx                 => cmd_lastIdx,
      cmd_ctrl                    => cmd_ctrl,
      cmd_tag                     => cmd_tag,
      in_valid                    => vd_cw_valid,
      in_ready                    => vd_cw_ready,
      in_last                     => vd_cw_last,
      in_data                     => vd_cw_data,
      in_dvalid                   => vd_cw_dvalid,
      bus_wreq_valid              => bus_wreq_valid,
      bus_wreq_ready              => bus_wreq_ready,
      bus_wreq_addr               => bus_wreq_addr,
      bus_wreq_len                => bus_wreq_len,
      bus_wdat_valid              => bus_wdat_valid,
      bus_wdat_ready              => bus_wdat_ready,
      bus_wdat_data               => bus_wdat_data,
      bus_wdat_strobe             => bus_wdat_strobe,
      bus_wdat_last               => bus_wdat_last,
      unlock_valid                => unl_valid,
      unlock_ready                => unl_ready,
      unlock_tag                  => unl_tag
    );
end architecture;
