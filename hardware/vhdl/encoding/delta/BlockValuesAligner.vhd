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
use work.Utils.all;
use work.Streams.all;
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

    -- Bit width of a single primitive value
    PRIM_WIDTH                  : natural
  );
  port (
    -- Rising-edge sensitive clock.
    clk                         : in  std_logic;

    -- Active-high synchronous reset.
    reset                       : in  std_logic;

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
    bc_data                     : out std_logic_vector(31 downto 0);

    --Data out stream to BitUnpacker
    out_valid                   : out std_logic;
    out_ready                   : in  std_logic;
    out_data                    : out std_logic_vector(DEC_DATA_WIDTH-1 downto 0);
    out_count                   : out std_logic_vector(log2ceil(MAX_DELTAS_PER_CYCLE)-1 downto 0);
    out_width                   : out std_logic_vector(log2ceil(PRIM_WIDTH) downto 0)
  );
end BlockValuesAligner;

architecture behv of BlockValuesAligner is
  -- 5 (log2(32)) should be enough to allow the BlockHeaderReader to read the header
  constant LOOKAHEAD_DEPTH      : natural := 5;

  -- Stream from aligner FiFo to shifters
  signal fifo_out_valid         : std_logic;
  signal fifo_out_ready         : std_logic;
  signal fifo_out_data          : std_logic_vector(DEC_DATA_WIDTH-1 downto 0);

  -- Stream from sync to aligner FiFo (with enable)
  signal fifo_in_valid          : std_logic;
  signal fifo_in_ready          : std_logic;
  signal fifo_in_enable         : std_logic;

  -- Stream from sync to BlockHeaderReader (with enable in the form of "not page_done")
  signal bhr_in_valid           : std_logic;
  signal bhr_in_ready           : std_logic;
  signal bhr_page_done          : std_logic;

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

begin
  sync_out_valid  <= fifo_in_valid  & bhr_in_valid;
  sync_out_ready  <= fifo_in_ready  & bhr_in_ready;
  sync_out_enable <= fifo_in_enable & (not bhr_page_done);
  
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

  -- This FiFo enables the lookahead functionality of the BlockHeaderReader
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

  header_reader: BlockHeaderReader
    generic map(
      DEC_DATA_WIDTH            => DEC_DATA_WIDTH,
      BLOCK_SIZE                => BLOCK_SIZE,
      MINIBLOCKS_IN_BLOCK       => MINIBLOCKS_IN_BLOCK,
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

  -- Todo:
  -- 2*PRIM_WIDTH width barrel shifter for aligning the bit packed values

end architecture;