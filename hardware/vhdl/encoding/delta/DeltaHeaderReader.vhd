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

-- This module reads the values in the Delta header and aligns the data to the first block header.

entity DeltaHeaderReader is
  generic (
    -- Bus data width
    BUS_DATA_WIDTH              : natural;

    -- Bit width of a single primitive value
    PRIM_WIDTH                  : natural
  );
  port (
    -- Rising-edge sensitive clock.
    clk                         : in  std_logic;

    -- Active-high synchronous reset.
    reset                       : in  std_logic;

    -- Data in stream from decompressor
    in_valid                    : in  std_logic;
    in_ready                    : out std_logic;
    in_data                     : in  std_logic_vector(BUS_DATA_WIDTH-1 downto 0);

    --------------------------------------------------------------------------------
    -- Read values in Delta header.
    -- The commented values are either not necessary or not supported in this design
    --------------------------------------------------------------------------------

    -- First value stream to DeltaAccumulator
    fv_valid                    : out std_logic;
    fv_ready                    : in  std_logic;
    first_value                 : out std_logic_vector(PRIM_WIDTH-1 downto 0);
    
    --block_size                : out std_logic_vector(31 downto 0);
    --miniblocks_in_block       : out std_logic_vector(31 downto 0);
    --total_value_count         : out std_logic_vector(31 downto 0);

    --Data out stream to StreamSerializer
    out_valid                   : out std_logic;
    out_ready                   : in  std_logic;
    out_data                    : out std_logic_vector(BUS_DATA_WIDTH-1 downto 0)
  );
end DeltaHeaderReader;