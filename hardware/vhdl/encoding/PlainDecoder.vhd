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
use work.UtilMisc_pkg.all;
use work.Stream_pkg.all;

-- This PlainDecoder does not actually have to decode anything because the "PLAIN" encoding just stores the values as normal integers or floats. 
-- This module is only concerned with limiting its input to exactly one page per handshaked page, and supplying the correct count with out_data to the
-- Fletcher arraywriters.

entity PlainDecoder is
  generic (
    -- Bus data width
    BUS_DATA_WIDTH              : natural;

    -- Max amount of elements supplied to the ArrayWriters per cycle
    ELEMENTS_PER_CYCLE          : natural;

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

    --Data out stream to Fletcher ArrayWriter
    out_valid                   : out std_logic;
    out_ready                   : in  std_logic;
    out_last                    : out std_logic;
    out_dvalid                  : out std_logic := '1';
    out_data                    : out std_logic_vector(log2ceil(ELEMENTS_PER_CYCLE+1) + ELEMENTS_PER_CYCLE*PRIM_WIDTH - 1 downto 0)
  );
end PlainDecoder;

architecture behv of PlainDecoder is

  type state_t is (IDLE, IN_PAGE, DONE);

  type reg_record is record 
    state             : state_t;
    egress_counter    : unsigned(32 - log2ceil(ELEMENTS_PER_CYCLE) downto 0);
    ingress_counter   : unsigned(31 downto 0);
    total_val_counter : unsigned(31 downto 0);
    m_page_num_values : unsigned(31 downto 0);
  end record;

  constant VALUES_IN_BUS_WORD : natural := BUS_DATA_WIDTH/PRIM_WIDTH;

  signal r : reg_record;
  signal d : reg_record;

  -- Amount of valid values in a bus word
  signal val_count : std_logic_vector(log2floor(ELEMENTS_PER_CYCLE) downto 0);

  -- Amount of bus words in a page that contain exactly elements_per_cycle values
  signal egress_total : unsigned(32 - log2ceil(ELEMENTS_PER_CYCLE) downto 0);

  -- If the last bus word of the page does not contain the max amount of elements per cycle, it will instead contain this much.
  signal val_misalignment : unsigned(log2floor(ELEMENTS_PER_CYCLE)-1 downto 0);

  -- Out stream
  signal buffer_in_valid : std_logic;
  signal buffer_in_ready : std_logic;
  signal buffer_in_last  : std_logic;

  -- Serializer in stream
  signal sgs_in_valid   : std_logic;
  signal sgs_in_ready   : std_logic;
  signal sgs_in_data    : std_logic_vector(BUS_DATA_WIDTH-1 downto 0);

  -- Serializer out stream
  signal sgs_out_valid   : std_logic;
  signal sgs_out_ready   : std_logic;
  signal sgs_out_data    : std_logic_vector(ELEMENTS_PER_CYCLE*PRIM_WIDTH-1 downto 0);

  signal new_page_reset  : std_logic;
  signal pipeline_reset  : std_logic;

begin
  pipeline_reset <=  new_page_reset or reset;

  sgs_inst: StreamGearboxSerializer
    generic map(
      ELEMENT_WIDTH             => ELEMENTS_PER_CYCLE*PRIM_WIDTH,
      IN_COUNT_MAX              => BUS_DATA_WIDTH/(ELEMENTS_PER_CYCLE*PRIM_WIDTH),
      IN_COUNT_WIDTH            => log2ceil(BUS_DATA_WIDTH/(ELEMENTS_PER_CYCLE*PRIM_WIDTH))
    )
    port map(
      clk                       => clk,
      reset                     => pipeline_reset,
      in_valid                  => sgs_in_valid,
      in_ready                  => sgs_in_ready,
      in_data                   => endianSwap(sgs_in_data),
      out_valid                 => sgs_out_valid,
      out_ready                 => sgs_out_ready,
      out_data                  => sgs_out_data
    );

  sgs_in_data <= in_data;

  out_valid <= buffer_in_valid;
  buffer_in_ready <= out_ready;
  out_last <= buffer_in_last;
  out_data <= val_count & sgs_out_data;

  egress_total <= resize(r.m_page_num_values(31 downto log2ceil(ELEMENTS_PER_CYCLE)), egress_total'length);
  val_misalignment <= r.m_page_num_values(log2floor(ELEMENTS_PER_CYCLE)-1 downto 0);

  logic_p: process(r, page_num_values, total_num_values, sgs_out_valid, buffer_in_last, new_page_valid, val_count,
                   buffer_in_ready, egress_total, val_misalignment, in_valid, sgs_in_ready, sgs_in_valid)
    variable v                      : reg_record;
    variable egress_counter_inc   : unsigned(32 - log2ceil(ELEMENTS_PER_CYCLE) downto 0);
    variable total_val_counter_inc  : unsigned(31 downto 0);
    variable total_remaining_values : unsigned(31 downto 0);
  begin
    v := r;
    egress_counter_inc := r.egress_counter + 1;

    new_page_ready <= '0';
    ctrl_done <= '0';
    val_count <= std_logic_vector(to_unsigned(ELEMENTS_PER_CYCLE, val_count'length));

    buffer_in_valid <= '0';
    sgs_out_ready   <= '0';
    buffer_in_last  <= '0';

    sgs_in_valid <= '0';
    in_ready     <= '0';

    new_page_reset <= '0';

    case r.state is
      when IDLE =>
        -- IDLE: wait for a new page to be handshaked, after which we can store the relevant metadata and reset the egress_counter to 0.
        new_page_ready <= '1';

        total_remaining_values := unsigned(total_num_values) - r.total_val_counter;

        if new_page_valid = '1' then
          v.state             := IN_PAGE;

          new_page_reset <= '1';

          if total_remaining_values <= unsigned(page_num_values) then
            v.m_page_num_values := total_remaining_values;
          else
            v.m_page_num_values := unsigned(page_num_values);
          end if;

          v.egress_counter  := (others => '0');
          v.ingress_counter := (others => '0');
        end if;

      when IN_PAGE =>
        -- IN_PAGE: The state where data in the page is actually processed
        buffer_in_valid <= sgs_out_valid;
        sgs_out_ready   <= buffer_in_ready;

        -- Only allow input if we have not seen the entire page yet
        if r.ingress_counter < r.m_page_num_values then
          sgs_in_valid <= in_valid;
          in_ready     <= sgs_in_ready;
        end if;

        if sgs_in_valid = '1' and sgs_in_ready = '1' then
          v.ingress_counter := r.ingress_counter + VALUES_IN_BUS_WORD;
        end if;

        -- If the last bus word is not a full bus word (implied) and this is the last bus word: set val_count to the amount of values in this bus word.
        if r.egress_counter = egress_total then
          val_count      <= "0" & std_logic_vector(val_misalignment);
        end if;

        total_val_counter_inc := r.total_val_counter + unsigned(val_count);

        -- If this bus word contains the very last value, assert buffer_in_last
        if total_val_counter_inc = unsigned(total_num_values) then
          buffer_in_last <= '1';
        end if;

        if sgs_out_valid = '1' and buffer_in_ready = '1' then
          v.egress_counter := egress_counter_inc;
          v.total_val_counter := total_val_counter_inc;

          if buffer_in_last = '1' then
            v.state := DONE;
          elsif (v.egress_counter = egress_total and val_misalignment = to_unsigned(0, val_misalignment'length)) or r.egress_counter = egress_total then
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
        r.egress_counter    <= (others => '0');
        r.total_val_counter <= (others => '0');
        r.ingress_counter   <= (others => '0');
      else
        r <= d;
      end if;
    end if;
  end process;

end architecture;