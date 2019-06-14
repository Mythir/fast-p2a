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
use work.UtilInt_pkg.all;
use work.UtilMisc_pkg.all;
use work.Stream_pkg.all;
use work.Delta.all;
use work.Ptoa.all;

entity BlockValuesAligner is
  generic (
    -- Decoder data width
    DEC_DATA_WIDTH              : natural;

    -- Block size in values
    BLOCK_SIZE                  : natural;

    -- Number of miniblocks in a block
    MINIBLOCKS_IN_BLOCK         : natural;

    -- Maximum number of unpacked deltas per cycle
    MAX_DELTAS_PER_CYCLE        : natural;

    -- Width for registers/ports concerned with the amount of bytes in a block
    BYTES_IN_BLOCK_WIDTH        : natural := 16;

    -- Bit width of a single primitive value
    PRIM_WIDTH                  : natural;

    RAM_CONFIG                  : string := ""
  );
  port (
    -- Rising-edge sensitive clock.
    clk                         : in  std_logic;

    -- Active-high synchronous reset.
    reset                       : in  std_logic;

    done                        : out std_logic;

    -- Data in stream from StreamSerializer
    in_valid                    : in  std_logic;
    in_ready                    : out std_logic;
    in_data                     : in  std_logic_vector(DEC_DATA_WIDTH-1 downto 0);

    -- Number of values in the page (from MetadataInterpreter)
    page_num_values             : in  std_logic_vector(31 downto 0);

    -- Minimum delta stream to DeltaAccumulator
    md_valid                    : out std_logic;
    md_ready                    : in  std_logic;
    md_data                     : out std_logic_vector(PRIM_WIDTH-1 downto 0);

    -- If the BlockValuesAligner is used for DeltaLengthByteArray decoding we need to know
    -- where the boundary between length data and char data is.
    bc_valid                    : out std_logic;
    bc_ready                    : in  std_logic;
    bc_data                     : out std_logic_vector(BYTES_IN_BLOCK_WIDTH-1 downto 0);

    --Data out stream to BitUnpacker
    out_valid                   : out std_logic;
    out_ready                   : in  std_logic;
    out_data                    : out std_logic_vector(DEC_DATA_WIDTH-1 downto 0);
    out_count                   : out std_logic_vector(log2floor(MAX_DELTAS_PER_CYCLE) downto 0);
    out_width                   : out std_logic_vector(log2floor(PRIM_WIDTH) downto 0)
  );
end BlockValuesAligner;

architecture behv of BlockValuesAligner is
  -- log2ceil(32) should be enough to allow the BlockHeaderReader to read the header
  constant LOOKAHEAD_DEPTH      : natural := 5;

  constant OUT_COUNT_WIDTH      : natural := log2floor(MAX_DELTAS_PER_CYCLE)+1;
  constant OUT_WIDTH_WIDTH      : natural := log2floor(PRIM_WIDTH)+1;

  -- Width of shift amount input of the shifters
  constant SHIFT_AMOUNT_WIDTH   : natural := log2ceil(DEC_DATA_WIDTH);
  constant NUM_SHIFT_STAGES     : natural := SHIFT_AMOUNT_WIDTH;
  -- Bit packing width and amount of values to unpack travel with the pipeline (out_width & out_count)
  constant SHIFTER_CTRL_WIDTH   : natural := OUT_WIDTH_WIDTH + OUT_COUNT_WIDTH;
  constant SHIFTER_DATA_WIDTH   : natural := 2*DEC_DATA_WIDTH;
  constant SHIFTER_INPUT_WIDTH  : natural := SHIFT_AMOUNT_WIDTH + SHIFTER_CTRL_WIDTH + SHIFTER_DATA_WIDTH;
  constant SHIFTER_OUTPUT_WIDTH : natural := SHIFTER_CTRL_WIDTH + SHIFTER_DATA_WIDTH;

  -- Stream from aligner FiFo to shifters
  signal fifo_out_valid         : std_logic;
  signal fifo_out_ready         : std_logic;
  signal fifo_out_data          : std_logic_vector(DEC_DATA_WIDTH-1 downto 0);

  -- Stream from sync to aligner FiFo (with enable)
  signal fifo_in_valid          : std_logic;
  signal fifo_in_ready          : std_logic;

  -- Stream from sync to BlockHeaderReader (with enable in the form of "not page_done")
  signal bhr_in_valid           : std_logic;
  signal bhr_in_ready           : std_logic;
  signal bhr_page_done          : std_logic;

  -- Stream out from BlockShiftControl
  signal bsc_out_valid          : std_logic;
  signal bsc_out_ready          : std_logic;
  signal bsc_out_data           : std_logic_vector(SHIFTER_DATA_WIDTH-1 downto 0);
  signal bsc_out_amount         : std_logic_vector(SHIFT_AMOUNT_WIDTH-1 downto 0);
  signal bsc_out_width          : std_logic_vector(OUT_WIDTH_WIDTH-1 downto 0);
  signal bsc_out_count          : std_logic_vector(OUT_COUNT_WIDTH-1 downto 0);
  signal bsc_page_done          : std_logic;

  -- Bit widths stream (from BlockHeaderReader)
  signal bw_valid               : std_logic;
  signal bw_ready               : std_logic;
  signal bw_data                : std_logic_vector(7 downto 0);

  -- BlockHeader lengths stream (from BlockHeaderReader)
  signal bl_valid               : std_logic;
  signal bl_ready               : std_logic;
  signal bl_data                : std_logic_vector(log2floor(max_varint_bytes(PRIM_WIDTH)+MINIBLOCKS_IN_BLOCK) downto 0);

  -- Aggregate sync out streams
  signal sync_out_valid         : std_logic_vector(1 downto 0);
  signal sync_out_ready         : std_logic_vector(1 downto 0);
  signal sync_out_enable        : std_logic_vector(1 downto 0);

  signal s_pipe_input           : std_logic_vector(SHIFTER_INPUT_WIDTH-1 downto 0);
  signal s_pipe_output          : std_logic_vector(SHIFTER_OUTPUT_WIDTH-1 downto 0);

  -- Stream in to shifter
  signal shifter_in_valid       : std_logic;
  signal shifter_in_ready       : std_logic;
  signal shifter_in_data        : std_logic_vector(SHIFTER_INPUT_WIDTH-1 downto 0);

  -- Stream out from shifter
  signal shifter_out_valid      : std_logic;
  signal shifter_out_ready      : std_logic;
  signal shifter_out_data       : std_logic_vector(SHIFTER_OUTPUT_WIDTH-1 downto 0);

begin
  fifo_in_valid   <= sync_out_valid(1);
  bhr_in_valid    <= sync_out_valid(0);
  sync_out_ready  <= fifo_in_ready  & bhr_in_ready;
  sync_out_enable <= (not bsc_page_done) & (not bhr_page_done);
  done            <= bsc_page_done and bhr_page_done;

  -- Connect output signals
  out_valid         <= shifter_out_valid;
  shifter_out_ready <= out_ready;
  out_data          <= shifter_out_data(DEC_DATA_WIDTH-1 downto 0);
  out_count         <= shifter_out_data(OUT_COUNT_WIDTH+SHIFTER_DATA_WIDTH-1 downto SHIFTER_DATA_WIDTH);
  out_width         <= shifter_out_data(SHIFTER_OUTPUT_WIDTH-1 downto SHIFTER_DATA_WIDTH+OUT_COUNT_WIDTH);

  -- Connect BlockShiftControl to shifter input signals
  shifter_in_valid  <= bsc_out_valid;
  bsc_out_ready     <= shifter_in_ready;
  shifter_in_data   <= bsc_out_amount & bsc_out_width & bsc_out_count & bsc_out_data;

  -- Syncs the streams into the BlockHeaderReader and the input FiFo of BlockShiftControl
  in_sync: StreamSync
    generic map(
      NUM_INPUTS                => 1,
      NUM_OUTPUTS               => 2
    )
    port map(
      clk                       => clk,
      reset                     => reset,
      in_valid(0)               => in_valid,
      in_ready(0)               => in_ready,
      out_valid                 => sync_out_valid,
      out_ready                 => sync_out_ready,
      out_enable                => sync_out_enable
    );

  header_reader: BlockHeaderReader
    generic map(
      DEC_DATA_WIDTH            => DEC_DATA_WIDTH,
      BLOCK_SIZE                => BLOCK_SIZE,
      MINIBLOCKS_IN_BLOCK       => MINIBLOCKS_IN_BLOCK,
      BYTES_IN_BLOCK_WIDTH      => BYTES_IN_BLOCK_WIDTH,
      FIFO_DEPTH                => LOOKAHEAD_DEPTH,
      PRIM_WIDTH                => PRIM_WIDTH
    )
    port map(
      clk                       => clk,
      reset                     => reset,
      page_done                 => bhr_page_done,
      in_valid                  => bhr_in_valid,
      in_ready                  => bhr_in_ready,
      in_data                   => in_data,
      page_num_values           => page_num_values,
      md_valid                  => md_valid,
      md_ready                  => md_ready,
      md_data                   => md_data,
      bw_valid                  => bw_valid,
      bw_ready                  => bw_ready,
      bw_data                   => bw_data,
      bl_valid                  => bl_valid,
      bl_ready                  => bl_ready,
      bl_data                   => bl_data,
      bc_valid                  => bc_valid,
      bc_ready                  => bc_ready,
      bc_data                   => bc_data
    );

  -- This FiFo enables the lookahead functionality of the BlockHeaderReader by allowing the stream to advance some cycles independent of BlockShiftControl input.
  aligner_fifo: StreamFIFO
    generic map(
      DEPTH_LOG2                => LOOKAHEAD_DEPTH,
      DATA_WIDTH                => DEC_DATA_WIDTH
    )
    port map(
      in_clk                    => clk,
      in_reset                  => reset,
      in_valid                  => fifo_in_valid,
      in_ready                  => fifo_in_ready,
      in_data                   => in_data,
      in_rptr                   => open,
      in_wptr                   => open,
      out_clk                   => clk,
      out_reset                 => reset,
      out_valid                 => fifo_out_valid,
      out_ready                 => fifo_out_ready,
      out_data                  => fifo_out_data,
      out_rptr                  => open,
      out_wptr                  => open
    );

  shift_ctrl: BlockShiftControl
    generic map(
      DEC_DATA_WIDTH            => DEC_DATA_WIDTH,
      BLOCK_SIZE                => BLOCK_SIZE,
      MINIBLOCKS_IN_BLOCK       => MINIBLOCKS_IN_BLOCK,
      MAX_DELTAS_PER_CYCLE      => MAX_DELTAS_PER_CYCLE,
      PRIM_WIDTH                => PRIM_WIDTH,
      COUNT_WIDTH               => OUT_COUNT_WIDTH,
      WIDTH_WIDTH               => OUT_WIDTH_WIDTH,
      AMOUNT_WIDTH              => SHIFT_AMOUNT_WIDTH
    )
    port map(
      clk                       => clk,
      reset                     => reset,
      page_done                 => bsc_page_done,
      in_valid                  => fifo_out_valid,
      in_ready                  => fifo_out_ready,
      in_data                   => endianSwap(fifo_out_data),
      page_num_values           => page_num_values,
      bw_valid                  => bw_valid,
      bw_ready                  => bw_ready,
      bw_data                   => bw_data,
      bl_valid                  => bl_valid,
      bl_ready                  => bl_ready,
      bl_data                   => bl_data,
      out_valid                 => bsc_out_valid,
      out_ready                 => bsc_out_ready,
      out_data                  => bsc_out_data,
      out_amount                => bsc_out_amount,
      out_width                 => bsc_out_width,
      out_count                 => bsc_out_count 
    );

  pipeline_ctrl: StreamPipelineControl
    generic map (
      IN_DATA_WIDTH             => SHIFTER_INPUT_WIDTH,
      OUT_DATA_WIDTH            => SHIFTER_OUTPUT_WIDTH,
      NUM_PIPE_REGS             => NUM_SHIFT_STAGES,
      INPUT_SLICE               => false,
      RAM_CONFIG                => RAM_CONFIG
    )
    port map (
      clk                       => clk,
      reset                     => reset,
      in_valid                  => shifter_in_valid,
      in_ready                  => shifter_in_ready,
      in_data                   => shifter_in_data,
      out_valid                 => shifter_out_valid,
      out_ready                 => shifter_out_ready,
      out_data                  => shifter_out_data,
      pipe_valid                => open,
      pipe_input                => s_pipe_input,
      pipe_output               => s_pipe_output
    );

  pipeline: StreamPipelineBarrel
    generic map (
      ELEMENT_WIDTH             => 1,
      ELEMENT_COUNT             => SHIFTER_DATA_WIDTH,
      AMOUNT_WIDTH              => SHIFT_AMOUNT_WIDTH,
      DIRECTION                 => "right",
      OPERATION                 => "shift",
      NUM_STAGES                => NUM_SHIFT_STAGES,
      CTRL_WIDTH                => SHIFTER_CTRL_WIDTH
    )
    port map (
      clk                       => clk,
      reset                     => reset,
      in_data                   => s_pipe_input(SHIFTER_DATA_WIDTH-1 downto 0),
      in_ctrl                   => s_pipe_input(SHIFTER_CTRL_WIDTH+SHIFTER_DATA_WIDTH-1 downto SHIFTER_DATA_WIDTH),
      in_amount                 => s_pipe_input(SHIFTER_INPUT_WIDTH-1 downto SHIFTER_CTRL_WIDTH+SHIFTER_DATA_WIDTH),
      out_data                  => s_pipe_output(SHIFTER_DATA_WIDTH-1 downto 0),
      out_ctrl                  => s_pipe_output(SHIFTER_OUTPUT_WIDTH-1 downto SHIFTER_DATA_WIDTH)
    );

end architecture;