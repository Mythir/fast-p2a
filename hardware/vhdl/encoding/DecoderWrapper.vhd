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
use work.ArrayConfig_pkg.all;
use work.ArrayConfigParse_pkg.all;

use work.Encoding.all;
use work.Delta.all;

entity DecoderWrapper is
  generic (
    BUS_DATA_WIDTH              : natural;
    INDEX_WIDTH                 : natural;
    PRIM_WIDTH                  : natural;
    CFG                         : string;
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
    uncompressed_size           : in  std_logic_vector(31 downto 0);
    out_valid                   : out std_logic_vector(arcfg_userCount(CFG)-1 downto 0);
    out_ready                   : in  std_logic_vector(arcfg_userCount(CFG)-1 downto 0);
    out_last                    : out std_logic_vector(arcfg_userCount(CFG)-1 downto 0);
    out_dvalid                  : out std_logic_vector(arcfg_userCount(CFG)-1 downto 0) := (others => '1');
    out_data                    : out std_logic_vector(arcfg_userWidth(CFG, INDEX_WIDTH)-1 downto 0)
  );
end DecoderWrapper;

architecture behv of DecoderWrapper is
begin

  plain_gen: if ENCODING = "PLAIN" generate
    plaindecoder_inst: PlainDecoder
      generic map(
        BUS_DATA_WIDTH            => BUS_DATA_WIDTH,
        ELEMENTS_PER_CYCLE        => parse_param(CFG, "epc", 1),
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
        out_valid                 => out_valid(0),
        out_ready                 => out_ready(0),
        out_last                  => out_last(0),
        out_dvalid                => out_dvalid(0),
        out_data                  => out_data
      );
  end generate;

  delta_gen: if ENCODING = "DELTA" generate
    deltadecoder_inst: DeltaDecoder
      generic map(
        BUS_DATA_WIDTH            => BUS_DATA_WIDTH,
        DEC_DATA_WIDTH            => 128,
        PRIM_WIDTH                => PRIM_WIDTH,
        ELEMENTS_PER_CYCLE        => parse_param(CFG, "epc", 1)
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
        uncompressed_size         => uncompressed_size,
        out_valid                 => out_valid(0),
        out_ready                 => out_ready(0),
        out_last                  => out_last(0),
        out_dvalid                => out_dvalid(0),
        out_data                  => out_data
      );
  end generate;

  delta_length_gen: if ENCODING = "DELTA_LENGTH" generate
    deltalengthdecoder_inst: DeltaLengthDecoder
      generic map(
        BUS_DATA_WIDTH              => BUS_DATA_WIDTH,
        DEC_DATA_WIDTH              => 128,
        INDEX_WIDTH                 => 32,
        CHARS_PER_CYCLE             => parse_param(CFG, "epc", 1),
        LENGTHS_PER_CYCLE           => parse_param(CFG, "lepc", 1)
      )
      port map(
        clk                         => clk,
        reset                       => reset,
        ctrl_done                   => ctrl_done,
        in_valid                    => in_valid,
        in_ready                    => in_ready,
        in_data                     => in_data,
        new_page_valid              => new_page_valid,
        new_page_ready              => new_page_ready,
        total_num_values            => total_num_values,
        page_num_values             => page_num_values,
        uncompressed_size           => uncompressed_size,
        out_valid                   => out_valid,
        out_ready                   => out_ready,
        out_last                    => out_last,
        out_dvalid                  => out_dvalid,
        out_data                    => out_data
      );
  end generate;



end architecture;