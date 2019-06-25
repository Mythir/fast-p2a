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

library work;
-- Fletcher utils for use of log2ceil function.
use work.UtilInt_pkg.all;

package Thrift is
  component V2MetadataInterpreter is
    generic (
      BUS_DATA_WIDTH              : natural := 512;
      CYCLE_COUNT_WIDTH           : natural := 8
    );
    port (
      clk                         : in  std_logic;
      hw_reset                    : in  std_logic;
      in_valid                    : in  std_logic;
      in_ready                    : out std_logic;
      in_data                     : in  std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
      da_valid                    : out std_logic;
      da_ready                    : in  std_logic;
      da_bytes_consumed           : out std_logic_vector(log2ceil(BUS_DATA_WIDTH/8) downto 0);
      rl_byte_length              : out std_logic_vector(31 downto 0);
      dl_byte_length              : out std_logic_vector(31 downto 0);
      dc_uncomp_size              : out std_logic_vector(31 downto 0);
      dc_comp_size                : out std_logic_vector(31 downto 0);
      dd_num_values               : out std_logic_vector(31 downto 0)
    );
  end component;
end Thrift;