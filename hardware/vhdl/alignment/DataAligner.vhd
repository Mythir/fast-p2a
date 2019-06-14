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
use work.UtilInt_pkg.all;
use work.Alignment.all;

-- In essence, the DataAligner is a pipelined barrel shifter with a buffer containing recently processed (unaligned) input words. 
-- Every time one of its consumers has received all the data is needed it should report back how many bytes in the last bus word were
-- actually needed by that consumer (all other bytes are for the next consumer). The DataAligner will use this information and the 
-- contents of the HistoryBuffer to realign and provide the next consumer with the realigned data.
--
-- The DataAligner will count the number of bytes read from the Ingester. Once this equals the total size of the data the DataAligner
-- will send garbage into the ShifterRecombiner to flush it. This functionality was included late in development to patch a bug
-- where the DataAligner could get stuck if the data_size supplied to the hardware was a very tight fit for the actually needed data.
--
-- Note: If a consumer handshakes an output word, it is expected to need at least 1 byte from it. It can't report back it has consumed
-- 0 bytes from it. Using all bytes is fine.

entity DataAligner is
  generic (
    -- Bus data width
    BUS_DATA_WIDTH              : natural := 512;

    BUS_ADDR_WIDTH              : natural := 64;

    -- Number of consumers requesting aligned data.
    NUM_CONSUMERS               : natural := 5;

    -- Number of stages in the barrel shifter pipeline
    NUM_SHIFT_STAGES            : natural := 6
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
    bytes_consumed              : in  std_logic_vector(NUM_CONSUMERS*(log2ceil(BUS_DATA_WIDTH/8)+1)-1 downto 0);
    bc_valid                    : in  std_logic_vector(NUM_CONSUMERS-1 downto 0);
    bc_ready                    : out std_logic_vector(NUM_CONSUMERS-1 downto 0);

    -- Producer alignment information
    -- The ingester might read from unaligned memory addresses. Misalignment should stay constant for sequential reads.
    prod_alignment              : in  std_logic_vector(log2ceil(BUS_DATA_WIDTH/8)-1 downto 0);
    pa_valid                    : in  std_logic;
    pa_ready                    : out std_logic;

    data_size                   : in  std_logic_vector(BUS_ADDR_WIDTH-1 downto 0)
  );
end DataAligner;

architecture behv of DataAligner is
  
  -- Top level state in the state machine
  type state_t is (IDLE, STANDARD, REALIGNING);
      signal state, state_next : state_t;

  constant CONSUMER_INDEX_WIDTH       : natural := log2ceil(NUM_CONSUMERS);
  constant SHIFT_WIDTH                : natural := log2ceil(BUS_DATA_WIDTH/8);

  -- The StreamPipelineControl in ShifterRecombiner can buffer an amount of data words equal to 2**(log2ceil(NUM_PIPE_REGS+1)+1) (see StreamPipelineControl.vhd in the Fletcher repo).
  -- Therefore, the HistoryBuffer should be able to buffer that many data words plus 1 for the recombiner register in ShifterRecombiner and 1 for the most recently consumed data word.
  constant HISTORY_BUFFER_DEPTH_LOG2  : natural := log2ceil(NUM_SHIFT_STAGES+1)+2;

  -- Index of current consumer
  signal c                            : integer range 0 to NUM_CONSUMERS-1;
  signal c_next                       : integer range 0 to NUM_CONSUMERS-1;

  -- How many bytes to shift the data for alignment
  signal alignment                    : std_logic_vector(SHIFT_WIDTH-1 downto 0);
  -- 1 wider to check for overflow
  signal alignment_next               : std_logic_vector(SHIFT_WIDTH downto 0);

  -- Number of bytes in the input data
  signal bytes_to_read                : signed(BUS_ADDR_WIDTH downto 0);
  signal bytes_to_read_next           : signed(BUS_ADDR_WIDTH downto 0);

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

  -- Signal used to indicate if just outputted bus word was the first to that consumer
  signal first_in_align_group         : std_logic;
  signal first_in_align_group_next    : std_logic;

  -- Internal copy of in_ready
  signal s_in_ready                   : std_logic;

begin

  in_ready <= s_in_ready;
  
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

  -- Whenever data is consumed from the DataAligner and it is not the first consumed by this consumer, the oldest entry in the hist_buf can be deleted
  -- OR
  -- There has been a rollover calculating the new alignment so we need to delete an entry from the history buffer.
  hist_buffer_delete_oldest <= (shift_rec_out_valid and shift_rec_out_ready and not first_in_align_group) or alignment_next(alignment_next'high);

  logic_p: process(c, alignment, state, bc_valid, pa_valid, prod_alignment, bytes_consumed, in_data, 
                   shift_rec_in_ready, hist_buffer_in_ready, in_valid, shift_rec_out_valid, out_ready, 
                   hist_buffer_out_data, hist_buffer_out_valid, end_realignment, shift_rec_out_ready,
                   first_in_align_group, data_size, s_in_ready, bytes_to_read)
  begin
    -- Default values
    bc_ready <= (others => '0');
    pa_ready <= '0';

    start_realignment <= '0';
    shift_rec_in_data <= in_data;

    -- Normally, no data can be exchanged between the DataAligner input and the shift_rec/hist_buf inputs
    shift_rec_in_valid <= '0';
    hist_buffer_in_valid <= '0';
    s_in_ready <= '0';

    hist_buffer_out_ready <= '0';

    c_next <= c;
    alignment_next <= '0' & alignment;
    first_in_align_group_next <= first_in_align_group;
    state_next <= state;
    bytes_to_read_next <= bytes_to_read;

    out_valid <= (others => '0');
    shift_rec_out_ready <= '0';

    -- Upon transmission of a data word to a consumer, the next word offered to the consumer won't be the first in the align group
    if shift_rec_out_valid = '1' and shift_rec_out_ready = '1' then
      first_in_align_group_next <= '0';
    end if;

    case state is
      when IDLE =>
      -- Get initial alignment from producer. In the current implementation a change in the producer alignment is not allowed.
      pa_ready <= '1';

      if pa_valid = '1' then
        state_next <= STANDARD;
        alignment_next <= '0' & std_logic_vector(unsigned(alignment) + unsigned(prod_alignment));
        bytes_to_read_next <= signed(resize((unsigned(prod_alignment) + unsigned(data_size)), bytes_to_read_next'length));
      end if;

      when STANDARD =>
        bc_ready(c) <= '1';

        if bc_valid(c) = '1' then
          state_next <= REALIGNING;
          alignment_next <= std_logic_vector(unsigned('0' & alignment) + unsigned(bytes_consumed((SHIFT_WIDTH+1)*(c+1)-1 downto (SHIFT_WIDTH+1)*c)));
          start_realignment <= '1';
          first_in_align_group_next <= '1';

            -- Rollover to first consumer after last consumer is done
          if c = NUM_CONSUMERS-1 then
            c_next <= 0;
          else
            c_next <= c+1;
          end if;
        end if;
        
        -- Synchronize shift_rec and hist_buffer input streams
        s_in_ready <= shift_rec_in_ready and hist_buffer_in_ready;
        shift_rec_in_valid <= in_valid and hist_buffer_in_ready;
        hist_buffer_in_valid <= in_valid and shift_rec_in_ready;

        out_valid(c) <= shift_rec_out_valid;
        shift_rec_out_ready <= out_ready(c);

        -- Continuously count bytes consumed from ingester.
        if in_valid = '1' and s_in_ready = '1' then
          bytes_to_read_next <= bytes_to_read - BUS_DATA_WIDTH/8;
        end if;

        -- Once ingester has nothing left to give, put garbage into the ShifterRecombiner.
        -- This is to avoid the ShifterRecombiner getting stuck on the final real bus word from the ingester.
        if bytes_to_read < 0 then
          shift_rec_in_valid <= '1';
        end if;

      when REALIGNING =>
        bc_ready(c) <= '1';

        if bc_valid(c) = '1' then
          alignment_next <= std_logic_vector(unsigned('0' & alignment) + unsigned(bytes_consumed((SHIFT_WIDTH+1)*(c+1)-1 downto (SHIFT_WIDTH+1)*c)));
          start_realignment <= '1';
          first_in_align_group_next <= '1';

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
        first_in_align_group <= '1';
      else
        c <= c_next;
        alignment <= alignment_next(SHIFT_WIDTH-1 downto 0);
        state <= state_next;
        first_in_align_group <= first_in_align_group_next;
        bytes_to_read <= bytes_to_read_next;
      end if;
    end if;
  end process;

end architecture;