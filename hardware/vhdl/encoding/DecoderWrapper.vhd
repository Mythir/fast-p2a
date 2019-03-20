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
use work.Encoding.all;

entity DecoderWrapper is
  generic (
    BUS_DATA_WIDTH              : natural;
    PRIM_WIDTH                  : natural;
    ENCODING                    : string := "PLAIN"
  );
  port (
    clk                         : in  std_logic;
    reset                       : in  std_logic;
    ctrl_done                   : out std_logic;
    in_valid                    : in  std_logic;
    in_ready                    : out std_logic;
    in_data                     : in  std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
    new_page_valid              : in  std_logic;
    new_page_ready              : out std_logic;
    total_num_values            : in  std_logic_vector(31 downto 0);
    page_num_values             : in  std_logic_vector(31 downto 0);
    out_valid                   : out std_logic;
    out_ready                   : in  std_logic;
    out_last                    : out std_logic;
    out_dvalid                  : out std_logic := '1';
    out_data                    : out std_logic_vector(BUS_DATA_WIDTH-1 downto 0)
  );
end DecoderWrapper;

architecture behv of DecoderWrapper is
begin

  plain_gen: if ENCODING = "PLAIN" generate
    plaindecoder_inst: PlainDecoder
      generic map(
        BUS_DATA_WIDTH            => BUS_DATA_WIDTH,
        PRIM_WIDTH                => PRIM_WIDTH
      )
      port map(
        clk                       => clk,
        reset                     => reset,
        ctrl_done                 => ctrl_done,
        in_valid                  => in_valid,
        in_ready                  => in_ready,
        in_data                   => in_data,
        new_page_valid            => new_page_valid,
        new_page_ready            => new_page_ready,
        total_num_values          => total_num_values,
        page_num_values           => page_num_values,
        out_valid                 => out_valid,
        out_ready                 => out_ready,
        out_last                  => out_last,
        out_dvalid                => out_dvalid,
        out_data                  => out_data
      );
  end generate;


end architecture;