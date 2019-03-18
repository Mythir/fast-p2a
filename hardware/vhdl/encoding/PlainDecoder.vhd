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

-- This PlainDecoder does not actually have to decode anything because the "PLAIN" encoding just stores the values as normal integers or floats. Instead
-- the complexity comes from the fact that each page can have an arbitrary number of values and we always want to sent <elements_per_cycle> values
-- to the ColumnWriter per transaction. Every time we start a new page, the PreDecBuffer in the ValuesDecoder handshakes the PlainDecoder to let it know it should
-- store that page's relevant metadata, which the PlainDecoder will use to send the correct amount of values to the ValBuffer. The ValBuffer stores the values until
-- it has enough to send to the ColumnWriter.

entity PlainDecoder is
  generic (
    -- Bus data width
    BUS_DATA_WIDTH              : natural;

    -- Bit width of a single primitive value
    PRIM_WIDTH                  : natural
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

    --Data out stream to Fletcher ColumnWriter
    out_valid                   : out std_logic;
    out_ready                   : in  std_logic;
    out_last                    : out std_logic;
    out_dvalid                  : out std_logic := '1';
    out_data                    : out std_logic_vector(BUS_DATA_WIDTH-1 downto 0)
  );
end PlainDecoder;

architecture behv of PlainDecoder is
  -- The amount of values transferred to the ColumnWriter every cycle
  constant ELEMENTS_PER_CYCLE : natural := BUS_DATA_WIDTH/PRIM_WIDTH;

  type state_t is (IDLE, IN_PAGE, DONE);

  type reg_record is record 
    state             : state_t;
    bus_word_counter  : unsigned(32 - log2ceil(ELEMENTS_PER_CYCLE) downto 0);
    total_val_counter : unsigned(31 downto 0);
    m_page_num_values : unsigned(31 downto 0);
  end record;

  signal r : reg_record;
  signal d : reg_record;

  -- Signal with in_data in correct byte order
  signal s_in_data : std_logic_vector(BUS_DATA_WIDTH-1 downto 0);

  -- Amount of valid values in a bus word
  signal val_count : std_logic_vector(log2floor(ELEMENTS_PER_CYCLE) downto 0);

  -- Amount of bus words in a page that contain exactly elements_per_cycle values
  signal full_bus_words_in_page : unsigned(32 - log2ceil(ELEMENTS_PER_CYCLE) downto 0);

  -- If the last bus word of the page does not contain the max amount of elements per cycle, it will instead contain this much.
  signal val_misalignment : unsigned(log2floor(ELEMENTS_PER_CYCLE)-1 downto 0);

  signal buffer_in_valid : std_logic;
  signal buffer_in_ready : std_logic;
  signal buffer_in_last  : std_logic;
begin

  s_in_data <= endian_swap(in_data);

  valbuffer_inst: entity work.ValBuffer
  generic map(
    BUS_DATA_WIDTH              => BUS_DATA_WIDTH,
    PRIM_WIDTH                  => PRIM_WIDTH
  )
  port map(
    clk                         => clk,
    reset                       => reset,
    in_valid                    => buffer_in_valid,
    in_ready                    => buffer_in_ready,
    in_count                    => val_count,
    in_last                     => buffer_in_last,
    in_data                     => s_in_data,
    out_valid                   => out_valid,
    out_ready                   => out_ready,
    out_last                    => out_last,
    out_data                    => out_data
  );

  full_bus_words_in_page <= resize(r.m_page_num_values(31 downto log2ceil(ELEMENTS_PER_CYCLE)), full_bus_words_in_page'length);
  val_misalignment <= r.m_page_num_values(log2floor(ELEMENTS_PER_CYCLE)-1 downto 0);

  logic_p: process(r, page_num_values, total_num_values, in_valid, buffer_in_last, new_page_valid, val_count,
                   buffer_in_ready, full_bus_words_in_page, val_misalignment)
    variable v                      : reg_record;
    variable bus_word_counter_inc   : unsigned(32 - log2ceil(ELEMENTS_PER_CYCLE) downto 0);
    variable total_val_counter_inc  : unsigned(31 downto 0);
    variable total_remaining_values : unsigned(31 downto 0);
  begin
    v := r;
    bus_word_counter_inc := r.bus_word_counter + 1;

    new_page_ready <= '0';
    ctrl_done <= '0';
    val_count <= std_logic_vector(to_unsigned(ELEMENTS_PER_CYCLE, val_count'length));

    buffer_in_valid <= '0';
    in_ready <= '0';
    buffer_in_last  <= '0';

    case r.state is
      when IDLE =>
        -- IDLE: wait for a new page to be handshaked, after which we can store the relevant metadata and reset the bus_word_counter to 0.
        new_page_ready <= '1';

        total_remaining_values := unsigned(total_num_values) - r.total_val_counter;

        if new_page_valid = '1' then
          v.state             := IN_PAGE;

          if total_remaining_values <= unsigned(page_num_values) then
            v.m_page_num_values := total_remaining_values;
          else
            v.m_page_num_values := unsigned(page_num_values);
          end if;

          v.bus_word_counter  := (others => '0');
        end if;

      when IN_PAGE =>
        -- IN_PAGE: The state where data in the page is actually processed
        buffer_in_valid <= in_valid;
        in_ready <= buffer_in_ready;

        -- If the last bus word is not a full bus word (implied) and this is the last bus word: set val_count to the amount of values in this bus word.
        if r.bus_word_counter = full_bus_words_in_page then
          val_count      <= "0" & std_logic_vector(val_misalignment);
        end if;

        total_val_counter_inc := r.total_val_counter + unsigned(val_count);

        -- If this bus word contains the very last value, assert buffer_in_last
        if total_val_counter_inc = unsigned(total_num_values) then
          buffer_in_last <= '1';
        end if;

        if in_valid = '1' and buffer_in_ready = '1' then
          v.bus_word_counter := bus_word_counter_inc;
          v.total_val_counter := total_val_counter_inc;

          if buffer_in_last = '1' then
            v.state := DONE;
          elsif (v.bus_word_counter = full_bus_words_in_page and val_misalignment = to_unsigned(0, val_misalignment'length)) or r.bus_word_counter = full_bus_words_in_page then
            -- The new state will be idle either when a final transfer with val_count < elements_per_cycle is not required or we just had that final transfer.
            v.state := IDLE;
          end if;
        end if;

      when DONE =>
        ctrl_done <= '1';

    end case;

    d <= v;
  end process;

  clk_p: process (clk)
  begin
    if rising_edge(clk) then
      if reset = '1' then
        r.state             <= IDLE;
        r.bus_word_counter  <= (others => '0');
        r.total_val_counter <= (others => '0');
      else
        r <= d;
      end if;
    end if;
  end process;

end architecture;