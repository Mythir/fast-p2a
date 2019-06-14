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

-- The ValuesDecoder is mostly a wrapper for more interesting components. Values in a page get fed into the ValuesDecoder after which the following
-- components will in order do the following things:
--
-- 1. PreDecBuffer: Will buffer an amount of bus words determined by MIN_INPUT_BUFFER_DEPTH. If this buffer is sufficiently large than the next
-- page can already start being processed by the MetadataInterpreter and (possible) Rep level and Def level decoders while the current page is still
-- being decompressed/decoded. To this end the PreDecBuffer will keep track of how many bytes it has ingested and compare it to the compressed_size
-- of the page.
--
-- 2. DecompressorWrapper: Decompress the values. The first version of the hardware will only support UNCOMPRESSED and SNAPPY.
--
-- 3. DecoderWrapper: Decode the values and make sure the ArrayWriter receives BUS_DATA_WIDTH/PRIM_WIDTH elements per write.
--
-- The processes in the ValuesDecoder itself are only concerned with providing the ArrayWriters with the correct settings.

entity ValuesDecoder is
  generic (
    -- Bus data width
    BUS_DATA_WIDTH              : natural;

    -- Bus address width
    BUS_ADDR_WIDTH              : natural;

    -- Arrow index field width
    INDEX_WIDTH                 : natural;

    -- Minimum depth of InputBuffer
    MIN_INPUT_BUFFER_DEPTH      : natural;

    -- Fletcher command stream tag width
    CMD_TAG_WIDTH               : natural;

    -- RAM config string
    RAM_CONFIG                  : string := "";

    -- Configuration string
    CFG                         : string;

    -- Encoding
    ENCODING                    : string;

    -- Compression
    COMPRESSION_CODEC           : string;

    -- Bit width of a single primitive value
    PRIM_WIDTH                  : natural
  );
  port (
    -- Rising-edge sensitive clock.
    clk                         : in  std_logic;

    -- Active-high synchronous reset.
    reset                       : in  std_logic;

    -- Control/status
    ctrl_start                  : in  std_logic;
    ctrl_done                   : out std_logic;

    -- Data in stream from DataAligner
    in_valid                    : in  std_logic;
    in_ready                    : out std_logic;
    in_data                     : in  std_logic_vector(BUS_DATA_WIDTH-1 downto 0);

    -- Compressed and uncompressed size of values in page (from MetadataInterpreter)
    compressed_size             : in  std_logic_vector(31 downto 0);
    uncompressed_size           : in  std_logic_vector(31 downto 0);

    -- Total number of requested values (from host)
    total_num_values            : in  std_logic_vector(31 downto 0);

    -- Number of values in the page (from MetadataInterpreter)
    page_num_values             : in  std_logic_vector(31 downto 0);

    -- Address of Arrow values buffer
    values_buffer_addr          : in  std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);

    -- Address of Arrow offsetes buffer
    offsets_buffer_addr         : in  std_logic_vector(BUS_ADDR_WIDTH-1 downto 0) := (others => '0');

    -- Bytes consumed stream to DataAligner
    bc_data                     : out std_logic_vector(log2ceil(BUS_DATA_WIDTH/8) downto 0);
    bc_ready                    : in  std_logic;
    bc_valid                    : out std_logic;

    -- Command stream to Fletcher ArrayWriter
    cmd_valid                   : out std_logic;
    cmd_ready                   : in  std_logic;
    cmd_firstIdx                : out std_logic_vector(INDEX_WIDTH-1 downto 0);
    cmd_lastIdx                 : out std_logic_vector(INDEX_WIDTH-1 downto 0);
    cmd_ctrl                    : out std_logic_vector(arcfg_ctrlWidth(CFG, BUS_ADDR_WIDTH)-1 downto 0);
    cmd_tag                     : out std_logic_vector(CMD_TAG_WIDTH-1 downto 0) := (others => '0');

    -- Unlock stream from Fletcher ArrayWriter
    unl_valid                   : in  std_logic;
    unl_ready                   : out std_logic;
    unl_tag                     : in  std_logic_vector(CMD_TAG_WIDTH-1 downto 0);

    --Data out stream to Fletcher ArrayWriter
    out_valid                   : out std_logic_vector(arcfg_userCount(CFG)-1 downto 0);
    out_ready                   : in  std_logic_vector(arcfg_userCount(CFG)-1 downto 0);
    out_last                    : out std_logic_vector(arcfg_userCount(CFG)-1 downto 0);
    out_dvalid                  : out std_logic_vector(arcfg_userCount(CFG)-1 downto 0) := (others => '1');
    out_data                    : out std_logic_vector(arcfg_userWidth(CFG, INDEX_WIDTH)-1 downto 0)
  );
end ValuesDecoder;

architecture behv of ValuesDecoder is

  type state_t is (IDLE, COMMAND, UNLOCK, DONE);
    signal state, state_next : state_t;
  
  -- New page handshake signals
  signal page_dcod_valid       : std_logic;
  signal page_dcmp_valid       : std_logic;
  signal page_dcod_ready       : std_logic;
  signal page_dcmp_ready       : std_logic;

  -- PreDecBuffer to Decompressor stream
  signal buf_to_dcmp_valid     : std_logic;
  signal buf_to_dcmp_ready     : std_logic;
  signal buf_to_dcmp_data      : std_logic_vector(BUS_DATA_WIDTH-1 downto 0);

  -- Decompressor to Decoder stream
  signal dcmp_to_dcod_valid     : std_logic;
  signal dcmp_to_dcod_ready     : std_logic;
  signal dcmp_to_dcod_data      : std_logic_vector(BUS_DATA_WIDTH-1 downto 0);

begin

  buffer_inst: PreDecBuffer
    generic map(
      BUS_DATA_WIDTH              => BUS_DATA_WIDTH,
      MIN_DEPTH                   => MIN_INPUT_BUFFER_DEPTH,
      RAM_CONFIG                  => RAM_CONFIG
    )
    port map(
      clk                         => clk,
      reset                       => reset,
      in_valid                    => in_valid,
      in_ready                    => in_ready,
      in_data                     => in_data,
      dcmp_valid                  => page_dcmp_valid,
      dcmp_ready                  => page_dcmp_ready,
      dcod_valid                  => page_dcod_valid,
      dcod_ready                  => page_dcod_ready,
      compressed_size             => compressed_size,
      bc_data                     => bc_data,
      bc_ready                    => bc_ready,
      bc_valid                    => bc_valid,
      out_valid                   => buf_to_dcmp_valid,
      out_ready                   => buf_to_dcmp_ready,
      out_data                    => buf_to_dcmp_data
    );

  dcmp_inst: DecompressorWrapper
    generic map(
      BUS_DATA_WIDTH              => BUS_DATA_WIDTH,
      COMPRESSION_CODEC           => COMPRESSION_CODEC
    )
    port map(
      clk                         => clk,
      reset                       => reset,
      in_valid                    => buf_to_dcmp_valid,
      in_ready                    => buf_to_dcmp_ready,
      in_data                     => buf_to_dcmp_data,
      new_page_valid              => page_dcmp_valid,
      new_page_ready              => page_dcmp_ready,
      compressed_size             => compressed_size,
      uncompressed_size           => uncompressed_size,
      out_valid                   => dcmp_to_dcod_valid,
      out_ready                   => dcmp_to_dcod_ready,
      out_data                    => dcmp_to_dcod_data
    );

  dcod_inst: DecoderWrapper
    generic map(
      BUS_DATA_WIDTH              => BUS_DATA_WIDTH,
      INDEX_WIDTH                 => INDEX_WIDTH,
      PRIM_WIDTH                  => PRIM_WIDTH,
      CFG                         => CFG,
      ENCODING                    => ENCODING
    )
    port map(
      clk                         => clk,
      reset                       => reset,
      ctrl_done                   => open,
      in_valid                    => dcmp_to_dcod_valid,
      in_ready                    => dcmp_to_dcod_ready,
      in_data                     => dcmp_to_dcod_data,
      new_page_valid              => page_dcod_valid,
      new_page_ready              => page_dcod_ready,
      total_num_values            => total_num_values,
      page_num_values             => page_num_values,
      uncompressed_size           => uncompressed_size,
      out_valid                   => out_valid,
      out_ready                   => out_ready,
      out_last                    => out_last,
      out_dvalid                  => out_dvalid,
      out_data                    => out_data
    );

  logic_p: process(state, ctrl_start, cmd_ready, unl_valid, total_num_values, values_buffer_addr, offsets_buffer_addr)
  begin
    state_next <= state;

    cmd_valid       <= '0';
    cmd_firstIdx    <= (others => '0');
    cmd_lastIdx     <= total_num_values;
    cmd_tag         <= (others => '0');

    if arcfg_ctrlWidth(CFG, BUS_ADDR_WIDTH) = 2*BUS_ADDR_WIDTH then
      cmd_ctrl <= values_buffer_addr & offsets_buffer_addr;
    elsif arcfg_ctrlWidth(CFG, BUS_ADDR_WIDTH) = BUS_ADDR_WIDTH then
      cmd_ctrl <= values_buffer_addr;
    end if;

    unl_ready <= '1';

    ctrl_done <= '0';

    case state is
      when IDLE =>
        if ctrl_start = '1' then
          state_next <= COMMAND;
        end if;

      when COMMAND =>
        cmd_valid <= '1';

        if cmd_ready = '1' then
          state_next <= UNLOCK;
        end if;

      when UNLOCK =>
        unl_ready <= '1';

        if unl_valid = '1' then
          state_next <= DONE;
        end if;

      when DONE =>
        ctrl_done <= '1';

    end case;
  end process;

  clk_p: process(clk)
  begin
    if rising_edge(clk) then
      if reset = '1' then
        state <= IDLE;
      else
        state <= state_next;
      end if;
    end if;
  end process;
end architecture;