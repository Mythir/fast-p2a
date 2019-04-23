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
use work.Utils.all;
use work.Ptoa.all;

package Delta is

  component BlockHeaderReader is
    generic (
      DEC_DATA_WIDTH              : natural;
      BLOCK_SIZE                  : natural;
      MINIBLOCKS_IN_BLOCK         : natural;
      BYTES_IN_BLOCK_WIDTH        : natural := 16;
      FIFO_DEPTH                  : natural;
      PRIM_WIDTH                  : natural
    );
    port (
      clk                         : in  std_logic;
      reset                       : in  std_logic;
      page_done                   : out std_logic;
      in_valid                    : in  std_logic;
      in_ready                    : out std_logic;
      in_data                     : in  std_logic_vector(DEC_DATA_WIDTH-1 downto 0);
      page_num_values             : in  std_logic_vector(31 downto 0);
      md_valid                    : out std_logic;
      md_ready                    : in  std_logic;
      md_data                     : out std_logic_vector(PRIM_WIDTH-1 downto 0);
      bw_valid                    : out std_logic;
      bw_ready                    : in  std_logic;
      bw_data                     : out std_logic_vector(7 downto 0);
      bl_valid                    : out std_logic;
      bl_ready                    : in  std_logic;
      bl_data                     : out std_logic_vector(log2floor(max_varint_bytes(PRIM_WIDTH)+MINIBLOCKS_IN_BLOCK) downto 0);
      bc_valid                    : out std_logic;
      bc_ready                    : in  std_logic;
      bc_data                     : out std_logic_vector(BYTES_IN_BLOCK_WIDTH-1 downto 0)
    );
  end component;

end Delta;