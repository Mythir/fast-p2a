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

entity BlockHeaderReader is
  generic (
    -- Decoder data width
    DEC_DATA_WIDTH              : natural;

    -- Block size in values
    BLOCK_SIZE                  : natural;

    -- Number of miniblocks in a block
    MINIBLOCKS_IN_BLOCK         : natural;

    -- Maximum number of unpacked deltas per cycle
    MAX_DELTAS_PER_CYCLE        : natural;

    -- Bit width of a single primitive value
    PRIM_WIDTH                  : natural
  );
  port (
    -- Rising-edge sensitive clock.
    clk                         : in  std_logic;

    -- Active-high synchronous reset.
    reset                       : in  std_logic;

    -- Data in stream from StreamSerializer
    in_valid                    : in  std_logic;
    in_ready                    : out std_logic;
    in_data                     : in  std_logic_vector(DEC_DATA_WIDTH-1 downto 0);

    -- Handshake signaling start of new page
    new_page_valid              : in  std_logic;
    new_page_ready              : out std_logic;

    -- Number of values in the page (from MetadataInterpreter)
    page_num_values             : in  std_logic_vector(31 downto 0);

    -- Minimum delta stream to DeltaAccumulator
    md_valid                    : out std_logic;
    md_ready                    : in  std_logic;
    md_data                     : out std_logic_vector(PRIM_WIDTH-1 downto 0);

    -- Bit width stream to BlockValuesAligner
    bw_valid                    : out std_logic;
    bw_ready                    : in  std_logic;
    bw_data                     : out std_logic_vector(7 downto 0);

    -- If the BlockValuesAligner is used for DeltaLengthByteArray decoding we need to know
    -- where the boundary between length data and char data is.
    bc_valid                    : out std_logic;
    bc_ready                    : in  std_logic;
    bytes_consumed              : out std_logic_vector(31 downto 0)
  );
end BlockHeaderReader;

architecture behv of BlockHeaderReader is

  type state_t is (IDLE, READING);
  type header_state_t is (MIN_DELTA, BIT_WIDTHS);
  type handshake_state_t is (IDLE, VALID);

  type reg_record is record 
    state               : state_t;
    header_state        : header_state_t;
    handshake_state     : handshake_state_t;
    byte_counter        : unsigned(log2floor(DEC_DATA_WIDTH/8) downto 0);
    miniblock_counter   : unsigned(log2floor(MINIBLOCKS_IN_BLOCK) downto 0);
    header_data         : std_logic_vector(DEC_DATA_WIDTH-1 downto 0);
  end record;

  signal r : reg_record;
  signal d : reg_record;

  signal current_byte           : std_logic_vector(7 downto 0);
  signal current_byte_valid     : std_logic;
  signal start_varint           : std_logic;

  signal varint_zigzag_true     : std_logic_vector(PRIM_WIDTH-1 downto 0);
  signal varint_zigzag_false    : std_logic_vector(PRIM_WIDTH-1 downto 0);

begin

  current_byte <= r.header_data(DEC_DATA_WIDTH-1 downto DEC_DATA_WIDTH-8);
  md_data <= current_byte;

  logic_p: process(r)
    variable v : reg_record;
  begin
    v := r;

    in_ready <= '0';
    current_byte_valid <= '0';

    case r.state is
      when IDLE =>
        in_ready <= '1';

        if in_valid = '1' then
          v.header_data := in_data;
          v.byte_counter := (others => '0');
          v.state := READING;
        end if;

      when READING =>
        if r.byte_counter = to_unsigned(DEC_DATA_WIDTH/8, r.byte_counter'length) then
          -- If all bytes in header_r have been processed and we are still not done, request new data
          in_ready <= '1';

          if in_valid = '1' then
            v.header_data := in_data;
            v.byte_counter := (others => '0');
          end if;

        else
          current_byte_valid <= '1';

          case r.header_state is
            when MIN_DELTA =>
              v.byte_counter := r.byte_counter + 1;
              v.header_data := std_logic_vector(shift_left(unsigned(r.header_data), 8));
              if current_byte(7) = '0' then
                v.header_state := BIT_WIDTHS;
              end if;

            when BIT_WIDTHS =>
              md_valid <= '1';

              if md_ready = '1' then
                v.byte_counter := r.byte_counter + 1;
                v.header_data := std_logic_vector(shift_left(unsigned(r.header_data), 8));
                v.miniblock_counter := r.miniblock_counter + 1;
              end if;


          end case;

        end if;
    end case;

    d <= r;
  end process;

  varint_zigzag_t_inst: VarIntDecoder
    generic map (
      INT_BIT_WIDTH => PRIM_WIDTH,
      ZIGZAG_ENCODED => true
    )
    port map (
      clk => clk,
      reset => reset,
      start => start_varint,
      in_data => current_byte,
      in_valid => current_byte_valid,
      out_data => varint_zigzag_true
    );

  varint_zigzag_f_inst: VarIntDecoder
    generic map (
      INT_BIT_WIDTH => PRIM_WIDTH,
      ZIGZAG_ENCODED => true
    )
    port map (
      clk => clk,
      reset => reset,
      start => start_varint,
      in_data => current_byte,
      in_valid => current_byte_valid,
      out_data => varint_zigzag_false
    );


end architecture;