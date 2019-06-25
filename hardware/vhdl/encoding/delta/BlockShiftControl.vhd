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
use work.UtilInt_pkg.all;
use work.Stream_pkg.all;
use work.Delta.all;
use work.Ptoa.all;

-- This module interprets the data from the BlockHeaderReader and provides the shifters with the right shift amounts
-- in order to align the bit packed values in the input stream to the right in out_data. For each alignment
-- this module also provides a count of how many values it expects the BitUnpacker to unpack and a width of the bit packing.
-- This module only supports 32 bit and 64 bit bit packed integers.

-- BL stream does not have a fifo. This will cause the BlockHeaderReader to block if the
-- BlockShiftControl hasn't started processing the previous header. This is not a problem because there is no point
-- in having the BlockHeaderReader run more than one block ahead of the BlockShiftControl.
-- The BW stream does have a FiFo. This allows the BlockHeaderReader to skip ahead to the next
-- Block header while this module is processing the previous one.

entity BlockShiftControl is
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
    PRIM_WIDTH                  : natural;

    -- Width of value count output (amount values to unpack)
    COUNT_WIDTH                 : natural;

    -- Width of bit packing width output
    WIDTH_WIDTH                 : natural;

    -- Width of shift amount output
    AMOUNT_WIDTH                : natural
  );
  port (
    -- Rising-edge sensitive clock.
    clk                         : in  std_logic;

    -- Active-high synchronous reset.
    reset                       : in  std_logic;

    page_done                   : out std_logic;

    -- Data in stream from BlockValuesAligner FiFo
    in_valid                    : in  std_logic;
    in_ready                    : out std_logic;
    in_data                     : in  std_logic_vector(DEC_DATA_WIDTH-1 downto 0);

    -- Number of values in the page (from MetadataInterpreter)
    page_num_values             : in  std_logic_vector(31 downto 0);

    -- Bit width stream from BlockHeaderReader
    bw_valid                    : in  std_logic;
    bw_ready                    : out std_logic;
    bw_data                     : in  std_logic_vector(7 downto 0);

    -- Block header length stream from BlockHeaderReader
    bl_valid                    : in  std_logic;
    bl_ready                    : out std_logic;
    bl_data                     : in  std_logic_vector(log2floor(max_varint_bytes(PRIM_WIDTH)+MINIBLOCKS_IN_BLOCK) downto 0);

    --Data out stream to shifters
    out_valid                   : out std_logic;
    out_ready                   : in  std_logic;
    out_data                    : out std_logic_vector(2*DEC_DATA_WIDTH-1 downto 0);
    out_amount                  : out std_logic_vector(AMOUNT_WIDTH-1 downto 0);
    out_width                   : out std_logic_vector(WIDTH_WIDTH-1 downto 0);
    out_count                   : out std_logic_vector(COUNT_WIDTH-1 downto 0)
  );
end BlockShiftControl;

architecture behv of BlockShiftControl is

  constant VALUES_IN_MINIBLOCK : natural := BLOCK_SIZE/MINIBLOCKS_IN_BLOCK;

  constant BL_WIDTH_BYTES   : natural := log2floor(max_varint_bytes(PRIM_WIDTH)+MINIBLOCKS_IN_BLOCK) + 1;
  -- The amount of bits used to represent block header width can not be smaller than amount_width
  -- This is to avoid problems with null ranges
  constant BL_WIDTH_BITS    : natural := imax(BL_WIDTH_BYTES+log2ceil(8), AMOUNT_WIDTH);

  -- Tables containing the amount of values to unpack per cycle for every bit width. Depending on PRIM_WIDTH one of these tables goes unused.
  constant count_lut_64 : count_lut_64_t := init_count_lut_64(MAX_DELTAS_PER_CYCLE, DEC_DATA_WIDTH);
  constant count_lut_32 : count_lut_32_t := init_count_lut_32(MAX_DELTAS_PER_CYCLE, DEC_DATA_WIDTH);

  -- Tables containing the amount of bits to shift per cycle for every bit width. Depending on PRIM_WIDTH one of these tables goes unused.
  constant shift_lut_64 : shift_lut_64_t := init_shift_lut_64(MAX_DELTAS_PER_CYCLE, DEC_DATA_WIDTH);
  constant shift_lut_32 : shift_lut_32_t := init_shift_lut_32(MAX_DELTAS_PER_CYCLE, DEC_DATA_WIDTH);

  type state_t is (HEADER, DATA);

  type reg_record is record
    state            : state_t;
    -- Holding register for the most recently consumed word from the input stream
    hold             : std_logic_vector(DEC_DATA_WIDTH-1 downto 0);
    hold_valid       : std_logic;
    current_shift    : unsigned(AMOUNT_WIDTH-1 downto 0);
    -- Keep track of how many data words were skipped while shifting through block header data
    skip_counter     : unsigned(BL_WIDTH_BITS-AMOUNT_WIDTH-1 downto 0);
    -- Keep track of values processed in this page
    page_val_count   : unsigned(31 downto 0);
    -- Keep track of miniblocks processed in this block
    mb_count         : unsigned(log2ceil(MINIBLOCKS_IN_BLOCK)-1 downto 0);
    -- Keep track of values processed in this miniblock
    mb_val_count     : unsigned(log2ceil(VALUES_IN_MINIBLOCK)-1 downto 0);
  end record;

  signal r : reg_record;
  signal d : reg_record;

  -- Used to store amount of bytes in block header multiplied by 8
  -- Cannot be smaller than amount width to avoid problems with null ranges down the line
  signal bits_in_block_header   : unsigned(BL_WIDTH_BITS-1 downto 0);

  -- Stream from bit width FiFo
  signal fifo_out_valid         : std_logic;
  signal fifo_out_ready         : std_logic;
  signal fifo_out_data          : std_logic_vector(7 downto 0);

begin

  assert PRIM_WIDTH <= DEC_DATA_WIDTH
    report "Width of DeltaDecoder (" & integer'image(DEC_DATA_WIDTH) & " bits) is smaller than maximum bit packed width (" & integer'image(PRIM_WIDTH) & " bits)." severity failure;

  assert PRIM_WIDTH = 32 or PRIM_WIDTH = 64
    report "PRIM_WIDTH of " & integer'image(PRIM_WIDTH) & " is not supported. Supported integer widths: 32 or 64." severity failure;

  assert MAX_DELTAS_PER_CYCLE <= VALUES_IN_MINIBLOCK
    report "DeltaDecoder MAX_DELTAS_PER_CYCLE larger than VALUES_IN_MINIBLOCK. This is unsupported by the hardware." severity failure;

  assert log2ceil(MINIBLOCKS_IN_BLOCK)=log2floor(MINIBLOCKS_IN_BLOCK) and log2ceil(VALUES_IN_MINIBLOCK)=log2floor(VALUES_IN_MINIBLOCK)
    report "DeltaDecoder currently only supports powers of 2 for the amount of miniblocks in a block and the amount of values in a miniblock." severity failure;

  -- Can buffer a full Block's worth of bit widths
  bw_fifo: StreamFIFO
    generic map(
      DEPTH_LOG2                => log2ceil(MINIBLOCKS_IN_BLOCK),
      DATA_WIDTH                => 8
    )
    port map(
      in_clk                    => clk,
      in_reset                  => reset,
      in_valid                  => bw_valid,
      in_ready                  => bw_ready,
      in_data                   => bw_data,
      in_rptr                   => open,
      in_wptr                   => open,
      out_clk                   => clk,
      out_reset                 => reset,
      out_valid                 => fifo_out_valid,
      out_ready                 => fifo_out_ready,
      out_data                  => fifo_out_data,
      out_rptr                  => open,
      out_wptr                  => open
    );

  out_data   <= in_data & r.hold;
  out_width  <= fifo_out_data(WIDTH_WIDTH-1 downto 0);
  out_amount <= std_logic_vector(r.current_shift);

  -- Multiply bytes in block header by 8
  bits_in_block_header <= shift_left(resize(unsigned(bl_data), bits_in_block_header'length), log2ceil(8));

  logic_p: process(r, in_valid, bl_valid, out_ready, page_num_values, in_data, bits_in_block_header, fifo_out_valid, fifo_out_data)
    variable v : reg_record;
    -- One wider than current_shift to check for overflow
    variable next_shift : unsigned(AMOUNT_WIDTH downto 0);

    variable current_unpack_count : unsigned(COUNT_WIDTH-1 downto 0);
    variable current_unpack_shift : unsigned(AMOUNT_WIDTH downto 0);

    variable bl_longer_than_data_word : boolean;
  begin
    v := r;

    in_ready       <= '0';
    bl_ready       <= '0';
    out_valid      <= '0';
    fifo_out_ready <= '0';

    out_count <= (others => '0');

    -- No output blocking needed as the DeltaAccumulator will ignore any output anyway.
    -- page_done signal is only used to avoid backpressuring the stream in case this module is used for decoding strings
    -- and a CharBuffer needs to consume characters following the deltas.
    if r.page_val_count >= unsigned(page_num_values) then
      page_done <= '1';
    else
      page_done <= '0';
    end if;

    if r.hold_valid = '0' then
      in_ready <= '1';

      if in_valid = '1' then
        v.hold       := in_data;
        v.hold_valid := '1';
      end if;
    else
      case r.state is
        when HEADER =>
          next_shift := resize(r.current_shift, r.current_shift'length + 1) + bits_in_block_header(AMOUNT_WIDTH-1 downto 0);
          if bl_valid = '1' then
            -- We can only do something if we know the length of the block header

            bl_longer_than_data_word := false;

            for i in r.skip_counter'low to r.skip_counter'high loop
              if bits_in_block_header(i+AMOUNT_WIDTH) /= r.skip_counter(i) then
                bl_longer_than_data_word := true;
              end if;
            end loop;

            if bl_longer_than_data_word then
              -- If the block header is longer than a data word we have to advance the input stream
              if in_valid = '1' then
                in_ready       <= '1';
                v.skip_counter := r.skip_counter + 1;
                v.hold         := in_data;
              end if;
            else
              if next_shift(next_shift'high) = '1' then
                -- In the case of an overflow in the shift amount register we have to advance the input stream.
                in_ready        <= '1';

                if in_valid = '1' then
                  bl_ready        <= '1';
                  v.skip_counter  := (others => '0');
                  v.current_shift := next_shift(AMOUNT_WIDTH-1 downto 0);
                  v.hold          := in_data;
                  v.state         := DATA;
                end if;
              elsif next_shift(next_shift'high) = '0' then
                bl_ready        <= '1';
                v.skip_counter  := (others => '0');
                v.current_shift := next_shift(AMOUNT_WIDTH-1 downto 0);
                v.state         := DATA;
              end if;
            end if;
          end if;

        when DATA =>
          if fifo_out_valid = '1' then
            if PRIM_WIDTH = 32 then
              current_unpack_count := to_unsigned(count_lut_32(to_integer(unsigned(fifo_out_data))), current_unpack_count'length);
              current_unpack_shift := to_unsigned(shift_lut_32(to_integer(unsigned(fifo_out_data))), current_unpack_shift'length);
            elsif PRIM_WIDTH = 64 then
              current_unpack_count := to_unsigned(count_lut_64(to_integer(unsigned(fifo_out_data))), current_unpack_count'length);
              current_unpack_shift := to_unsigned(shift_lut_64(to_integer(unsigned(fifo_out_data))), current_unpack_shift'length);
            end if;

            next_shift := resize(r.current_shift, r.current_shift'length + 1) + current_unpack_shift;

            -- We can tell the BitUnpacker to shift if in_data is valid or if it won't need bits from in_data (data in holding register is enough)
            if in_valid = '1' or next_shift(next_shift'high) = '0' then
              out_valid <= '1';
              out_count <= std_logic_vector(current_unpack_count);

              if out_ready = '1' then
                v.mb_val_count   := r.mb_val_count + resize(current_unpack_count, r.mb_val_count'length);
                v.page_val_count := r.page_val_count + resize(current_unpack_count, 32);
                v.current_shift  := next_shift(AMOUNT_WIDTH-1 downto 0);

                if next_shift(next_shift'high) = '1' then
                  -- Shifting overflow, advance the input stream
                  in_ready <= '1';

                  if in_valid = '1' then
                    v.hold := in_data;
                  else
                    -- Input stream blocked, invalidate the holding register
                    v.hold_valid := '0';
                  end if;
                end if;

                if v.mb_val_count = to_unsigned(0, v.mb_val_count'length) then
                  -- Full miniblock processed
                  v.mb_count := r.mb_count + 1;
                  fifo_out_ready   <= '1';

                  if v.mb_count = to_unsigned(0, v.mb_count'length) then
                    -- Full block processed
                    v.state := HEADER;
                  end if;
                end if;
              end if;
            end if;
          end if;
  
      end case;
    end if;

    d <= v;
  end process;

  clk_p: process(clk)
  begin
    if rising_edge(clk) then
      if reset = '1' then
        r.state            <= HEADER;
        r.hold_valid       <= '0';
        r.skip_counter     <= (others => '0');
        r.current_shift    <= (others => '0');
        r.page_val_count   <= (others => '0');
        r.mb_count         <= (others => '0');
        r.mb_val_count     <= (others => '0');
      else
        r <= d;
      end if;
    end if;
  end process;

end architecture;