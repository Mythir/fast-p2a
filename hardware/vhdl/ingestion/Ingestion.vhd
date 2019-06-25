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

package Ingestion is
  component Ingester is
    generic (
      BUS_DATA_WIDTH              : natural;
      BUS_ADDR_WIDTH              : natural;
      BUS_LEN_WIDTH               : natural;
      BUS_BURST_MAX_LEN           : natural;
      BUS_FIFO_DEPTH              : natural := 16;
      BUS_FIFO_RAM_CONFIG         : string := ""
    );
    port (
      clk                         : in  std_logic;
      reset                       : in  std_logic;
      bus_rreq_valid              : out std_logic;
      bus_rreq_ready              : in  std_logic;
      bus_rreq_addr               : out std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
      bus_rreq_len                : out std_logic_vector(BUS_LEN_WIDTH-1 downto 0);
      bus_rdat_valid              : in  std_logic;
      bus_rdat_ready              : out std_logic;
      bus_rdat_data               : in  std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
      bus_rdat_last               : in  std_logic;
      out_valid                   : out std_logic;
      out_ready                   : in  std_logic;
      out_data                    : out std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
      pa_valid                    : out std_logic;
      pa_ready                    : in  std_logic;
      pa_data                     : out std_logic_vector(log2ceil(BUS_DATA_WIDTH/8)-1 downto 0);
      start                       : in  std_logic;
      stop                        : in  std_logic;
      base_address                : in  std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
      data_size                   : in  std_logic_vector(BUS_ADDR_WIDTH-1 downto 0)
    );
  end component;
end Ingestion;