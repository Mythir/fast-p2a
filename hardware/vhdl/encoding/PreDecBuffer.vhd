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
-- Fletcher streams for use of StreamBuffer
use work.Stream_pkg.all;

-- Once the first data of a new page is received from the DataAligner, the PreDecBuffer will notify the Decompressor and the Decoder and start buffering data.
-- Once the PreDecBuffer has received <compressed_size> bytes it will handshake the DataAligner.

entity PreDecBuffer is
  generic (
    -- Bus data width
    BUS_DATA_WIDTH              : natural;

    -- Minimum depth of internal data buffer
    MIN_DEPTH                   : natural;

    -- RAM config string
    RAM_CONFIG                  : string := ""
  );
  port (
    -- Rising-edge sensitive clock.
    clk                         : in  std_logic;

    -- Active-high synchronous reset.
    reset                       : in  std_logic;

    -- Data in stream from DataAligner
    in_valid                    : in  std_logic;
    in_ready                    : out std_logic;
    in_data                     : in  std_logic_vector(BUS_DATA_WIDTH-1 downto 0);


    -- Decompressor "new page" handshake
    dcmp_valid                  : out std_logic;
    dcmp_ready                  : in  std_logic;

    -- Decoder "new page" handshake
    dcod_valid                  : out std_logic;
    dcod_ready                  : in  std_logic;

    -- Compressed size of values in page (from MetadataInterpreter)
    compressed_size             : in  std_logic_vector(31 downto 0);

    -- Bytes consumed stream to DataAligner
    bc_data                     : out std_logic_vector(log2ceil(BUS_DATA_WIDTH/8) downto 0);
    bc_ready                    : in  std_logic;
    bc_valid                    : out std_logic;

    --Data out stream to decompressor or decoder
    out_valid                   : out std_logic;
    out_ready                   : in  std_logic;
    out_data                    : out std_logic_vector(BUS_DATA_WIDTH-1 downto 0)
  );
end PreDecBuffer;

architecture behv of PreDecBuffer is

  type top_state_t       is (PAGE_START, IN_PAGE, PAGE_END);
  type handshake_state_t is (DECOMPRESSOR, DECODER, DONE);

  type reg_record is record 
    top_state               : top_state_t;
    handshake_state         : handshake_state_t;
    page_byte_counter       : unsigned(31 downto 0);
  end record;

  signal r : reg_record;
  signal d : reg_record;

  signal in_valid_buf : std_logic;
  signal in_ready_buf : std_logic;

begin

  buffer_inst: StreamBuffer
  generic map(
    MIN_DEPTH       => MIN_DEPTH,
    DATA_WIDTH      => BUS_DATA_WIDTH,
    RAM_CONFIG      => RAM_CONFIG
  )
  port map(
    clk             => clk,
    reset           => reset,
    in_valid        => in_valid_buf,
    in_ready        => in_ready_buf,
    in_data         => in_data,
    out_valid       => out_valid,
    out_ready       => out_ready,
    out_data        => out_data
  );
  
  logic_p: process (r, in_valid, in_ready_buf, compressed_size, bc_ready, dcod_ready, dcmp_ready)
    variable v : reg_record;
  begin
    v := r;

    dcmp_valid <= '0';
    dcod_valid <= '0';
    in_ready <= '0';
    in_valid_buf <= '0';
    bc_valid <= '0';

    bc_data(log2ceil(BUS_DATA_WIDTH/8)-1 downto 0) <= compressed_size(log2ceil(BUS_DATA_WIDTH/8)-1 downto 0);
    if compressed_size(log2ceil(BUS_DATA_WIDTH/8)-1 downto 0) = std_logic_vector(to_unsigned(0, log2ceil(BUS_DATA_WIDTH/8))) then
      bc_data(log2ceil(BUS_DATA_WIDTH/8)) <= '1';
    else
      bc_data(log2ceil(BUS_DATA_WIDTH/8)) <= '0';
    end if;

    case r.top_state is
      when PAGE_START =>
        -- PAGE_START: Wait for beginning of new page.
        if in_valid = '1' then
          v.top_state       := IN_PAGE;
          v.handshake_state := DECOMPRESSOR;
        end if;

      when IN_PAGE =>
        -- IN_PAGE: Consume data from DataAligner
        -- Connect input stream with StreamBuffer. Upon transfer of data, update the byte counter.
        in_valid_buf <= in_valid;
        in_ready <= in_ready_buf;
        if in_valid = '1' and in_ready_buf = '1' then
          v.page_byte_counter := r.page_byte_counter + BUS_DATA_WIDTH/8;
        end if;

        if v.page_byte_counter >= unsigned(compressed_size) then
          v.top_state := PAGE_END;
        end if;

      when PAGE_END =>
        -- If both the decompressor and the decoder have acknowledged, the ValuesDecoder can signal to the DataAligner that it can continue with the next page.
        if r.handshake_state = DONE then
          bc_valid <= '1';
          if bc_ready = '1' then
            v.top_state         := PAGE_START;
            v.page_byte_counter := (others => '0');
          end if;
        end if;

    end case;


    -- When a new page gets fed into the ValuesDecoder, we handshake the decompressor and the decoder in that order.
    case r.handshake_state is
      when DECOMPRESSOR =>
        dcmp_valid <= '1';
        if dcmp_ready = '1' then
          v.handshake_state := DECODER;
        end if;

      when DECODER =>
          dcod_valid <= '1';
          if dcod_ready = '1' then
            v.handshake_state := DONE;
          end if;

      when others =>

    end case;

    d <= v;

  end process;

  clk_p: process (clk)
  begin
    if rising_edge(clk) then
      if reset = '1' then
        r.top_state         <= PAGE_START;
        r.handshake_state   <= DONE;
        r.page_byte_counter <= (others => '0');
      else
        r <= d;
      end if;
    end if;
  end process;
end architecture;