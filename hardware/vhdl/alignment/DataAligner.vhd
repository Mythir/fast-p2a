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
use work.Alignment.all;

-- Todo: description

entity DataAligner is
  generic (
    -- Bus data width
    BUS_DATA_WIDTH              : natural := 512;

    -- Number of consumers requesting aligned data.
    NUM_CONSUMERS               : natural;

    -- Number of stages in the barrel shifter pipeline
    NUM_SHIFT_STAGES            : natural
  );
  port (

    -- Rising-edge sensitive clock.
    clk                         : in  std_logic;

    -- Active-high synchronous reset.
    reset                       : in  std_logic;

    -- Unaligned data in
    in_valid                    : in  std_logic;
    in_ready                    : out std_logic;
    in_data                     : in  std_logic_vector(BUS_DATA_WIDTH-1 downto 0);

    -- Aligned data_out
    out_valid                   : out std_logic_vector(NUM_CONSUMERS-1 downto 0);
    out_ready                   : in  std_logic_vector(NUM_CONSUMERS-1 downto 0);
    out_data                    : out std_logic_vector(BUS_DATA_WIDTH-1 downto 0);

    -- Consumer alignment information
    -- Each consumer reports back how many bytes of the last bus word it actually needed
    bytes_consumed              : in  std_logic_vector(NUM_CONSUMERS*log2ceil(BUS_DATA_WIDTH/8)-1 downto 0);
    bc_valid                    : in  std_logic_vector(NUM_CONSUMERS-1 downto 0);
    bc_ready                    : out std_logic_vector(NUM_CONSUMERS-1 downto 0);

    -- Producer alignment information
    -- The ingester might read from unaligned memory addresses. Misalignment should stay constant for sequential reads.
    prod_alignment              : in  std_logic_vector(log2ceil(BUS_DATA_WIDTH/8)-1 downto 0);
    pa_valid                    : in  std_logic;
    pa_ready                    : out std_logic
  );
end DataAligner;

architecture behv of DataAligner is
  
  -- Top level state in the state machine
  type state_t is (IDLE, STANDARD, REALIGNING);
      signal state, state_next : state_t;

  constant CONSUMER_INDEX_WIDTH       : natural := log2ceil(NUM_CONSUMERS);
  constant SHIFT_WIDTH                : natural := log2ceil(BUS_DATA_WIDTH/8);

  -- The StreamPipelineControl in ShifterRecombiner can buffer an amount of data words equal to 2**(log2ceil(NUM_PIPE_REGS+1)+1) (see StreamPipelineControl.vhd in the Fletcher repo).
  -- Therefore, the HistoryBuffer should be able to buffer that many data words plus 1 for the recombiner register in ShifterRecombiner.
  constant HISTORY_BUFFER_DEPTH_LOG2  : natural := log2ceil(NUM_SHIFT_STAGES+1)+2;

  -- Index of current consumer
  signal c                            : integer range 0 to NUM_CONSUMERS-1;
  signal c_next                       : integer range 0 to NUM_CONSUMERS-1;

  -- How many bytes to shift the data for alignment
  signal alignment                    : std_logic_vector(SHIFT_WIDTH-1 downto 0);
  signal alignment_next               : std_logic_vector(SHIFT_WIDTH-1 downto 0);

  -- Shift_rec input stream
  signal shift_rec_in_valid           : std_logic;
  signal shift_rec_in_ready           : std_logic;
  signal shift_rec_in_data            : std_logic_vector(BUS_DATA_WIDTH-1 downto 0);

  -- Shift_rec output stream
  signal shift_rec_out_valid          : std_logic;
  signal shift_rec_out_ready          : std_logic;

  -- Hist_buf output stream
  signal hist_buffer_out_valid        : std_logic;
  signal hist_buffer_out_ready        : std_logic;
  signal hist_buffer_out_data         : std_logic_vector(BUS_DATA_WIDTH-1 downto 0);

  -- Hist_buf input stream, synchronized with shift_rec input stream during STANDARD operation, otherwise blocked
  signal hist_buffer_in_valid         : std_logic;
  signal hist_buffer_in_ready         : std_logic;

  signal start_realignment            : std_logic;
  signal end_realignment              : std_logic;
  signal hist_buffer_delete_oldest    : std_logic;

begin
  
  hist_buffer_inst: HistoryBuffer
  generic map(
    BUS_DATA_WIDTH           => BUS_DATA_WIDTH,
    DEPTH_LOG2               => HISTORY_BUFFER_DEPTH_LOG2
  )
  port map(
    clk                      => clk,
    reset                    => reset,
    in_valid                 => hist_buffer_in_valid,
    in_ready                 => hist_buffer_in_ready,
    in_data                  => shift_rec_in_data,
    out_valid                => hist_buffer_out_valid,
    out_ready                => hist_buffer_out_ready,
    out_data                 => hist_buffer_out_data,
    start_rewind             => start_realignment,
    end_rewind               => end_realignment,
    delete_oldest            => hist_buffer_delete_oldest
  );

  shift_rec_inst: ShifterRecombiner
  generic map(
    BUS_DATA_WIDTH           => BUS_DATA_WIDTH,
    SHIFT_WIDTH              => SHIFT_WIDTH,
    ELEMENT_WIDTH            => 8,
    NUM_SHIFT_STAGES         => NUM_SHIFT_STAGES
  )
  port map(
    clk                      => clk,
    reset                    => reset,
    clear                    => start_realignment,
    in_valid                 => shift_rec_in_valid,
    in_ready                 => shift_rec_in_ready,
    in_data                  => shift_rec_in_data,
    out_valid                => shift_rec_out_valid,
    out_ready                => shift_rec_out_ready,
    out_data                 => out_data,
    alignment                => alignment
  );

  -- Whenever data is consumed from the DataAligner, the oldest entry in the hist_buf can be deleted
  hist_buffer_delete_oldest <= shift_rec_out_valid and shift_rec_out_ready;

  logic_p: process(c, alignment, state, bc_valid, pa_valid, prod_alignment, bytes_consumed, in_data, 
                   shift_rec_in_ready, hist_buffer_in_ready, in_valid, shift_rec_out_valid, out_ready, 
                   hist_buffer_out_data, hist_buffer_out_valid, end_realignment)
  begin
    -- Default values
    bc_ready <= (others => '0');
    pa_ready <= '0';

    start_realignment <= '0';
    shift_rec_in_data <= in_data;

    -- Normally, no data can be exchanged between the DataAligner input and the shift_rec/hist_buf inputs
    shift_rec_in_valid <= '0';
    hist_buffer_in_valid <= '0';
    in_ready <= '0';

    hist_buffer_out_ready <= '0';

    c_next <= c;
    alignment_next <= alignment;

    out_valid <= (others => '0');
    shift_rec_out_ready <= '0';

    case state is
      when IDLE =>
      -- Get initial alignment from producer
      pa_ready <= '1';

      if pa_valid = '1' then
        state_next <= STANDARD;
        alignment_next <= std_logic_vector(unsigned(alignment) + unsigned(prod_alignment));
      end if;

      when STANDARD =>
        bc_ready(c) <= '1';

        if bc_valid(c) = '1' then
          state_next <= REALIGNING;
          alignment_next <= std_logic_vector(unsigned(alignment) + unsigned(bytes_consumed(SHIFT_WIDTH*c + SHIFT_WIDTH-1 downto SHIFT_WIDTH*c)));
          start_realignment <= '1';

            -- Rollover to first consumer after last consumer is done
          if c = NUM_CONSUMERS-1 then
            c_next <= 0;
          else
            c_next <= c+1;
          end if;
        end if;
        
        -- Synchronize shift_rec and hist_buffer input streams
        in_ready <= shift_rec_in_ready and hist_buffer_in_ready;
        shift_rec_in_valid <= in_valid and hist_buffer_in_ready;
        hist_buffer_in_valid <= in_valid and shift_rec_in_ready;

        out_valid(c) <= shift_rec_out_valid;
        shift_rec_out_ready <= out_ready(c);

      when REALIGNING =>
        bc_ready(c) <= '1';

        if bc_valid(c) = '1' then
          alignment_next <= std_logic_vector(unsigned(alignment) + unsigned(bytes_consumed(SHIFT_WIDTH*c + SHIFT_WIDTH-1 downto SHIFT_WIDTH*c)));
          start_realignment <= '1';

            -- Rollover to first consumer after last consumer is done
          if c = NUM_CONSUMERS-1 then
            c_next <= 0;
          else
            c_next <= c+1;
          end if;
        end if;

        -- Connect hist_buffer ouput stream to shift_rec input stream
        shift_rec_in_data <= hist_buffer_out_data;
        shift_rec_in_valid <= hist_buffer_out_valid;
        hist_buffer_out_ready <= shift_rec_in_ready;

        out_valid(c) <= shift_rec_out_valid;
        shift_rec_out_ready <= out_ready(c);

        if end_realignment = '1' then
          state_next <= STANDARD;
        end if;

    end case;
  end process;

  state_p: process (clk)
  begin
    if rising_edge(clk) then
      if reset = '1' then
        c <= 0;
        alignment <= std_logic_vector(to_unsigned(0, SHIFT_WIDTH));
        state <= IDLE;
      else
        c <= c_next;
        alignment <= alignment_next;
        state <= state_next;
      end if;
    end if;
  end process;

end architecture;