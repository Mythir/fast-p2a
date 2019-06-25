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
use work.Stream_pkg.all;

-- This module uses the min_delta value obtained from the BlockHeaderReader to calculate the full deltas from the values unpacked by BitUnpacker.
-- It keeps track of the amount of deltas processed in a block so it knows when to request a new min_delta.
-- A FiFo buffers multiple min_delta values to allow the BlockHeaderReader to continue with the next block header.
-- Once a full page worth of values has been processed (as determined by DeltaAccumulatorFV), this module is reset.
-- This is in order to avoid sending padding values in the block down the pipeline. (Each block is padded to BLOCK_SIZE).

entity DeltaAccumulatorMD is
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
    
    -- Data in stream from BitUnpacker
    in_valid                    : in  std_logic;
    in_ready                    : out std_logic;
    in_data                     : in  std_logic_vector(MAX_DELTAS_PER_CYCLE*PRIM_WIDTH-1 downto 0);
    in_count                    : in  std_logic_vector(log2floor(MAX_DELTAS_PER_CYCLE) downto 0);

    -- Minimum delta stream from BlockHeaderReader
    md_valid                    : in  std_logic;
    md_ready                    : out std_logic;
    md_data                     : in  std_logic_vector(PRIM_WIDTH-1 downto 0);

    --Data out stream to DeltaAccumulator
    out_valid                   : out std_logic;
    out_ready                   : in  std_logic;
    out_count                   : out std_logic_vector(log2floor(MAX_DELTAS_PER_CYCLE) downto 0);
    out_data                    : out std_logic_vector(MAX_DELTAS_PER_CYCLE*PRIM_WIDTH-1 downto 0)
  );
end DeltaAccumulatorMD;

architecture behv of DeltaAccumulatorMD is

  type reg_record is record
    block_val_count : unsigned(log2floor(BLOCK_SIZE) downto 0);
  end record;

  signal r : reg_record;
  signal d : reg_record;

  signal md_fifo_out_valid : std_logic;
  signal md_fifo_out_ready : std_logic;
  signal md_fifo_out_data  : std_logic_vector(PRIM_WIDTH-1 downto 0);

begin
  
  -- Buffer for the min deltas
  md_fifo: StreamFIFO
    generic map(
      DEPTH_LOG2                => log2ceil(MINIBLOCKS_IN_BLOCK),
      DATA_WIDTH                => PRIM_WIDTH
    )
    port map(
      in_clk                    => clk,
      in_reset                  => reset,
      in_valid                  => md_valid,
      in_ready                  => md_ready,
      in_data                   => md_data,
      out_clk                   => clk,
      out_reset                 => reset,
      out_valid                 => md_fifo_out_valid,
      out_ready                 => md_fifo_out_ready,
      out_data                  => md_fifo_out_data
    );

  -- out_count remains unchanged while each of the offsets in the input data gets added to min_delta to create the final delta
  out_count <= in_count;
  sum_gen: for i in 0 to MAX_DELTAS_PER_CYCLE-1 generate
    out_data(PRIM_WIDTH*(i+1)-1 downto PRIM_WIDTH*i) <= std_logic_vector(unsigned(in_data(PRIM_WIDTH*(i+1)-1 downto PRIM_WIDTH*i)) + unsigned(resize(signed(md_fifo_out_data), PRIM_WIDTH)));
  end generate sum_gen;

  logic_p: process(r, md_fifo_out_valid, in_valid, out_ready, in_count)
    variable v : reg_record;
  begin
    v := r;

    in_ready  <= '0';
    out_valid <= '0';

    md_fifo_out_ready <= '0';

    if md_fifo_out_valid = '1' then
      in_ready  <= out_ready;
      out_valid <= in_valid;

      if in_valid = '1' and out_ready = '1' then
        v.block_val_count := r.block_val_count + unsigned(in_count);
      end if;

      if v.block_val_count = to_unsigned(BLOCK_SIZE, r.block_val_count'length) then
        -- Request new md upon completion of block
        md_fifo_out_ready <= '1';
        v.block_val_count := (others => '0');
      end if;
    end if;

    d <= v;
  end process;

  clk_p: process(clk)
  begin
    if rising_edge(clk) then
      if reset = '1' then
        r.block_val_count <= (others => '0');
      else
        r <= d;
      end if;
    end if;
  end process;

end architecture;