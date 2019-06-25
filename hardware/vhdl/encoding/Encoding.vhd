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
use work.UtilInt_pkg.all;
use work.UtilConv_pkg.all;
use work.ArrayConfig_pkg.all;
use work.ArrayConfigParse_pkg.all;

package Encoding is

  component ValuesDecoder is
    generic (
      BUS_DATA_WIDTH              : natural;
      BUS_ADDR_WIDTH              : natural;
      INDEX_WIDTH                 : natural;
      MIN_INPUT_BUFFER_DEPTH      : natural;
      CMD_TAG_WIDTH               : natural;
      RAM_CONFIG                  : string := "";
      CFG                         : string;
      ENCODING                    : string;
      COMPRESSION_CODEC           : string;
      PRIM_WIDTH                  : natural
    );
    port (
      clk                         : in  std_logic;
      reset                       : in  std_logic;
      ctrl_start                  : in  std_logic;
      ctrl_done                   : out std_logic;
      in_valid                    : in  std_logic;
      in_ready                    : out std_logic;
      in_data                     : in  std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
      compressed_size             : in  std_logic_vector(31 downto 0);
      uncompressed_size           : in  std_logic_vector(31 downto 0);
      total_num_values            : in  std_logic_vector(31 downto 0);
      page_num_values             : in  std_logic_vector(31 downto 0);
      values_buffer_addr          : in  std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
      offsets_buffer_addr         : in  std_logic_vector(BUS_ADDR_WIDTH-1 downto 0) := (others => '0');
      bc_data                     : out std_logic_vector(log2ceil(BUS_DATA_WIDTH/8) downto 0);
      bc_ready                    : in  std_logic;
      bc_valid                    : out std_logic;
      cmd_valid                   : out std_logic;
      cmd_ready                   : in  std_logic;
      cmd_firstIdx                : out std_logic_vector(INDEX_WIDTH-1 downto 0);
      cmd_lastIdx                 : out std_logic_vector(INDEX_WIDTH-1 downto 0);
      cmd_ctrl                    : out std_logic_vector(arcfg_ctrlWidth(CFG, BUS_ADDR_WIDTH)-1 downto 0);
      cmd_tag                     : out std_logic_vector(CMD_TAG_WIDTH-1 downto 0) := (others => '0');
      unl_valid                   : in  std_logic;
      unl_ready                   : out std_logic;
      unl_tag                     : in  std_logic_vector(CMD_TAG_WIDTH-1 downto 0);
      out_valid                   : out std_logic_vector(arcfg_userCount(CFG)-1 downto 0);
      out_ready                   : in  std_logic_vector(arcfg_userCount(CFG)-1 downto 0);
      out_last                    : out std_logic_vector(arcfg_userCount(CFG)-1 downto 0);
      out_dvalid                  : out std_logic_vector(arcfg_userCount(CFG)-1 downto 0) := (others => '1');
      out_data                    : out std_logic_vector(arcfg_userWidth(CFG, INDEX_WIDTH)-1 downto 0)
    );
  end component;

  component VarIntDecoder is
    generic (
      INT_BIT_WIDTH               : natural;
      ZIGZAG_ENCODED              : boolean
    );
    port (
      clk                         : in std_logic;
      reset                       : in std_logic;
      start                       : in std_logic;
      in_data                     : in std_logic_vector(7 downto 0);
      in_valid                    : in std_logic;
      out_data                    : out std_logic_vector(INT_BIT_WIDTH-1 downto 0)
    );
  end component;

  component DecompressorWrapper is
    generic (
      BUS_DATA_WIDTH              : natural;
      COMPRESSION_CODEC           : string := "UNCOMPRESSED"
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

  component PreDecBuffer is
    generic (
      BUS_DATA_WIDTH              : natural;
      MIN_DEPTH                   : natural;
      RAM_CONFIG                  : string := ""
    );
    port (
      clk                         : in  std_logic;
      reset                       : in  std_logic;
      in_valid                    : in  std_logic;
      in_ready                    : out std_logic;
      in_data                     : in  std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
      dcmp_valid                  : out std_logic;
      dcmp_ready                  : in  std_logic;
      dcod_valid                  : out std_logic;
      dcod_ready                  : in  std_logic;
      compressed_size             : in  std_logic_vector(31 downto 0);
      bc_data                     : out std_logic_vector(log2ceil(BUS_DATA_WIDTH/8) downto 0);
      bc_ready                    : in  std_logic;
      bc_valid                    : out std_logic;
      out_valid                   : out std_logic;
      out_ready                   : in  std_logic;
      out_data                    : out std_logic_vector(BUS_DATA_WIDTH-1 downto 0)
    );
  end component;

  component PlainDecoder is
    generic (
      BUS_DATA_WIDTH              : natural;
      ELEMENTS_PER_CYCLE          : natural;
      PRIM_WIDTH                  : natural
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
      out_data                    : out std_logic_vector(log2ceil(ELEMENTS_PER_CYCLE+1) + ELEMENTS_PER_CYCLE*PRIM_WIDTH - 1 downto 0)
    );
  end component;

  component DecoderWrapper is
    generic (
      BUS_DATA_WIDTH              : natural;
      PRIM_WIDTH                  : natural;
      INDEX_WIDTH                 : natural;
      CFG                         : string;
      ENCODING                    : string
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
  end component;

  component AdvanceableFiFo is
    generic (
      DATA_WIDTH                  : natural;
      DEPTH_LOG2                  : natural;
      ADV_COUNT_WIDTH             : natural := 16;
      RAM_CONFIG                  : string := ""
    );
    port (
      clk                         : in  std_logic;
      reset                       : in  std_logic;
      in_valid                    : in  std_logic;
      in_ready                    : out std_logic;
      in_data                     : in  std_logic_vector(DATA_WIDTH-1 downto 0);
      out_valid                   : out std_logic;
      out_ready                   : in  std_logic;
      out_data                    : out std_logic_vector(DATA_WIDTH-1 downto 0);
      adv_valid                   : in  std_logic;
      adv_ready                   : out std_logic := '1';
      adv_count                   : in  std_logic_vector(ADV_COUNT_WIDTH-1 downto 0)
    );
  end component;

  -----------------------------------------------------------------------------
  -- Helper functions
  -----------------------------------------------------------------------------
  -- Decodes zigzag encoded integers to correct signed value;
  function decode_zigzag(a : in std_logic_vector) return signed;

end Encoding;

package body Encoding is
  function decode_zigzag(a : in std_logic_vector) return signed is
    variable x : std_logic_vector(a'length - 1 downto 0);
    variable y : std_logic_vector(a'length - 1 downto 0);
  begin
    x := std_logic_vector(shift_right(unsigned(a), 1));
    y := std_logic_vector(-signed(a and slv(1, a'length)));
    return signed(x xor y);
  end function;
end Encoding;