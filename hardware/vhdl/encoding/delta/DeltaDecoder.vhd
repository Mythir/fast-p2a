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

entity DeltaDecoder is
  generic (
    -- Bus data width
    BUS_DATA_WIDTH              : natural;

    -- Bit width of a single primitive value
    PRIM_WIDTH                  : natural;

    -- Max amount of decoded integers produced at out_data per cycle
    ELEMENTS_PER_CYCLE          : natural
  );
  port (
    -- Rising-edge sensitive clock.
    clk                         : in  std_logic;

    -- Active-high synchronous reset.
    reset                       : in  std_logic;

    ctrl_done                   : out std_logic;

    -- Data in stream from Decompressor
    in_valid                    : in  std_logic;
    in_ready                    : out std_logic;
    in_data                     : in  std_logic_vector(BUS_DATA_WIDTH-1 downto 0);

    -- Handshake signaling start of new page
    new_page_valid              : in  std_logic;
    new_page_ready              : out std_logic;

    -- Total number of requested values (from host)
    total_num_values            : in  std_logic_vector(31 downto 0);

    -- Number of values in the page (from MetadataInterpreter)
    page_num_values             : in  std_logic_vector(31 downto 0);

    -- Uncompressed size of page (from MetadataInterpreter)
    uncompressed_size 			    : in  std_logic_vector(31 downto 0);

    --Data out stream to Fletcher ColumnWriter
    out_valid                   : out std_logic;
    out_ready                   : in  std_logic;
    out_last                    : out std_logic;
    out_dvalid                  : out std_logic := '1';
    out_data                    : out std_logic_vector(log2ceil(ELEMENTS_PER_CYCLE+1) + ELEMENTS_PER_CYCLE*PRIM_WIDTH - 1 downto 0)
  );
end DeltaDecoder;

-- Don't forget to store page_num_values after every handshake. Don't accept new data until a new page has been handshaked (wait for BitUnpacker and DeltaAccumulator)

architecture behv of DeltaDecoder is
  
  -- The current design requires these two encoding parameters to be constant.
  constant BLOCK_SIZE          : natural := 128;
  constant MINIBLOCKS_IN_BLOCK : natural := 4;

  type state_t is (REQ_PAGE, IN_PAGE);

  type reg_record is record
    state             : state_t;
    total_num_values  : std_logic_vector(31 downto 0);
    page_num_values   : std_logic_vector(31 downto 0);
    uncompressed_size : std_logic_vector(31 downto 0);
    bytes_counted     : std_logic_vector(31 downto 0);
  end record;

  signal r : reg_record;
  signal d : reg_record;

  -- Internal copies of ports
  signal s_in_valid        : std_logic;
  signal s_in_ready        : std_logic;
 
  signal dhr_in_valid      : std_logic;
  signal dhr_in_ready      : std_logic;
  
  signal da_new_page_valid : std_logic;
  signal da_new_page_ready : std_logic;

begin

  s_in_valid <= in_valid;
  in_ready   <= s_in_ready;

  logic_p: process(r, in_valid, s_in_ready, in_data, da_new_page_ready, da_new_page_valid, total_num_values, page_num_values, uncompressed_size)
    variable v : reg_record;
  begin
    v := r;
    -- Todo: continue here
    case r.state is
    when REQ_PAGE =>
      new_page_ready    <= da_new_page_ready;
      da_new_page_valid <= new_page_valid;

      if da_new_page_valid = '1' and da_new_page_ready = '1' then
        -- When a new page is handshaked, set all registers to the new metadata values.
        v.total_num_values  := total_num_values;
        v.page_num_values   := page_num_values;
        v.uncompressed_size := uncompressed_size;
        v.bytes_counted     := (others => '0');
      end if;

    if s_in_valid = '1' and s_in_ready <= '1'


    d <= v;
  end process;

  clk_p: process(clk)
  begin
    if rising_edge(clk) then
      if reset = '1' then
        r.state <= REQ_PAGE;
      else
        r <= d;
      end if;
    end if;
  end process;

  dhr_inst: DeltaHeaderReader
    generic map(
      BUS_DATA_WIDTH              <= BUS_DATA_WIDTH,
      NUM_SHIFT_STAGES            <= 3,
      BLOCK_SIZE                  <= BLOCK_SIZE,
      MINIBLOCKS_IN_BLOCK         <= MINIBLOCKS_IN_BLOCK,
      PRIM_WIDTH                  <= PRIM_WIDTH
    )
    port map(
      clk                         <= clk,
      reset                       <= reset,
      in_valid                    <= dhr_in_valid,
      in_ready                    <= dhr_in_ready,
      in_data                     <= in_data,
      fv_valid                    <= ,
      fv_ready                    <= ,
      first_value                 <= ,
      out_valid                   <= ,
      out_ready                   <= ,
      out_data                    <= 
    );

end architecture;