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
use ieee.numeric_std.all;

package Snappy is

  component SnappyDecompressor is
    generic (
      BUS_DATA_WIDTH              : natural
    );
    port (
      clk                         : in  std_logic;
      reset                       : in  std_logic;
      in_valid                    : in  std_logic;
      in_ready                    : out std_logic;
      in_data                     : in  std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
      new_page_valid              : in  std_logic;
      new_page_ready              : out std_logic;
      compressed_size             : in  std_logic_vector(31 downto 0);
      uncompressed_size           : in  std_logic_vector(31 downto 0);
      out_valid                   : out std_logic;
      out_ready                   : in  std_logic;
      out_data                    : out std_logic_vector(BUS_DATA_WIDTH-1 downto 0)
    );
  end component;

  component decompressor_wrapper is
    port (
      clk                         : in  std_logic;
      rst_n                       : in  std_logic;
      last                        : out std_logic;
      done                        : out std_logic;
      start                       : in  std_logic;
      in_data                     : in  std_logic_vector(511 downto 0);
      in_data_valid               : in  std_logic;
      in_data_ready               : out std_logic;
      compression_length          : in  std_logic_vector(34 downto 0);
      decompression_length        : in  std_logic_vector(31 downto 0);
      in_metadata_valid           : in  std_logic;
      in_metadata_ready           : out std_logic;
      out_data                    : out std_logic_vector(511 downto 0);
      out_data_valid              : out std_logic;
      out_data_byte_valid         : out std_logic_vector(63 downto 0);
      out_data_ready              : in  std_logic
    );
  end component;

end Snappy;