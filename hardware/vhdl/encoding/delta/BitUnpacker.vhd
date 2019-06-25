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
use work.UtilInt_pkg.all;
use work.Delta.all;
use work.Stream_pkg.all;

-- This module takes the aligned bit-packed data plus count and width information from the BlockValuesAligner and unpacks the values.
-- For each value that needs to be unpacked (limited by MAX_DELTAS_PER_CYCLE) a shifter pipeline is generated.
-- The shifter pipeline shifts the bits for that particular value to the right, after which it is ANDed with a mask for this particular bit-packing width.
-- Parallel to the shifters will be a FiFo saving the count and width values for every input, to be used in determining the mask after shifting or simply
-- passed to the DeltaAccumulator.
-- An input Sync makes sure all shifters and the FiFo receive the input at the same time, while an output sync ensures they are passed to the output at the
-- same time.

entity BitUnpacker is
  generic (
    -- Decoder data width
    DEC_DATA_WIDTH              : natural;

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

    -- Data in stream from BlockValuesAligner
    in_valid                    : in  std_logic;
    in_ready                    : out std_logic;
    in_data                     : in  std_logic_vector(DEC_DATA_WIDTH-1 downto 0);
    in_count                    : in  std_logic_vector(log2floor(MAX_DELTAS_PER_CYCLE) downto 0);
    in_width                    : in  std_logic_vector(log2floor(PRIM_WIDTH) downto 0);

    --Data out stream to DeltaAccumulator
    out_valid                   : out std_logic;
    out_ready                   : in  std_logic;
    out_count                   : out std_logic_vector(log2floor(MAX_DELTAS_PER_CYCLE) downto 0);
    out_data                    : out std_logic_vector(MAX_DELTAS_PER_CYCLE*PRIM_WIDTH-1 downto 0)
  );
end BitUnpacker;

architecture behv of BitUnpacker is
  constant NUM_SHIFT_STAGES     : natural := log2ceil(DEC_DATA_WIDTH);
    
  constant COUNT_WIDTH          : natural := log2floor(MAX_DELTAS_PER_CYCLE)+1;
  constant WIDTH_WIDTH          : natural := log2floor(PRIM_WIDTH)+1;
    
  constant FIFO_WIDTH           : natural := COUNT_WIDTH + WIDTH_WIDTH;
  constant FIFO_DEPTH           : natural := NUM_SHIFT_STAGES;

  -- LUTs containing the masks for the result of the shifters. One of these goes unused.
  constant mask_lut_64 : mask_lut_64_t := init_mask_lut_64;
  constant mask_lut_32 : mask_lut_32_t := init_mask_lut_32;
  
  -- In sync to FiFo and shifters
  signal in_sync_out_valid      : std_logic_vector(MAX_DELTAS_PER_CYCLE downto 0);
  signal in_sync_out_ready      : std_logic_vector(MAX_DELTAS_PER_CYCLE downto 0);

  signal out_sync_in_valid      : std_logic_vector(MAX_DELTAS_PER_CYCLE downto 0);
  signal out_sync_in_ready      : std_logic_vector(MAX_DELTAS_PER_CYCLE downto 0);

  -- Concatenation of in_count & in_width
  signal fifo_in_data           : std_logic_vector(FIFO_WIDTH-1 downto 0);

  -- Concatenation of all valid and ready signals of the shifters
  signal shifters_out_valid     : std_logic_vector(MAX_DELTAS_PER_CYCLE-1 downto 0);
  signal shifters_out_ready     : std_logic_vector(MAX_DELTAS_PER_CYCLE-1 downto 0);

  -- FiFo to out_sync
  signal fifo_out_valid         : std_logic;
  signal fifo_out_ready         : std_logic;
  signal fifo_out_data          : std_logic_vector(FIFO_WIDTH-1 downto 0);
  signal fifo_out_count         : std_logic_vector(COUNT_WIDTH-1 downto 0);
  signal fifo_out_width         : std_logic_vector(WIDTH_WIDTH-1 downto 0);

  signal mask                   : std_logic_vector(PRIM_WIDTH-1 downto 0);
begin
  
  -- Input: in stream, Output: All shifters plus the FiFo
  in_sync: StreamSync
    generic map(
      NUM_INPUTS                => 1,
      NUM_OUTPUTS               => MAX_DELTAS_PER_CYCLE+1
    )
    port map(
      clk                       => clk,
      reset                     => reset,
      in_valid(0)               => in_valid,
      in_ready(0)               => in_ready,
      out_valid                 => in_sync_out_valid,
      out_ready                 => in_sync_out_ready
    );

  fifo_in_data   <= in_count & in_width;
  out_count      <= fifo_out_count;
  fifo_out_width <= fifo_out_data(WIDTH_WIDTH-1 downto 0);
  fifo_out_count <= fifo_out_data(FIFO_WIDTH-1 downto WIDTH_WIDTH);

  count_width_fifo: StreamFIFO
    generic map(
      DEPTH_LOG2         => log2ceil(FIFO_DEPTH)+1, -- Made slightly larger because it was filling up to often
      DATA_WIDTH         => FIFO_WIDTH
    )
    port map(
      in_clk             => clk,
      in_reset           => reset,
      in_valid           => in_sync_out_valid(in_sync_out_valid'left),
      in_ready           => in_sync_out_ready(in_sync_out_ready'left),
      in_data            => fifo_in_data,
      out_clk            => clk,
      out_reset          => reset,
      out_valid          => fifo_out_valid,
      out_ready          => fifo_out_ready,
      out_data           => fifo_out_data
    );

  mask64: if PRIM_WIDTH = 64 generate
    mask <= mask_lut_64(to_integer(unsigned(fifo_out_width)));
  end generate mask64;

  mask32: if PRIM_WIDTH = 32 generate
    mask <= mask_lut_32(to_integer(unsigned(fifo_out_width)));
  end generate mask32;

  shifter_gen: for i in 0 to MAX_DELTAS_PER_CYCLE-1 generate
    signal shifter_out_data : std_logic_vector(PRIM_WIDTH-1 downto 0);
  begin
    unpack_shifter: BitUnpackerShifter
      generic map(
        ID                          => i,
        DEC_DATA_WIDTH              => DEC_DATA_WIDTH,
        MAX_DELTAS_PER_CYCLE        => MAX_DELTAS_PER_CYCLE,
        WIDTH_WIDTH                 => WIDTH_WIDTH,
        PRIM_WIDTH                  => PRIM_WIDTH,
        NUM_SHIFT_STAGES            => NUM_SHIFT_STAGES
      )
      port map(
        clk                         => clk,
        reset                       => reset,
        in_valid                    => in_sync_out_valid(i),
        in_ready                    => in_sync_out_ready(i),
        in_data                     => in_data,
        in_width                    => in_width,
        out_valid                   => shifters_out_valid(i),
        out_ready                   => shifters_out_ready(i),
        out_data                    => shifter_out_data
      );

    out_data(PRIM_WIDTH*(i+1)-1 downto PRIM_WIDTH*i) <= shifter_out_data and mask;
  end generate shifter_gen;
  
  out_sync_in_valid(out_sync_in_valid'left) <= fifo_out_valid;
  fifo_out_ready <= out_sync_in_ready(out_sync_in_ready'left);

  out_sync_in_valid(MAX_DELTAS_PER_CYCLE-1 downto 0) <= shifters_out_valid;
  shifters_out_ready <= out_sync_in_ready(MAX_DELTAS_PER_CYCLE-1 downto 0);

  -- Input: All shifters plus the FiFo, Output: To DeltaAccumulator
  out_sync: StreamSync
    generic map(
      NUM_INPUTS          => MAX_DELTAS_PER_CYCLE+1,
      NUM_OUTPUTS         => 1
    )
    port map(
      clk                 => clk,
      reset               => reset,
      in_valid            => out_sync_in_valid,
      in_ready            => out_sync_in_ready,
      out_valid(0)        => out_valid,
      out_ready(0)        => out_ready
    );

end architecture;