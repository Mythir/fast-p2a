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
-- Fletcher utils, for use of log2ceil function.
use work.Utils.all;
use work.Encoding.all;

-- This unit extracts relevant information from Parquet 2.0 page headers. Currently only the uncompressed size, compressed size,
-- num values, definition level byte length, and repetition level byte length fields are needed by the hardware. Once the
-- V2MetadataInterpreter has read a full thrift structure it will stream out (via bytes_consumed) how many bytes in the last bus word
-- were part of the metadata structure.

entity V2MetadataInterpreter is
  generic (
    -- Bus data width
    BUS_DATA_WIDTH              : natural := 512;

    -- Width of the register that stores the amount of bytes processed. 8 bits should be plenty for page metadata
    CYCLE_COUNT_WIDTH           : natural := 8
  );
  port (

    -- Rising-edge sensitive clock.
    clk                         : in  std_logic;

    -- Active-high synchronous reset.
    hw_reset                    : in  std_logic;

    -- Input data stream
    in_valid                    : in  std_logic;
    in_ready                    : out std_logic;
    in_data                     : in  std_logic_vector(BUS_DATA_WIDTH-1 downto 0);

    -- Output stream of bytes consumed to DataAligner
    da_valid                    : out std_logic;
    da_ready                    : in  std_logic;
    da_bytes_consumed           : out std_logic_vector(log2ceil(BUS_DATA_WIDTH/8)+1 downto 0);

    -- Output repetition level byte length repetition level decoder
    rl_byte_length              : out std_logic_vector(31 downto 0);

    -- Output definition level byte length to definition level decoder
    dl_byte_length              : out std_logic_vector(31 downto 0);

    -- Output compression information to decompressor
    dc_uncomp_size              : out std_logic_vector(31 downto 0);
    dc_comp_size                : out std_logic_vector(31 downto 0);

    -- Output number of values in page to data decoder
    dd_num_values               : out std_logic_vector(31 downto 0)
  );
end V2MetadataInterpreter;

architecture behv of V2MetadataInterpreter is

  -- Top level state in the state machine
  type top_state_t is (IDLE, INTERPRETING, DONE, FAULT);
      signal top_state, top_state_next : top_state_t;

  -- If in a PageHeader struct, which field is being interpreted
  type page_header_state_t is (START, PAGETYPE, UNCOMPRESSED_SIZE, COMPRESSED_SIZE, CRC, DATA_PAGE_HEADER, DICT_PAGE_HEADER);
      signal page_header_state, page_header_state_next : page_header_state_t;

  -- If in a DataPageHeader struct, which field is being interpreted
  type data_page_header_state_t is (START, NUM_VALUES, NUM_NULLS, NUM_ROWS, ENCODING, DEF_LEVEL_BYTE_LENGTH, REP_LEVEL_BYTE_LENGTH, IS_COMPRESSED, STATISTICS, DONE);
      signal data_page_header_state, data_page_header_state_next : data_page_header_state_t;

  -- Is the byte we are looking at part of a field header, or field data.
  type field_state_t is (HEADER, DATA);
      signal field_state, field_state_next : field_state_t;

  -- The integers encoded as varint in the page headers are always 32 bits wide
  constant VARINT_WIDTH             : natural := 32;

  -- Shift register for metadata input
  signal metadata_r                 : std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
  signal metadata_r_next            : std_logic_vector(BUS_DATA_WIDTH-1 downto 0);

  -- Registers for decoded metadata output
  signal uncomp_size_r              : std_logic_vector(31 downto 0);
  signal comp_size_r                : std_logic_vector(31 downto 0);
  signal num_values_r               : std_logic_vector(31 downto 0);
  signal rep_lvl_size_r             : std_logic_vector(31 downto 0);
  signal def_lvl_size_r             : std_logic_vector(31 downto 0);
  signal uncomp_size_r_next         : std_logic_vector(31 downto 0);
  signal comp_size_r_next           : std_logic_vector(31 downto 0);
  signal num_values_r_next          : std_logic_vector(31 downto 0);
  signal rep_lvl_size_r_next        : std_logic_vector(31 downto 0);
  signal def_lvl_size_r_next        : std_logic_vector(31 downto 0);

  -- Keep score of cycles
  signal cycle_count_r              : std_logic_vector(CYCLE_COUNT_WIDTH-1 downto 0);
  signal cycle_count_r_next         : std_logic_vector(CYCLE_COUNT_WIDTH-1 downto 0);

  -- The byte of the input that is currently being inspected
  signal current_byte               : std_logic_vector(7 downto 0);

  signal current_byte_valid         : std_logic;

  -- Used to signal the varint_decoder it will have to start decoding in the next clock cycle
  signal start_varint               : std_logic;

  -- VarIntDecoder output
  signal varint_dec_out_data        : std_logic_vector(VARINT_WIDTH-1 downto 0);

begin

  varint_dec_inst: VarIntDecoder
    generic map (
      INT_BIT_WIDTH => VARINT_WIDTH,
      ZIGZAG_ENCODED => true
    )
    port map (
      clk => clk,
      reset => hw_reset,
      start => start_varint,
      in_data => current_byte,
      in_valid => current_byte_valid,
      out_data => varint_dec_out_data
    );

  dc_uncomp_size    <= uncomp_size_r;
  dc_comp_size      <= comp_size_r;
  rl_byte_length    <= rep_lvl_size_r;
  dl_byte_length    <= def_lvl_size_r;
  dd_num_values     <= num_values_r;
  da_bytes_consumed <= cycle_count_r(log2ceil(BUS_DATA_WIDTH/8)+1 downto 0);

  current_byte <= metadata_r(BUS_DATA_WIDTH-1 downto BUS_DATA_WIDTH-8);

  logic_p: process (page_header_state, data_page_header_state, field_state, uncomp_size_r, comp_size_r, rep_lvl_size_r, def_lvl_size_r,
                    top_state, metadata_r, current_byte, num_values_r, cycle_count_r, varint_dec_out_data,
                    in_valid, in_data, da_ready) is
  begin
    -- Default values
    top_state_next <= top_state;
    page_header_state_next <= page_header_state;
    data_page_header_state_next <= data_page_header_state;
    field_state_next <= field_state;

    uncomp_size_r_next <= uncomp_size_r;
    comp_size_r_next <= comp_size_r;
    rep_lvl_size_r_next <= rep_lvl_size_r;
    def_lvl_size_r_next <= def_lvl_size_r;
    num_values_r_next <= num_values_r;
    cycle_count_r_next <= cycle_count_r;
    metadata_r_next <= metadata_r;

    -- By default the interpreter is not ready to send or receive data
    in_ready <= '0';
    da_valid <= '0';

    start_varint <= '0';

    current_byte_valid <= '0';

    -- State machine
    case top_state is
      when IDLE =>
        -- Wait for metadata to parse from DataAligner
        in_ready <= '1';

        if in_valid = '1' then
          top_state_next <= INTERPRETING;
          metadata_r_next <= in_data;
        end if;

      when INTERPRETING =>
        if cycle_count_r = std_logic_vector(to_unsigned(BUS_DATA_WIDTH/8, cycle_count_r'length)) then
          -- If all bytes in metadata_r have been processed and we are still not done, request new data
          in_ready <= '1';

          if in_valid = '1' then
            metadata_r_next <= in_data;
            cycle_count_r_next <= (others => '0');
          end if;

        else
          current_byte_valid <= '1';

          cycle_count_r_next <= std_logic_vector(unsigned(cycle_count_r) + 1);
  
          -- Shift the metadata register with one byte to the left every clock cycle.
          metadata_r_next <= std_logic_vector(shift_left(unsigned(metadata_r), 8));

          case page_header_state is
            when START =>
              case field_state is
                when HEADER =>
                  field_state_next <= DATA;
                  if current_byte = x"15" then
                    page_header_state_next <= PAGETYPE;
                  else
                    top_state_next <= FAULT;
                  end if;

                when others =>
                  -- START has no data
              end case; -- Start field_state

            when PAGETYPE =>
              case field_state is
                when DATA =>
                  -- PAGETYPE is only ever one byte long, we are not interested in its contents because the pagetype can be determined later as well.
                  field_state_next <= HEADER;

                when HEADER =>
                  field_state_next <= DATA;
                  if current_byte = x"15" then
                    page_header_state_next <= UNCOMPRESSED_SIZE;
                    start_varint <= '1'; -- Next cycle UNCOMPRESSED_SIZE will have to be decoded.
                  else
                    top_state_next <= FAULT;
                  end if;
              end case; -- PAGETYPE field_state

            when UNCOMPRESSED_SIZE =>
              case field_state is
                when DATA =>
                  if current_byte(7) = '0' then -- Last byte of varint
                    field_state_next <= HEADER;
                  end if;
                when HEADER =>
                  -- Move decoded uncomp_size data to proper register
                  uncomp_size_r_next <= varint_dec_out_data;
                  field_state_next <= DATA;
                  if current_byte = x"15" then
                    page_header_state_next <= COMPRESSED_SIZE;
                    start_varint <= '1'; -- Next cycle COMPRESSED_SIZE will have to be decoded.
                  else
                    top_state_next <= FAULT;
                  end if;
              end case; -- UNCOMPRESSED_SIZE field_state

            when COMPRESSED_SIZE =>
              case field_state is
                when DATA =>
                  if current_byte(7) = '0' then -- Last byte of varint
                    field_state_next <= HEADER;
                  end if;

                when HEADER =>
                  -- Move decoded comp_size data to proper register
                  comp_size_r_next <= varint_dec_out_data;

                  if current_byte = x"15" then
                    page_header_state_next <= CRC;
                    field_state_next <= DATA;
                  elsif current_byte = x"5c" then
                    page_header_state_next <= DATA_PAGE_HEADER;
                    field_state_next <= HEADER;
                  elsif current_byte = x"4c" then
                    page_header_state_next <= DICT_PAGE_HEADER;
                    field_state_next <= HEADER;
                  else
                    top_state_next <= FAULT;
                  end if;
              end case; -- COMPRESSED_SIZE field_state

            when CRC =>
              -- We are not actually interested in the contents of this field
              case field_state is
                when DATA =>
                  if current_byte(7) = '0' then -- Last byte of varint
                    field_state_next <= HEADER;
                  end if;

                when HEADER =>
                  field_state_next <= HEADER;

                  if current_byte = x"4c" then
                    page_header_state_next <= DATA_PAGE_HEADER;
                  elsif current_byte = x"3c" then
                    page_header_state_next <= DICT_PAGE_HEADER;
                  else
                    top_state_next <= FAULT;
                  end if;
              end case; -- CRC field_state

            when DATA_PAGE_HEADER =>
              case data_page_header_state is
                when START =>
                  case field_state is
                    when HEADER =>
                      field_state_next <= DATA;
  
                      if current_byte = x"15" then
                        data_page_header_state_next <= NUM_VALUES;
                        start_varint <= '1';
                      else
                        top_state_next <= FAULT;
                      end if;

                    when others =>
                      -- START has no data
                  end case; -- Start field_state

                when NUM_VALUES =>
                  case field_state is
                    when DATA =>
                      if current_byte(7) = '0' then -- Last byte of varint
                        field_state_next <= HEADER;
                      end if;

                    when HEADER =>
                      -- Move decoded num_values data to proper register
                      num_values_r_next <= varint_dec_out_data;
                      field_state_next <= DATA;
  
                      if current_byte = x"15" then
                        data_page_header_state_next <= NUM_NULLS;
                      else
                        top_state_next <= FAULT;
                      end if;
                  end case; -- NUM_VALUES field_state

                when NUM_NULLS =>
                  -- We are not actually interested in the contents of this field
                  case field_state is
                    when DATA =>
                      if current_byte(7) = '0' then -- Last byte of varint
                        field_state_next <= HEADER;
                      end if;

                    when HEADER =>
                      field_state_next <= DATA;
  
                      if current_byte = x"15" then
                        data_page_header_state_next <= NUM_ROWS;
                      else
                        top_state_next <= FAULT;
                      end if;
                  end case; -- NUM_NULLS field_state

                when NUM_ROWS =>
                  -- We are not actually interested in the contents of this field
                  case field_state is
                    when DATA =>
                      if current_byte(7) = '0' then -- Last byte of varint
                        field_state_next <= HEADER;
                      end if;

                    when HEADER =>
                      field_state_next <= DATA;
  
                      if current_byte = x"15" then
                        data_page_header_state_next <= ENCODING;
                      else
                        top_state_next <= FAULT;
                      end if;
                  end case; -- NUM_ROWS field_state

                when ENCODING =>
                  case field_state is
                    when DATA =>
                      -- ENCODING is only ever one byte long. Only one encoding is currently supported. This is not checked by hw.
                      field_state_next <= HEADER;

                    when HEADER =>
                      field_state_next <= DATA;
  
                      if current_byte = x"15" then
                        data_page_header_state_next <= DEF_LEVEL_BYTE_LENGTH;
                        start_varint <= '1';
                      else
                        top_state_next <= FAULT;
                      end if;
                  end case; -- ENCODING field_state

                when DEF_LEVEL_BYTE_LENGTH =>
                  case field_state is
                    when DATA =>
                      if current_byte(7) = '0' then -- Last byte of varint
                        field_state_next <= HEADER;
                      end if;

                    when HEADER =>
                      -- Move decoded num_values data to proper register
                      def_lvl_size_r_next <= varint_dec_out_data;
                      field_state_next <= DATA;
  
                      if current_byte = x"15" then
                        data_page_header_state_next <= REP_LEVEL_BYTE_LENGTH;
                        start_varint <= '1';
                      else
                        top_state_next <= FAULT;
                      end if;
                  end case; -- DEF_LEVEL_ENCODING field_state

                when REP_LEVEL_BYTE_LENGTH =>
                  case field_state is
                    when DATA =>
                      if current_byte(7) = '0' then -- Last byte of varint
                        field_state_next <= HEADER;
                      end if;

                    when HEADER =>
                      -- Move decoded num_values data to proper register
                      rep_lvl_size_r_next <= varint_dec_out_data;
  
                      if current_byte = x"00" then -- End of DataPageHeader struct
                        data_page_header_state_next <= DONE;
                      elsif current_byte = x"11" or current_byte = x"12" then -- Optional IS_COMPRESSED field is present
                        data_page_header_state_next <= IS_COMPRESSED;
                        field_state_next <= HEADER;
                      elsif current_byte = x"2c" then -- Optional STATISTICS field is present
                        data_page_header_state_next <= STATISTICS;
                      else
                        top_state_next <= FAULT;
                      end if;
                  end case; -- REP_LEVEL_ENCODING field_state

                when IS_COMPRESSED =>
                  if current_byte = x"00" then -- End of DataPageHeader struct
                    data_page_header_state_next <= DONE;
                  elsif current_byte = x"1c" then
                    data_page_header_state_next <= STATISTICS;
                  else
                    top_state_next <= FAULT;
                  end if;

                when DONE =>
                  if current_byte = x"00" then -- End of PageHeader struct
                    top_state_next <= DONE;
                  else
                    top_state_next <= FAULT;
                  end if;

                when others =>
                  -- Not implemented
                  top_state_next <= FAULT;
              end case; -- data_page_header_state

            when DICT_PAGE_HEADER =>
              -- Not yet implemented
              top_state_next <= FAULT;

            when others =>
              -- Not implemented
              top_state_next <= FAULT;
          end case; -- page_header_state
        end if;

      when DONE =>
        -- Reset metadata interpretation state machine
        page_header_state_next <= START;
        data_page_header_state_next <= START;
        field_state_next <= HEADER;

        da_valid <= '1';

        if da_ready = '1' then
          top_state_next <= IDLE;
          cycle_count_r_next <= (others => '0');
        end if;

      when others =>

    end case;


  end process;
  
  state_p: process (clk)
  begin
    if rising_edge(clk) then
      if hw_reset = '1' then
        top_state <= IDLE;
        page_header_state <= START;
        data_page_header_state <= START;
        field_state <= HEADER;

        uncomp_size_r <= (others => '0');
        num_values_r <= (others => '0');
        comp_size_r <= (others => '0');
        rep_lvl_size_r <= (others => '0');
        def_lvl_size_r <= (others => '0');
        cycle_count_r <= (others => '0');
        metadata_r <= (others => '0');
      else
        top_state <= top_state_next;
        page_header_state <= page_header_state_next;
        data_page_header_state <= data_page_header_state_next;
        field_state <= field_state_next;

        uncomp_size_r <= uncomp_size_r_next;
        comp_size_r   <= comp_size_r_next;
        num_values_r  <= num_values_r_next;
        rep_lvl_size_r <= rep_lvl_size_r_next;
        def_lvl_size_r <= def_lvl_size_r_next;
        metadata_r <= metadata_r_next;
        cycle_count_r <= cycle_count_r_next;
      end if;
    end if;
  end process;
end architecture;