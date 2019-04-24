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

-- Todo: description
-- BL stream does not have a fifo. This will cause the BlockHeaderReader to block if the
-- BlockShiftControl does not consume the Block header length before the BlockHeaderReader
-- wants to start on the next Block header. This is not a problem because there is no point
-- in having the BlockHeaderReader run more than one block ahead of the BlockShiftControl

entity BlockShiftControl is
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
    PRIM_WIDTH                  : natural;

    -- Width of value count output (amount values to unpack)
    COUNT_WIDTH                 : natural;

    -- Width of bit packing width output
    WIDTH_WIDTH                 : natural;

    -- Width of shift amount output
    AMOUNT_WIDTH                : natural
  );
  port (
    -- Rising-edge sensitive clock.
    clk                         : in  std_logic;

    -- Active-high synchronous reset.
    reset                       : in  std_logic;

    -- Data in stream from BlockValuesAligner FiFo
    in_valid                    : in  std_logic;
    in_ready                    : out std_logic;
    in_data                     : in  std_logic_vector(DEC_DATA_WIDTH-1 downto 0);

    -- Number of values in the page (from MetadataInterpreter)
    page_num_values             : in  std_logic_vector(31 downto 0);

    -- Bit width stream from BlockHeaderReader
    bw_valid                    : out std_logic;
    bw_ready                    : in  std_logic;
    bw_data                     : out std_logic_vector(7 downto 0);

    -- Block header length stream from BlockHeaderReader
    bl_valid                    : out std_logic;
    bl_ready                    : in  std_logic;
    bl_data                     : out std_logic_vector(log2floor(max_varint_bytes(PRIM_WIDTH)+MINIBLOCKS_IN_BLOCK) downto 0);

    --Data out stream to BitUnpacker
    out_valid                   : out std_logic;
    out_ready                   : in  std_logic;
    out_data                    : out std_logic_vector(2*DEC_DATA_WIDTH-1 downto 0);
    out_amount                  : out std_logic_vector(AMOUNT_WIDTH-1 downto 0);
    out_width                   : out std_logic_vector(WIDTH_WIDTH-1 downto 0);
    out_count                   : out std_logic_vector(COUNT_WIDTH-1 downto 0)
  );
end BlockShiftControl;

architecture behv of BlockShiftControl is
  
  type state_t is (HEADER, DATA);

  type reg_record is record
    state            : state_t;
    hold             : std_logic_vector(DEC_DATA_WIDTH-1 downto 0);
    current_shift    : unsigned(AMOUNT_WIDTH-1 downto 0);
  end record;

  signal r : reg_record;
  signal d : reg_record;

begin

  out_data <= in_data & r.hold;

end architecture;