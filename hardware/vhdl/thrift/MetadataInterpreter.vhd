
-- Copyright 2018 Delft University of Technology
--
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

-- Todo: Description

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
    cycle_count                 : out std_logic_vector(31 downto 0);
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
  type data_page_header_state_t is (START, NUM_VALUES, ENCODING, DEF_LEVEL_ENCODING, REP_LEVEL_ENCODING, STATISTICS);
      signal data_page_header_state, data_page_header_state_next : data_page_header_state_t;

  -- Is the byte we are looking at part of a field header, or field data.
  type field_state_t is (HEADER, DATA);
      signal field_state, field_state_next : field_state_t;

  -- Shift register for metadata input
  signal metadata_r                 : std_logic_vector(METADATA_WIDTH-1 downto 0);
  signal metadata_r_next            : std_logic_vector(METADATA_WIDTH-1 downto 0);

  -- Registers for decoded metadata output
  signal md_uncomp_size_r              : std_logic_vector(31 downto 0);
  signal md_comp_size_r                : std_logic_vector(31 downto 0);
  signal md_num_values_r               : std_logic_vector(31 downto 0);
  signal md_uncomp_size_r_next         : std_logic_vector(31 downto 0);
  signal md_comp_size_r_next           : std_logic_vector(31 downto 0);
  signal md_num_values_r_next          : std_logic_vector(31 downto 0);

  -- Keep score of cycles for debugging purposes
  signal cycle_count_r              : std_logic_vector(31 downto 0);

begin

  md_uncomp_size <= md_uncomp_size_r;
  md_comp_size <= md_comp_size_r;
  md_num_values <= md_num_values_r;
  cycle_count <= cycle_count_r;

  mst_rreq_addr <= md_addr;

  -- Always only request 1 beat per transfer
  mst_rreq_len <= std_logic_vector(to_unsigned(1, BUS_LEN_WIDTH));

  logic_p: process (metadata_state, page_header_state, data_page_header_state, field_state, ctrl_start,
                    top_state, mst_rreq_ready, mst_rdat_valid, metadata_r) is
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
    metadata_r_next <= metadata_r;

    -- Gross debugging stuff. Allow writing to user regs and status reg.
    regs_out_en <= (others => '0');
    regs_out_en(NUM_REGS-1 downto NUM_REGS-3) <= "111";
    regs_out_en(1) <= '1';


    -- By default the interpreter is not ready to receive data
    mst_rdat_ready <= '0';
    mst_rreq_valid <= '0';

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

        -- TODO REMOVE TEMPORARILY REMOVED CHECK FOR DEBUG
        --if ctrl_start = '1' then
          top_state_next <= READ_MEM_REQ;
        --end if;

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
          metadata_r_next <= mst_rdat_data(BUS_DATA_WIDTH-1 downto BUS_DATA_WIDTH - METADATA_WIDTH);
          top_state_next <= INTERPRETING;
        end if;

      when INTERPRETING =>
        -- To be implemented, now simply debug stuff
        ctrl_idle <= '0';
        ctrl_busy <= '1';
        ctrl_done <= '0';

        -- Just checking the contents of the metadata register for debugging purposes
        md_uncomp_size_r_next <= metadata_r(METADATA_WIDTH-1 downto METADATA_WIDTH - 32);
        md_comp_size_r_next <= metadata_r(METADATA_WIDTH-33 downto METADATA_WIDTH-64);

        if(metadata_r(METADATA_WIDTH-1 downto METADATA_WIDTH - 32) = x"15041580") then
          md_num_values_r_next(0) <= '1';
        end if;

        if(metadata_r(METADATA_WIDTH-33 downto METADATA_WIDTH-64) = X"7d15807d") then
          md_num_values_r_next(1) <= '1';
        end if;

        top_state_next <= DONE;

      when DONE =>
        ctrl_idle <= '1';
        ctrl_busy <= '0';
        ctrl_done <= '1';

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
        cycle_count_r <= std_logic_vector(to_unsigned(0, 32));
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
      end if;
    end if;
  end process;
end architecture;