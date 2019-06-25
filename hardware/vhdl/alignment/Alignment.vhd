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

package Alignment is
  component DataAligner is
    generic (
      BUS_DATA_WIDTH              : natural := 512;
      BUS_ADDR_WIDTH              : natural;
      NUM_CONSUMERS               : natural;
      NUM_SHIFT_STAGES            : natural
    );
    port (
      clk                         : in  std_logic;
      reset                       : in  std_logic;
      in_valid                    : in  std_logic;
      in_ready                    : out std_logic;
      in_data                     : in  std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
      out_valid                   : out std_logic_vector(NUM_CONSUMERS-1 downto 0);
      out_ready                   : in  std_logic_vector(NUM_CONSUMERS-1 downto 0);
      out_data                    : out std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
      bytes_consumed              : in  std_logic_vector(NUM_CONSUMERS*(log2ceil(BUS_DATA_WIDTH/8)+1)-1 downto 0);
      bc_valid                    : in  std_logic_vector(NUM_CONSUMERS-1 downto 0);
      bc_ready                    : out std_logic_vector(NUM_CONSUMERS-1 downto 0);
      prod_alignment              : in  std_logic_vector(log2ceil(BUS_DATA_WIDTH/8)-1 downto 0);
      pa_valid                    : in  std_logic;
      pa_ready                    : out std_logic;
      data_size                   : in  std_logic_vector(BUS_ADDR_WIDTH-1 downto 0)
    );
  end component;

  component ShifterRecombiner is
    generic (
      BUS_DATA_WIDTH              : natural := 512;
      SHIFT_WIDTH                 : natural;
      ELEMENT_WIDTH               : natural := 8;
      NUM_SHIFT_STAGES            : natural
    );
    port (
      clk                         : in  std_logic;
      reset                       : in  std_logic;
      clear                       : in  std_logic;
      in_valid                    : in  std_logic;
      in_ready                    : out std_logic;
      in_data                     : in  std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
      out_valid                   : out std_logic;
      out_ready                   : in  std_logic;
      out_data                    : out std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
      alignment                   : in  std_logic_vector(SHIFT_WIDTH-1 downto 0)
    );
  end component;

  component HistoryBuffer is
    generic (
      BUS_DATA_WIDTH              : natural := 512;
      DEPTH_LOG2                  : natural
    );
    port (
      clk                         : in  std_logic;
      reset                       : in  std_logic;
      in_valid                    : in  std_logic;
      in_ready                    : out std_logic;
      in_data                     : in  std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
      out_valid                   : out std_logic;
      out_ready                   : in  std_logic;
      out_data                    : out std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
      start_rewind                : in  std_logic;
      end_rewind                  : out std_logic;
      delete_oldest               : in  std_logic
    );
  end component;

end Alignment;