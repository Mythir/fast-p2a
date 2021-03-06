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
use work.Encoding.all;

-- Todo: description

entity DecompressorWrapper is
  generic (
    -- Bus data width
    BUS_DATA_WIDTH              : natural;

    -- Compression
    COMPRESSION_CODEC           : string := "UNCOMPRESSED"
  );
  port (
    -- Rising-edge sensitive clock.
    clk                         : in  std_logic;

    -- Active-high synchronous reset.
    reset                       : in  std_logic;

    -- Data in stream from PreDecBuffer
    in_valid                    : in  std_logic;
    in_ready                    : out std_logic;
    in_data                     : in  std_logic_vector(BUS_DATA_WIDTH-1 downto 0);

    -- Handshake signaling new page
    new_page_valid              : in  std_logic;
    new_page_ready              : out std_logic;

    -- Compressed and uncompressed size of values in page (from MetadataInterpreter)
    compressed_size             : in  std_logic_vector(31 downto 0);
    uncompressed_size           : in  std_logic_vector(31 downto 0);

    --Data out stream to Fletcher ArrayWriter
    out_valid                   : out std_logic;
    out_ready                   : in  std_logic;
    out_data                    : out std_logic_vector(BUS_DATA_WIDTH-1 downto 0)
  );
end DecompressorWrapper;

architecture behv of DecompressorWrapper is

begin
  uncompressed_gen: if COMPRESSION_CODEC = "UNCOMPRESSED" generate
    in_ready       <= out_ready;
    out_valid      <= in_valid;
    out_data       <= in_data;
    new_page_ready <= '1';
  end generate;
end architecture;