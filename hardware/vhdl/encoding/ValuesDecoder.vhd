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

-- Todo: description

entity ValuesDecoder is
  generic (
    -- Bus data width
    BUS_DATA_WIDTH              : natural;

    -- Bus address width
    BUS_ADDR_WIDTH              : natural;

    -- Arrow index field width
    INDEX_WIDTH                 : natural;

    -- Fletcher command stream tag width
    CMD_TAG_WIDTH               : natural;

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

    -- Bytes consumed stream to DataAligner
    bc_data                     : out std_logic_vector(log2ceil(BUS_DATA_WIDTH/8)-1 downto 0);
    bc_ready                    : in  std_logic;
    bc_valid                    : out std_logic;

    -- Command stream to Fletcher ColumnWriter
    cmd_valid                   : out std_logic;
    cmd_ready                   : in  std_logic;
    cmd_firstIdx                : out std_logic_vector(INDEX_WIDTH-1 downto 0);
    cmd_lastIdx                 : out std_logic_vector(INDEX_WIDTH-1 downto 0);
    cmd_ctrl                    : out std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
    cmd_tag                     : out std_logic_vector(CMD_TAG_WIDTH-1 downto 0) := (others => '0');

    -- Unlock stream from Fletcher ColumnWriter
    unl_valid                   : in  std_logic;
    unl_ready                   : out std_logic;
    unl_tag                     : in  std_logic_vector(CMD_TAG_WIDTH-1 downto 0);

    --Data out stream to Fletcher ColumnWriter
    out_valid                   : out std_logic;
    out_ready                   : in  std_logic;
    out_last                    : out std_logic;
    out_dvalid                  : out std_logic := '1';
    out_data                    : out std_logic_vector(BUS_DATA_WIDTH-1 downto 0)
  );
end ValuesDecoder;

architecture behv of ValuesDecoder is

  type state_t is (IDLE, COMMAND, DECODING, PAGE_END, UNLOCK, DONE);

  type reg_record is record
    state                       : state_t;
    interm_total_val_counter    : unsigned(31 downto 0);
    total_val_counter           : unsigned(31 downto 0);
    bus_word_counter            : unsigned(31 downto 0);
  end record;

  -- The amount of values transferred to the ColumnWriter every cycle
  constant ELEMENTS_PER_CYCLE : natural := BUS_DATA_WIDTH/PRIM_WIDTH;

  signal r : reg_record;
  signal d : reg_record;

begin

  logic_p: process (r, in_valid, in_data, out_ready, unl_valid, cmd_ready, bc_ready, values_buffer_addr, page_num_values, total_num_values,
                    compressed_size, ctrl_start)
    variable v : reg_record;
  begin
    v := r;

    ctrl_done <= '0';

    in_ready <= '0';
    out_valid <= '0';

    bc_valid  <= '0';
    -- Bytes consumed of final bus word = compressed size % BUS_DATA_WIDTH/8
    bc_data   <= compressed_size(log2ceil(BUS_DATA_WIDTH/8)-1 downto 0);

    cmd_valid       <= '0';
    cmd_firstIdx    <= (others => '0');
    cmd_lastIdx     <= total_num_values;
    cmd_ctrl        <= values_buffer_addr;
    cmd_tag         <= (others => '0');

    unl_ready <= '0';

    case r.state is
      when IDLE =>
        if ctrl_start = '1' then
          v.state := COMMAND;
        end if;

      when COMMAND =>
        cmd_valid <= '1';

        if cmd_ready = '1' then
          v.state := DECODING;
        end if;

      when DECODING =>
        -- Todo: DECODING stage is now fully combinatorial between inputs and outputs. Should probably insert an explicit decoder (which for PLAIN is just pass through)
        -- and accompanying StreamSlices
        in_ready <= '1';

        out_valid <= in_valid;
        in_ready  <= out_ready;
        out_data  <= in_data;

        if in_valid = '1' and out_ready = '1' then
         -- Upon transfer of values to ColumnWriter:
          v.interm_total_val_counter := r.interm_total_val_counter + ELEMENTS_PER_CYCLE;
          v.bus_word_counter         := r.bus_word_counter + 1;

          if v.interm_total_val_counter >= unsigned(total_num_values) then
            -- The ParquetReader is done, proceed to unlock
            out_last <= '1';
            v.state := UNLOCK;
          elsif r.bus_word_counter = unsigned(compressed_size(31 downto log2ceil(BUS_DATA_WIDTH/8))) then
            -- End of page
            v.state := PAGE_END; 
          end if;
        end if;

      when PAGE_END =>
        bc_valid <= '1';

        if bc_ready = '1' then
          v.state                    := DECODING;
          v.bus_word_counter         := (others => '0');
          v.total_val_counter        := r.total_val_counter + unsigned(page_num_values);
          v.interm_total_val_counter := v.total_val_counter;
        end if;

      when UNLOCK =>
        unl_ready <= '1';

        if unl_valid = '1' then
          v.state := DONE;
        end if;

      when DONE =>
        ctrl_done <= '1';

    end case;

    d <= v;

  end process;

  state_p: process (clk)
  begin
    if rising_edge(clk) then
      if reset = '1' then
        r.state                    <= IDLE;
        r.total_val_counter        <= (others => '0');
        r.bus_word_counter         <= (others => '0');
        r.interm_total_val_counter <= (others => '0');
      else
        r <= d;
      end if;
    end if;
  end process;
end architecture;