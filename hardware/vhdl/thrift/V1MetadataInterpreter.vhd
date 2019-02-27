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
use work.Encoding.all;

-- This unit is responsible for getting relevant values from the Parquet page header metadata. 
-- At this point only num_values, comp_size, uncomp_size are needed by the rest of the hardware.
-- Includes simple hardware for AXI communication but this will be removed in the future in favour of a centralised ingester.
-- Will in the future also require handshakes with components that need data from this interpreter.

entity MetadataInterpreter is
  generic (

    -- Width of the data read with every read request to the memory.
    METADATA_WIDTH              : natural := 512;

    -- Bus address width
    BUS_ADDR_WIDTH              : natural;

    -- Bus data width
    BUS_DATA_WIDTH              : natural;

    -- Bus burst length width
    BUS_LEN_WIDTH               : natural;

    -- Width of the register that stores the amount of bytes processed. 8 bits should be plenty for page metadata
    CYCLE_COUNT_WIDTH           : natural := 8;

    NUM_REGS                    : natural


  );
  port (

    -- Rising-edge sensitive clock.
    clk                         : in  std_logic;

    -- Active-high synchronous reset.
    hw_reset                    : in  std_logic;

    -- Master port.
    mst_rreq_valid              : out std_logic;
    mst_rreq_ready              : in  std_logic;
    mst_rreq_addr               : out std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
    mst_rreq_len                : out std_logic_vector(BUS_LEN_WIDTH-1 downto 0);
    mst_rdat_valid              : in  std_logic;
    mst_rdat_ready              : out std_logic;
    mst_rdat_data               : in  std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
    mst_rdat_last               : in  std_logic;

    -- Fletcher status signals
    ctrl_done                   : out std_logic;
    ctrl_busy                   : out std_logic;
    ctrl_idle                   : out std_logic;
    ctrl_reset                  : in std_logic;
    ctrl_stop                   : in std_logic;
    ctrl_start                  : in std_logic;

    -- Metadata output
    md_uncomp_size              : out std_logic_vector(31 downto 0);
    md_comp_size                : out  std_logic_vector(31 downto 0);
    md_num_values               : out std_logic_vector(31 downto 0);

    -- For debugging purposes
    cycle_count                 : out std_logic_vector(CYCLE_COUNT_WIDTH-1 downto 0);
    regs_out_en                 : out std_logic_vector(NUM_REGS-1 downto 0);

    -- Pointer to metadata that should be interpreted
    md_addr                     : in std_logic_vector(BUS_ADDR_WIDTH-1 downto 0)

  );
end MetadataInterpreter;

architecture behv of MetadataInterpreter is

  -- Top level state in the state machine
  type top_state_t is (RESET, IDLE, READ_MEM_REQ, READ_MEM_DAT, INTERPRETING, DONE, FAULT);
      signal top_state, top_state_next : top_state_t;
  
  -- Which Parquet metadata structure is being interpreted
  type metadata_state_t is (COLUMN_CHUNK, PAGE);
      signal metadata_state, metadata_state_next : metadata_state_t;

  -- If in a PageHeader struct, which field is being interpreted
  type page_header_state_t is (START, PAGETYPE, UNCOMPRESSED_SIZE, COMPRESSED_SIZE, CRC, DATA_PAGE_HEADER, DICT_PAGE_HEADER);
      signal page_header_state, page_header_state_next : page_header_state_t;

  -- If in a DataPageHeader struct, which field is being interpreted
  type data_page_header_state_t is (START, NUM_VALUES, ENCODING, DEF_LEVEL_ENCODING, REP_LEVEL_ENCODING, STATISTICS, DONE);
      signal data_page_header_state, data_page_header_state_next : data_page_header_state_t;

  -- Is the byte we are looking at part of a field header, or field data.
  type field_state_t is (HEADER, DATA);
      signal field_state, field_state_next : field_state_t;

  -- The integers encoded as varint in the page headers are always 32 bits wide
  constant VARINT_WIDTH             : natural := 32;

  -- Shift register for metadata input
  signal metadata_r                 : std_logic_vector(METADATA_WIDTH-1 downto 0);
  signal metadata_r_next            : std_logic_vector(METADATA_WIDTH-1 downto 0);

  -- Registers for decoded metadata output
  signal md_uncomp_size_r           : std_logic_vector(31 downto 0);
  signal md_comp_size_r             : std_logic_vector(31 downto 0);
  signal md_num_values_r            : std_logic_vector(31 downto 0);
  signal md_uncomp_size_r_next      : std_logic_vector(31 downto 0);
  signal md_comp_size_r_next        : std_logic_vector(31 downto 0);
  signal md_num_values_r_next       : std_logic_vector(31 downto 0);

  -- Keep score of cycles
  signal cycle_count_r              : std_logic_vector(CYCLE_COUNT_WIDTH-1 downto 0);
  signal cycle_count_r_next         : std_logic_vector(CYCLE_COUNT_WIDTH-1 downto 0);

  -- The byte of the input that is currently being inspected
  signal current_byte               : std_logic_vector(7 downto 0);

  -- Used to signal the varint_decoder it will have to start decoding in the next clock cycle
  signal start_varint               : std_logic;

  -- Used to signal validity of the current_byte.
  signal current_byte_valid         : std_logic;

  -- VarIntDecoder output
  signal varint_dec_out_data        : std_logic_vector(VARINT_WIDTH-1 downto 0);

begin
  
  -- For now always 1 (Todo: implement logic)
  current_byte_valid <= '1';

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

  md_uncomp_size <= md_uncomp_size_r;
  md_comp_size <= md_comp_size_r;
  md_num_values <= md_num_values_r;
  cycle_count <= cycle_count_r;

  mst_rreq_addr <= md_addr;

  current_byte <= metadata_r(METADATA_WIDTH-1 downto METADATA_WIDTH-8);

  -- Always only request 1 beat per transfer
  mst_rreq_len <= std_logic_vector(to_unsigned(1, BUS_LEN_WIDTH));

  logic_p: process (metadata_state, page_header_state, data_page_header_state, field_state, ctrl_start,
                    top_state, mst_rreq_ready, mst_rdat_valid, metadata_r, current_byte, start_varint, current_byte_valid, varint_dec_out_data) is
  begin
    -- Default values
    top_state_next <= top_state;
    metadata_state_next <= metadata_state;
    page_header_state_next <= page_header_state;
    data_page_header_state_next <= data_page_header_state;
    field_state_next <= field_state;

    md_uncomp_size_r_next <= md_uncomp_size_r;
    md_comp_size_r_next <= md_comp_size_r;
    md_num_values_r_next <= md_num_values_r;
    cycle_count_r_next <= cycle_count_r;
    metadata_r_next <= metadata_r;

    -- Gross debugging stuff. Allow writing to user regs and status reg.
    regs_out_en <= (others => '0');
    regs_out_en(NUM_REGS-1 downto NUM_REGS-3) <= "111";
    regs_out_en(1) <= '1';

    -- By default the interpreter is not ready to receive data
    mst_rdat_ready <= '0';
    mst_rreq_valid <= '0';

    start_varint <= '0';

    -- State machine
    case top_state is
      when RESET =>
        ctrl_idle <= '0';
        ctrl_busy <= '0';
        ctrl_done <= '0';

        top_state_next <= IDLE;

      when IDLE =>
        -- Wait for signal to begin
        ctrl_idle <= '1';
        ctrl_busy <= '0';
        ctrl_done <= '0';

        if ctrl_start = '1' then
          top_state_next <= READ_MEM_REQ;
        end if;

      when READ_MEM_REQ =>
        -- Send address of metadata to master
        ctrl_idle <= '0';
        ctrl_busy <= '1';
        ctrl_done <= '0';

        mst_rreq_valid <= '1';

        if mst_rreq_ready = '1' then
          top_state_next <= READ_MEM_DAT;
        end if;

      when READ_MEM_DAT =>
        -- Read metadata from memory
        ctrl_idle <= '0';
        ctrl_busy <= '1';
        ctrl_done <= '0';

        mst_rdat_ready <= '1';

        if mst_rdat_valid = '1' then
          -- Swap the bytes to their correct order (first byte of metadata on the left). Todo: Implement this in the ingester/aligner instead.
          metadata_r_next <= mst_rdat_data(BUS_DATA_WIDTH-1 downto BUS_DATA_WIDTH - METADATA_WIDTH);
          top_state_next <= INTERPRETING;
        end if;

      when INTERPRETING =>
        ctrl_idle <= '0';
        ctrl_busy <= '1';
        ctrl_done <= '0';

        -- Just checking the contents of the metadata register for debugging purposes
        -----------------------------------------------
        --md_uncomp_size_r_next <= metadata_r(METADATA_WIDTH-1 downto METADATA_WIDTH - 32);
        --md_comp_size_r_next <= metadata_r(METADATA_WIDTH-33 downto METADATA_WIDTH-64);

        --if(metadata_r(METADATA_WIDTH-1 downto METADATA_WIDTH - 32) = x"15041580") then
        --  md_num_values_r_next(0) <= '1';
        --end if;

        --if(metadata_r(METADATA_WIDTH-33 downto METADATA_WIDTH-64) = X"7d15807d") then
        --  md_num_values_r_next(1) <= '1';
        --end if;
        -----------------------------------------------

        cycle_count_r_next <= std_logic_vector(unsigned(cycle_count_r) + 1);

        -- Shift the metadata register with one byte to the left every clock cycle.
        metadata_r_next <= metadata_r(METADATA_WIDTH-9 downto 0) & "00000000";

        case metadata_state is
          when PAGE =>
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
                    md_uncomp_size_r_next <= varint_dec_out_data;
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
                    md_comp_size_r_next <= varint_dec_out_data;

                    if current_byte = x"15" then
                      page_header_state_next <= CRC;
                      field_state_next <= DATA;
                    elsif current_byte = x"2c" then
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
                    if current_byte = x"1c" then
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
                        md_num_values_r_next <= varint_dec_out_data;
                        field_state_next <= DATA;
    
                        if current_byte = x"15" then
                          data_page_header_state_next <= ENCODING;
                        else
                          top_state_next <= FAULT;
                        end if;
                    end case; -- COMPRESSED_SIZE field_state
  
                  when ENCODING =>
                    case field_state is
                      when DATA =>
                        -- ENCODING is only ever one byte long. Only one encoding is currently supported. This is not checked by hw.
                        field_state_next <= HEADER;
                      when HEADER =>
                        field_state_next <= DATA;
    
                        if current_byte = x"15" then
                          data_page_header_state_next <= DEF_LEVEL_ENCODING;
                        else
                          top_state_next <= FAULT;
                        end if;
                    end case; -- ENCODING field_state
  
                  when DEF_LEVEL_ENCODING =>
                    case field_state is
                      when DATA =>
                        -- DEF_LEVEL_ENCODING is only ever one byte long. Only one encoding is currently supported. This is not checked by hw.
                        field_state_next <= HEADER;
                      when HEADER =>
                        field_state_next <= DATA;
    
                        if current_byte = x"15" then
                          data_page_header_state_next <= REP_LEVEL_ENCODING;
                        else
                          top_state_next <= FAULT;
                        end if;
                    end case; -- DEF_LEVEL_ENCODING field_state
  
                  when REP_LEVEL_ENCODING =>
                    case field_state is
                      when DATA =>
                        -- REP_LEVEL_ENCODING is only ever one byte long. Only one encoding is currently supported. This is not checked by hw.
                        field_state_next <= HEADER;
                      when HEADER =>
    
                        if current_byte = x"00" then -- End of DataPageHeader struct
                          data_page_header_state_next <= DONE;
                        elsif current_byte = x"1c" then
                          data_page_header_state_next <= STATISTICS;
                        else
                          top_state_next <= FAULT;
                        end if;
                    end case; -- REP_LEVEL_ENCODING field_state
  
                  when STATISTICS =>
                    -- Not supported. For some reason parquet-cpp prints an empty statistics struct instead of no statistics struct when statistics are disabled.
                    -- This bypass sends the state machine back to REP_LEVEL_ENCODING as if there were no statistics struct if it detects an empty statistics struct.
                    -- If the struct is not empty, than the hw goes into error state.
                    -- Cycle_count does of course still reflect the extra two bytes an empty statistics struct takes up in the header.
                    if current_byte = x"00" then -- End of Statistics struct
                      data_page_header_state_next <= REP_LEVEL_ENCODING;
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

          when others =>
            -- Only PAGE metadata structure implemented for now.
            top_state_next <= FAULT;
        end case; -- metadata_state

      when DONE =>
        ctrl_idle <= '1';
        ctrl_busy <= '0';
        ctrl_done <= '1';

        -- Reset metadata interpretation state machine
        metadata_state_next <= PAGE;
        page_header_state_next <= START;
        data_page_header_state_next <= START;
        field_state_next <= HEADER;

        -- Todo: implement restart of MetadataInterpreter

      when others =>
        ctrl_idle <= '0';
        ctrl_busy <= '0';
        ctrl_done <= '0';

    end case;


  end process;
  
  state_p: process (clk)
  begin
    if rising_edge(clk) then
      if hw_reset = '1' or ctrl_reset = '1' then
        top_state <= RESET;
        metadata_state <= PAGE;
        page_header_state <= START;
        data_page_header_state <= START;
        field_state <= HEADER;

        md_uncomp_size_r <= std_logic_vector(to_unsigned(0, 32));
        md_comp_size_r <= std_logic_vector(to_unsigned(0, 32));
        md_num_values_r <= std_logic_vector(to_unsigned(0, 32));
        cycle_count_r <= std_logic_vector(to_unsigned(0, CYCLE_COUNT_WIDTH));
        metadata_r <= std_logic_vector(to_unsigned(0, METADATA_WIDTH));
      else
        top_state <= top_state_next;
        metadata_state <= metadata_state_next;
        page_header_state <= page_header_state_next;
        data_page_header_state <= data_page_header_state_next;
        field_state <= field_state_next;

        md_uncomp_size_r <= md_uncomp_size_r_next;
        md_comp_size_r   <= md_comp_size_r_next;
        md_num_values_r  <= md_num_values_r_next;
        metadata_r <= metadata_r_next;
        cycle_count_r <= cycle_count_r_next;
      end if;
    end if;
  end process;
end architecture;