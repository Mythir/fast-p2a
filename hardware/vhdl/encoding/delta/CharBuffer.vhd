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
use work.Delta.all;
use work.Encoding.all;

entity CharBuffer is
  generic (
    -- Bus data width
    BUS_DATA_WIDTH              : natural;

    -- Amount of chars supplied to Fletcher per cycle
    CHARS_PER_CYCLE             : natural;

    BYTES_IN_BLOCK_WIDTH        : natural;

    RAM_CONFIG                  : string := ""
  );
  port (
    -- Rising-edge sensitive clock.
    clk                         : in  std_logic;

    -- Active-high synchronous reset.
    reset                       : in  std_logic;

    -- If all lengths in the page have been read (from BlockValuesAligner)
    lengths_processed           : in  std_logic;

    -- Data in stream from DeltaHeaderReader
    in_valid                    : in  std_logic;
    in_ready                    : out std_logic;
    in_last                     : in  std_logic;
    in_data                     : in  std_logic_vector(BUS_DATA_WIDTH-1 downto 0);

    -- Bytes consumed stream from BlockValuesAligner
    bc_valid                    : in  std_logic;
    bc_ready                    : out std_logic;
    bc_data                     : in  std_logic_vector(BYTES_IN_BLOCK_WIDTH-1 downto 0);

    -- Num chars stream from DeltaAccumulator
    nc_valid                    : in  std_logic;
    nc_ready                    : out std_logic;
    nc_last                     : in  std_logic;
    nc_data                     : in  std_logic_vector(31 downto 0);

    -- Handshake signaling start of new page
    new_page_valid              : in  std_logic;
    new_page_ready              : out std_logic;

    --Data out stream to Fletcher ColumnWriter
    out_valid                   : out std_logic;
    out_ready                   : in  std_logic;
    out_last                    : out std_logic;
    out_data                    : out std_logic_vector(log2ceil(CHARS_PER_CYCLE+1) + CHARS_PER_CYCLE*8 - 1 downto 0)
  );
end CharBuffer;

architecture behv of CharBuffer is

  type state_t is (REQ_PAGE, SKIP_LENGTHS, PASS_CHARS, DONE);

  -- 16 bits is a suitable size for adv_count in the case of the default 128 block_size, 4 miniblocks configuration.
  constant ADV_COUNT_WIDTH      : natural := BYTES_IN_BLOCK_WIDTH;
  constant OUT_COUNT_WIDTH      : natural := log2ceil(CHARS_PER_CYCLE+1);
  constant OUT_CHARS_WIDTH      : natural := CHARS_PER_CYCLE*8;

  constant SHIFT_AMOUNT_WIDTH   : natural := log2ceil(BUS_DATA_WIDTH/8);
  constant NUM_SHIFT_STAGES     : natural := SHIFT_AMOUNT_WIDTH;

  constant SHIFTER_CTRL_WIDTH   : natural := 0;
  constant SHIFTER_DATA_WIDTH   : natural := 2*BUS_DATA_WIDTH;
  constant SHIFTER_INPUT_WIDTH  : natural := SHIFTER_CTRL_WIDTH + SHIFTER_DATA_WIDTH;
  constant SHIFTER_OUTPUT_WIDTH : natural := SHIFTER_CTRL_WIDTH + SHIFTER_DATA_WIDTH;

  constant FIFO_DATA_WIDTH      : natural := 1 + BUS_DATA_WIDTH;

  type reg_record is record
    state             : state_t;
    -- Accumulate bytes (string lengths) to skip
    bc_accumulator    : unsigned(31 downto 0);
    -- Keep track of how much has been skipped
    skipped_words     : unsigned(31-SHIFT_AMOUNT_WIDTH downto 0);
    -- Characters left to read in page
    chars_to_read     : unsigned(31 downto 0);
    -- Hold registers for shifter_in
    hold              : std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
    hold_last         : std_logic;
    -- '1' if last page
    last_page         : std_logic;
  end record;

  signal r : reg_record;
  signal d : reg_record;

  signal fifo_in_data           : std_logic_vector(FIFO_DATA_WIDTH-1 downto 0);
  signal fifo_out_valid         : std_logic;
  signal fifo_out_ready         : std_logic;
  signal fifo_out_data          : std_logic_vector(FIFO_DATA_WIDTH-1 downto 0);

  signal adv_valid              : std_logic;
  signal adv_ready              : std_logic;
  signal adv_count              : std_logic_vector(ADV_COUNT_WIDTH-1 downto 0);

  signal shift_amount           : std_logic_vector(SHIFT_AMOUNT_WIDTH-1 downto 0);

  signal s_pipe_input           : std_logic_vector(SHIFTER_INPUT_WIDTH-1 downto 0);
  signal s_pipe_output          : std_logic_vector(SHIFTER_OUTPUT_WIDTH-1 downto 0);

  -- Stream in to shifter
  signal shifter_in_valid       : std_logic;
  signal shifter_in_ready       : std_logic;
  signal shifter_in_data        : std_logic_vector(SHIFTER_INPUT_WIDTH-1 downto 0);

  -- Stream out from shifter
  signal shifter_out_valid      : std_logic;
  signal shifter_out_ready      : std_logic;
  signal shifter_out_data       : std_logic_vector(SHIFTER_OUTPUT_WIDTH-1 downto 0);

  -- Separate components of shifter_out_data
  signal shifter_in_chars       : std_logic_vector(2*BUS_DATA_WIDTH-1 downto 0);

  signal s_out_valid            : std_logic;
  signal s_out_ready            : std_logic;
  signal out_count              : std_logic_vector(OUT_COUNT_WIDTH-1 downto 0);
  signal out_chars              : std_logic_vector(OUT_CHARS_WIDTH-1 downto 0);

  -- Reset certain components upon handshaking a new page
  signal new_page_reset         : std_logic;
  signal pipeline_reset         : std_logic;

begin

  pipeline_reset <= reset or new_page_reset;
  
  -----------------------------------------------------------------------------
  -- FiFo used to buffer data from DeltaHeaderReader and skip string lengths
  -----------------------------------------------------------------------------

  fifo_in_data <= in_last & in_data;
  adv_count <= std_logic_vector(resize(r.bc_accumulator(31 downto SHIFT_AMOUNT_WIDTH) - r.skipped_words, adv_count'length));

  -- Depth 32 should be plenty
  in_buffer: AdvanceableFiFo
    generic map(
      DATA_WIDTH              => BUS_DATA_WIDTH+1,
      ADV_COUNT_WIDTH         => ADV_COUNT_WIDTH,
      DEPTH_LOG2              => 5
    )
    port map(
      clk                     => clk,
      reset                   => pipeline_reset,
      in_valid                => in_valid,
      in_ready                => in_ready,
      in_data                 => fifo_in_data,
      out_valid               => fifo_out_valid,
      out_ready               => fifo_out_ready,
      out_data                => fifo_out_data,
      adv_valid               => adv_valid,
      adv_ready               => adv_ready,
      adv_count               => adv_count
    );

  ---------------------------------------------------------------------------------------------------
  -- Barrel shifter for re-aligning data from DeltaHeaderReader after having read all string lengths
  ---------------------------------------------------------------------------------------------------
  shifter_in_chars <= r.hold & fifo_out_data(BUS_DATA_WIDTH-1 downto 0);
  shifter_in_data <= shifter_in_chars;
  shift_amount <= std_logic_vector(r.bc_accumulator(SHIFT_AMOUNT_WIDTH-1 downto 0));

  pipeline_ctrl: StreamPipelineControl
    generic map (
      IN_DATA_WIDTH             => SHIFTER_INPUT_WIDTH,
      OUT_DATA_WIDTH            => SHIFTER_OUTPUT_WIDTH,
      NUM_PIPE_REGS             => NUM_SHIFT_STAGES,
      INPUT_SLICE               => false,
      RAM_CONFIG                => RAM_CONFIG
    )
    port map (
      clk                       => clk,
      reset                     => pipeline_reset,
      in_valid                  => shifter_in_valid,
      in_ready                  => shifter_in_ready,
      in_data                   => shifter_in_data,
      out_valid                 => shifter_out_valid,
      out_ready                 => shifter_out_ready,
      out_data                  => shifter_out_data,
      pipe_valid                => open,
      pipe_input                => s_pipe_input,
      pipe_output               => s_pipe_output
    );

  pipeline: StreamPipelineBarrel
    generic map (
      ELEMENT_WIDTH             => 8,
      ELEMENT_COUNT             => SHIFTER_DATA_WIDTH/8,
      AMOUNT_WIDTH              => SHIFT_AMOUNT_WIDTH,
      DIRECTION                 => "left",
      OPERATION                 => "shift",
      NUM_STAGES                => NUM_SHIFT_STAGES,
      CTRL_WIDTH                => SHIFTER_CTRL_WIDTH
    )
    port map (
      clk                       => clk,
      reset                     => pipeline_reset,
      in_data                   => s_pipe_input(SHIFTER_DATA_WIDTH-1 downto 0),
      in_ctrl                   => s_pipe_input(SHIFTER_CTRL_WIDTH+SHIFTER_DATA_WIDTH-1 downto SHIFTER_DATA_WIDTH),
      in_amount                 => shift_amount,
      out_data                  => s_pipe_output(SHIFTER_DATA_WIDTH-1 downto 0),
      out_ctrl                  => s_pipe_output(SHIFTER_OUTPUT_WIDTH-1 downto SHIFTER_DATA_WIDTH)
    );

  -----------------------------------------------------------
  -- If chars per cycle is limited serialize shifter output
  -----------------------------------------------------------

  serialization_required: if BUS_DATA_WIDTH /= OUT_CHARS_WIDTH generate
  begin
    ss_inst: StreamGearboxSerializer
      generic map(
        ELEMENT_WIDTH                => BUS_DATA_WIDTH,
        IN_COUNT_MAX              => BUS_DATA_WIDTH/OUT_CHARS_WIDTH,
        IN_COUNT_WIDTH            => log2ceil(BUS_DATA_WIDTH/OUT_CHARS_WIDTH)
      )
      port map(
        clk                       => clk,
        reset                     => pipeline_reset,
        in_valid                  => shifter_out_valid,
        in_ready                  => shifter_out_ready,
        in_data                   => shifter_out_data(SHIFTER_DATA_WIDTH-1 downto BUS_DATA_WIDTH),
        out_valid                 => s_out_valid,
        out_ready                 => s_out_ready,
        out_data                  => out_chars
      );
  end generate;

  no_serialization_required: if BUS_DATA_WIDTH = OUT_CHARS_WIDTH generate
  begin
    shifter_out_ready <= s_out_ready;
    s_out_valid       <= shifter_out_valid;
    out_chars         <= shifter_out_data(SHIFTER_DATA_WIDTH-1 downto BUS_DATA_WIDTH);
  end generate;

  -- out_chars endian swapped to comply with Fletcher LSB alignment requirements
  out_data    <= out_count & endianSwap(out_chars);

  -------------------
  -- State machine
  -------------------

  logic_p: process(r, new_page_valid, shifter_in_valid, bc_data, adv_ready, fifo_out_valid, bc_valid, nc_valid, nc_last, nc_data, fifo_out_data, shifter_in_ready,
                   s_out_ready, s_out_valid, lengths_processed, out_ready)
    variable v : reg_record;
  begin
    v := r;

    new_page_ready   <= '0';
    bc_ready         <= '0';
    adv_valid        <= '0';
    nc_ready         <= '0';

    shifter_in_valid <= '0';
    fifo_out_ready   <= '0';

    out_valid   <= '0';
    s_out_ready <= '0';

    new_page_reset <= '0';

    out_count <= std_logic_vector(to_unsigned(CHARS_PER_CYCLE, out_count'length));
    out_last  <= '0';

    case r.state is
      when REQ_PAGE =>
        -- Handshake a new page with the PreDecBuffer and store relevant page metadata.
        new_page_ready <= '1';

        if new_page_valid = '1' then
          new_page_reset   <= '1';
          v.state          := SKIP_LENGTHS;
          v.bc_accumulator := (others => '0');
          v.skipped_words  := (others => '0');
        end if;

      when SKIP_LENGTHS =>
        -- Keep skipping bus words in the Advanceable FiFo based on the bytes consumed information from BlockValuesAligner
        bc_ready <= '1';

        -- Accumulate bytes to skip
        if bc_valid = '1' then
          v.bc_accumulator := r.bc_accumulator + unsigned(bc_data);
        end if;

        -- If the amount of bytes we need to skip is not equal to the amount of bytes we skipped, ask the advanceable fifo to delete some bus words
        if r.bc_accumulator(31 downto SHIFT_AMOUNT_WIDTH) /= r.skipped_words then
          adv_valid <= '1';

          if adv_ready = '1' then
            v.skipped_words := r.bc_accumulator(31 downto SHIFT_AMOUNT_WIDTH);
          end if;
        elsif nc_valid = '1' and bc_valid = '0' and fifo_out_valid = '1' and lengths_processed = '1' then
          -- If DeltaHeaderReader has a char count ready, if block values aligner has no more bc info, and if the fifo has valid data on its output, start passing characters to the output stream
          nc_ready            <= '1';
          fifo_out_ready      <= '1';
          v.state             := PASS_CHARS;
          v.chars_to_read     := unsigned(nc_data);
          v.last_page         := nc_last;
          v.hold              := fifo_out_data(BUS_DATA_WIDTH-1 downto 0);
          v.hold_last         := fifo_out_data(BUS_DATA_WIDTH);
        end if;

      when PASS_CHARS =>
        -- Connect output of charbuffer to Shifter/StreamSerializer
        out_valid   <= s_out_valid;
        s_out_ready <= out_ready;

        shifter_in_valid <= fifo_out_valid or r.hold_last;

        -- Feed data into the shifter
        if shifter_in_valid = '1' and shifter_in_ready = '1' then
          fifo_out_ready  <= '1';
          v.hold          := fifo_out_data(BUS_DATA_WIDTH-1 downto 0);
          -- Only set hold_last if the output of the fifo is valid
          if fifo_out_valid = '1' then
            v.hold_last     := fifo_out_data(BUS_DATA_WIDTH);
          end if;
        end if;

        -- Upon handshake, decrease amount of chars left to read
        if s_out_valid = '1' and s_out_ready = '1' then
          v.chars_to_read := r.chars_to_read - CHARS_PER_CYCLE;
        end if;

        -- When we are almost done, cut out_count short and determine if this was the last page
        if r.chars_to_read <= CHARS_PER_CYCLE then
          out_count <= std_logic_vector(resize(r.chars_to_read, out_count'length));
          if r.last_page = '1' then
            out_last <= '1';
          end if;

          if s_out_valid = '1' and s_out_ready = '1' then
            if r.last_page = '1' then
              v.state := DONE;
            else
              v.state := REQ_PAGE;
            end if;
          end if;
        end if;


      when DONE =>

    end case;

    d <= v;
  end process;

  clk_p: process(clk)
  begin
    if rising_edge(clk) then
      if reset = '1' then
        r.state           <= REQ_PAGE;
      else
        r <= d;
      end if;
    end if;
  end process;

end architecture;