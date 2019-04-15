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

    -- Handshake signaling start of new page
    new_page_valid              : in  std_logic;
    new_page_ready              : out std_logic;

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
    bytes_consumed              : out std_logic_vector(31 downto 0);

    --Data out stream to BitUnpacker
    out_valid                   : out std_logic;
    out_ready                   : in  std_logic;
    out_data                    : out std_logic_vector(DEC_DATA_WIDTH-1 downto 0);
    out_count                   : out std_logic_vector(log2ceil(MAX_DELTAS_PER_CYCLE)-1 downto 0);
    out_width                   : out std_logic_vector(log2ceil(PRIM_WIDTH) downto 0)
  );
end BlockValuesAligner;

architecture behv of BlockValuesAligner is

begin

end architecture;