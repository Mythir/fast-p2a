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
-- Fletcher utils for use of log2ceil function.
use work.Utils.all;
use work.Streams.all;
use work.Delta.all;

-- This module determines the encoded values from the unpacked deltas, min_delta, and first_value. Also takes
-- responsiblity for detecting and handling page boundaries.

entity DeltaAccumulator is
  generic (
    -- Maximum number of unpacked deltas per cycle
    MAX_DELTAS_PER_CYCLE        : natural;

    -- Amount of values in a block
    BLOCK_SIZE                  : natural;

    -- Amount of miniblocks in a block 
    MINIBLOCKS_IN_BLOCK         : natural;

    -- Bit width of a single primitive value
    PRIM_WIDTH                  : natural
  );
  port (
    -- Rising-edge sensitive clock.
    clk                         : in  std_logic;

    -- Active-high synchronous reset.
    reset                       : in  std_logic;

    -- Total number of requested values (from host)
    total_num_values            : in  std_logic_vector(31 downto 0);

    -- Number of values in the page (from MetadataInterpreter)
    page_num_values             : in  std_logic_vector(31 downto 0);

    -- Handshake signaling start of new page
    new_page_valid              : in  std_logic;
    new_page_ready              : out std_logic;
    
    -- Data in stream from BitUnpacker
    in_valid                    : in  std_logic;
    in_ready                    : out std_logic;
    in_data                     : in  std_logic_vector(MAX_DELTAS_PER_CYCLE*PRIM_WIDTH-1 downto 0);
    in_count                    : in  std_logic_vector(log2floor(MAX_DELTAS_PER_CYCLE) downto 0);

    -- First value stream from DeltaHeaderReader
    fv_valid                    : in  std_logic;
    fv_ready                    : out std_logic;
    fv_data                     : in  std_logic_vector(PRIM_WIDTH-1 downto 0);

    -- Minimum delta stream to DeltaAccumulator
    md_valid                    : in  std_logic;
    md_ready                    : out std_logic;
    md_data                     : in  std_logic_vector(PRIM_WIDTH-1 downto 0);

    --Data out stream to ValuesBuffer
    out_valid                   : out std_logic;
    out_ready                   : in  std_logic;
    out_last                    : out std_logic;
    out_count                   : out std_logic_vector(log2floor(MAX_DELTAS_PER_CYCLE) downto 0);
    out_data                    : out std_logic_vector(MAX_DELTAS_PER_CYCLE*PRIM_WIDTH-1 downto 0)
  );
end DeltaAccumulator;

architecture behv of DeltaAccumulator is
  constant DATA_WIDTH  : natural := in_data'length;
  constant COUNT_WIDTH : natural := in_count'length;
  -- +1 for out_last
  constant SLICE_WIDTH : natural := 1 + DATA_WIDTH + COUNT_WIDTH;
  
  type slice_subrecord is record
    valid    : std_logic;
    ready    : std_logic;
    concat   : std_logic_vector(SLICE_WIDTH-1 downto 0);
  end record;

  type slice_record is record
    i        : slice_subrecord;
    o        : slice_subrecord;
  end record;

  signal slice1 : slice_record;
  signal slice2 : slice_record;
  signal slice3 : slice_record;

  -- Asserted by DeltaAccumulatorFV when a new page is requested to start from a clean slate
  signal new_page_reset   : std_logic;

  -- new_page_reset or reset
  signal pipeline_reset   : std_logic;

  -- Internal copies of signals
  signal s_new_page_valid : std_logic;
  signal s_new_page_ready : std_logic;

begin

  new_page_ready   <= s_new_page_ready;
  s_new_page_valid <= new_page_valid;

  new_page_reset <= s_new_page_valid and s_new_page_ready;

  pipeline_reset <= reset or new_page_reset;

  slice1.i.valid  <= in_valid;
  in_ready        <= slice1.i.ready;
  slice1.i.concat <= '0' & in_data & in_count;

  slice_1: StreamSlice 
    generic map (
      DATA_WIDTH                  => SLICE_WIDTH
    )
    port map (
      clk                         => clk,
      reset                       => pipeline_reset,
      in_valid                    => slice1.i.valid,
      in_ready                    => slice1.i.ready,
      in_data                     => slice1.i.concat,
      out_valid                   => slice1.o.valid,
      out_ready                   => slice1.o.ready,
      out_data                    => slice1.o.concat
    );

  deltas: DeltaAccumulatorMD
    generic map(
      MAX_DELTAS_PER_CYCLE        => MAX_DELTAS_PER_CYCLE,
      BLOCK_SIZE                  => BLOCK_SIZE,
      MINIBLOCKS_IN_BLOCK         => MINIBLOCKS_IN_BLOCK,
      PRIM_WIDTH                  => PRIM_WIDTH
    )
    port map(
      clk                         => clk,
      reset                       => pipeline_reset,
      in_valid                    => slice1.o.valid,
      in_ready                    => slice1.o.ready,
      in_data                     => slice1.o.concat(SLICE_WIDTH-2 downto COUNT_WIDTH),
      in_count                    => slice1.o.concat(COUNT_WIDTH-1 downto 0),
      md_valid                    => md_valid,
      md_ready                    => md_ready,
      md_data                     => md_data,
      out_valid                   => slice2.i.valid,
      out_ready                   => slice2.i.ready,
      out_count                   => slice2.i.concat(COUNT_WIDTH-1 downto 0),
      out_data                    => slice2.i.concat(SLICE_WIDTH-2 downto COUNT_WIDTH)
    );
  
  slice_2: StreamSlice 
    generic map (
      DATA_WIDTH                  => SLICE_WIDTH
    )
    port map (
      clk                         => clk,
      reset                       => pipeline_reset,
      in_valid                    => slice2.i.valid,
      in_ready                    => slice2.i.ready,
      in_data                     => slice2.i.concat,
      out_valid                   => slice2.o.valid,
      out_ready                   => slice2.o.ready,
      out_data                    => slice2.o.concat
    );

  prefix_sum: DeltaAccumulatorFV
    generic map(
      MAX_DELTAS_PER_CYCLE        => MAX_DELTAS_PER_CYCLE,
      BLOCK_SIZE                  => BLOCK_SIZE,
      PRIM_WIDTH                  => PRIM_WIDTH
    )
    port map(
      clk                         => clk,
      reset                       => reset,
      ctrl_done                   => open,
      total_num_values            => total_num_values,
      page_num_values             => page_num_values,
      new_page_valid              => s_new_page_valid,
      new_page_ready              => s_new_page_ready,
      in_valid                    => slice2.o.valid,
      in_ready                    => slice2.o.ready,
      in_data                     => slice2.o.concat(SLICE_WIDTH-2 downto COUNT_WIDTH),
      in_count                    => slice2.o.concat(COUNT_WIDTH-1 downto 0),
      fv_valid                    => fv_valid,
      fv_ready                    => fv_ready,
      fv_data                     => fv_data,
      out_valid                   => slice3.i.valid,
      out_ready                   => slice3.i.ready,
      out_last                    => slice3.i.concat(SLICE_WIDTH-1),
      out_count                   => slice3.i.concat(COUNT_WIDTH-1 downto 0),
      out_data                    => slice3.i.concat(SLICE_WIDTH-2 downto COUNT_WIDTH)
    );
  
  slice_3: StreamSlice 
    generic map (
      DATA_WIDTH                  => SLICE_WIDTH
    )
    port map (
      clk                         => clk,
      reset                       => reset,
      in_valid                    => slice3.i.valid,
      in_ready                    => slice3.i.ready,
      in_data                     => slice3.i.concat,
      out_valid                   => slice3.o.valid,
      out_ready                   => slice3.o.ready,
      out_data                    => slice3.o.concat
    );

    out_valid <= slice3.o.valid;
    slice3.o.ready <= out_ready;
    out_last  <= slice3.o.concat(SLICE_WIDTH-1);
    out_data  <= slice3.o.concat(SLICE_WIDTH-2 downto COUNT_WIDTH);
    out_count <= slice3.o.concat(COUNT_WIDTH-1 downto 0);

end architecture;