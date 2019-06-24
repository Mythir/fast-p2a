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
use work.Ptoa.all;
use work.Encoding.all;

-- This module reads the block headers and creates 4 different streams that are used by different modules to correctly decode the Delta encoded data.
-- min_delta stream (md)          : Field in block header used by the delta accumulator to calculate the extra deltas from the bit packed positive offsets.
-- bit_width stream (bw)          : Fields in block header used by the BlockShiftControl to determine the correct alignment for the bit unpackers. The 
--                                  BlockShiftControl also passes the bit packing widths to the bit unpackers for unpacking.
-- block_header_length stream (bl): Length of the block header (not a field, determined in the process of reading). Needed by the BlockShiftControl
--                                  because it needs to know how many bytes to skip to reach the bit-packed values.
-- bytes_consumed stream (bc)     : Only strictly needed when decoding strings. In turn passes the length of the block header and the length of the bit packed
--                                  values to the CharBuffer where they are accumulated to the full size of the delta encoded block. This result is used to
--                                  determine the offset in the page to the characters.

entity BlockHeaderReader is
  generic (
    -- Decoder data width
    DEC_DATA_WIDTH              : natural;

    -- Block size in values
    BLOCK_SIZE                  : natural;

    -- Number of miniblocks in a block
    MINIBLOCKS_IN_BLOCK         : natural;

    -- Width for registers/ports concerned with the amount of bytes in a block
    BYTES_IN_BLOCK_WIDTH        : natural := 16;

    -- Depth of advanceable FiFo
    FIFO_DEPTH                  : natural;

    -- Bit width of a single primitive value
    PRIM_WIDTH                  : natural
  );
  port (
    -- Rising-edge sensitive clock.
    clk                         : in  std_logic;

    -- Active-high synchronous reset.
    reset                       : in  std_logic;

    -- Asserted when all block headers have been processed
    page_done                   : out std_logic;

    -- Data in stream from StreamSerializer
    in_valid                    : in  std_logic;
    in_ready                    : out std_logic;
    in_data                     : in  std_logic_vector(DEC_DATA_WIDTH-1 downto 0);

    -- Number of values in the page (from MetadataInterpreter)
    page_num_values             : in  std_logic_vector(31 downto 0);

    -- Minimum delta stream to DeltaAccumulator
    md_valid                    : out std_logic;
    md_ready                    : in  std_logic;
    md_data                     : out std_logic_vector(PRIM_WIDTH-1 downto 0);

    -- Bit width stream to BlockValuesAligner
    bw_valid                    : out std_logic;
    bw_ready                    : in  std_logic;
    bw_data                     : out std_logic_vector(7 downto 0);

    -- Block header length stream to BlockValuesAligner
    bl_valid                    : out std_logic;
    bl_ready                    : in  std_logic;
    bl_data                     : out std_logic_vector(log2floor(max_varint_bytes(PRIM_WIDTH)+MINIBLOCKS_IN_BLOCK) downto 0);

    -- If the BlockValuesAligner is used for DeltaLengthByteArray decoding we need to know
    -- where the boundary between length data and char data is.
    bc_valid                    : out std_logic;
    bc_ready                    : in  std_logic;
    bc_data                     : out std_logic_vector(BYTES_IN_BLOCK_WIDTH-1 downto 0)
  );
end BlockHeaderReader;

architecture behv of BlockHeaderReader is

  type state_t is (IDLE, READING, SKIPPING, BYPASS, DONE);
  type header_state_t is (MIN_DELTA, BIT_WIDTHS);
  type handshake_state_t is (IDLE, VALID);

  type reg_record is record 
    state               : state_t;
    header_state        : header_state_t;
    -- Handshake states for output streams
    bl_handshake_state  : handshake_state_t;
    md_handshake_state  : handshake_state_t;
    bc_handshake_state  : handshake_state_t;
    -- Register for bc_data in the bytes_consumed output stream
    bc_out              : std_logic_vector(BYTES_IN_BLOCK_WIDTH-1 downto 0);
    -- Counts bytes shifted in header_data during READING
    byte_counter        : unsigned(log2floor(DEC_DATA_WIDTH/8) downto 0);
    -- Counts length of block header in bytes
    bl_counter          : unsigned(log2floor(max_varint_bytes(PRIM_WIDTH)+MINIBLOCKS_IN_BLOCK) downto 0);
    -- Keeps track of miniblock bit widths processed
    miniblock_counter   : unsigned(log2floor(MINIBLOCKS_IN_BLOCK) downto 0);
    -- Register first used for accumulating the size in bytes of the packed data, then counted down back to 0 while skipping to the next block header.
    bytes_packed_data   : unsigned(BYTES_IN_BLOCK_WIDTH-1 downto 0);
    -- Register for reading the header_data
    header_data         : std_logic_vector(DEC_DATA_WIDTH-1 downto 0);
    -- Used for checking if there are any more block headers to read
    page_val_counter    : unsigned(31 downto 0);
  end record;

  -- 16 bits is a suitable size for adv_count in the case of the default 128 block_size, 4 miniblocks configuration.
  constant ADV_COUNT_WIDTH      : natural := 16;
  constant VALUES_IN_MINIBLOCK  : natural := BLOCK_SIZE/MINIBLOCKS_IN_BLOCK;

  signal r : reg_record;
  signal d : reg_record;

  signal current_byte           : std_logic_vector(7 downto 0);
  signal current_byte_valid     : std_logic;
  signal start_varint           : std_logic;

  signal varint_zigzag_true     : std_logic_vector(PRIM_WIDTH-1 downto 0);

  signal adv_valid              : std_logic;
  signal adv_ready              : std_logic;
  signal adv_count              : std_logic_vector(ADV_COUNT_WIDTH-1 downto 0);

  signal fifo_out_valid         : std_logic;
  signal fifo_out_ready         : std_logic;
  signal fifo_out_data          : std_logic_vector(DEC_DATA_WIDTH-1 downto 0);

begin
  
  -- Depth 32 should be enough
  in_buffer: AdvanceableFiFo
    generic map(
      DATA_WIDTH              => DEC_DATA_WIDTH,
      ADV_COUNT_WIDTH         => ADV_COUNT_WIDTH,
      DEPTH_LOG2              => 5
    )
    port map(
      clk                     => clk,
      reset                   => reset,
      in_valid                => in_valid,
      in_ready                => in_ready,
      in_data                 => in_data,
      out_valid               => fifo_out_valid,
      out_ready               => fifo_out_ready,
      out_data                => fifo_out_data,
      adv_valid               => adv_valid,
      adv_ready               => adv_ready,
      adv_count               => adv_count
    );

  current_byte <= r.header_data(DEC_DATA_WIDTH-1 downto DEC_DATA_WIDTH-8);
  
  bw_data <= current_byte;
  bl_data <= std_logic_vector(r.bl_counter);
  md_data <= varint_zigzag_true;
  bc_data <= r.bc_out;
  adv_count <= std_logic_vector(resize(r.bytes_packed_data(BYTES_IN_BLOCK_WIDTH-1 downto log2ceil(DEC_DATA_WIDTH/8)), adv_count'length));

  logic_p: process(r, fifo_out_valid, fifo_out_data, current_byte, bw_ready, adv_ready, bl_ready, bc_ready, md_ready, page_num_values)
    variable v : reg_record;
  begin
    v := r;

    fifo_out_ready <= '0';
    current_byte_valid <= '0';
    start_varint <= '0';
    page_done <= '0';

    bw_valid <= '0';
    adv_valid <= '0';

    case r.state is
      when IDLE =>
        -- Make sure previous block header has been fully handled before starting on the next one
        if r.bl_handshake_state = IDLE and r.md_handshake_state = IDLE and r.bc_handshake_state = IDLE then
          fifo_out_ready <= '1';
  
          if fifo_out_valid = '1' then
            v.header_data       := fifo_out_data;
            v.byte_counter      := (others => '0');
            v.bl_counter        := (others => '0');
            v.miniblock_counter := (others => '0');
            v.state             := READING;
            start_varint        <= '1';
          end if;
        end if;

        if r.page_val_counter >= unsigned(page_num_values) then
          v.state := DONE;
        end if;

      when READING =>
        if r.byte_counter = to_unsigned(DEC_DATA_WIDTH/8, r.byte_counter'length) and r.miniblock_counter < MINIBLOCKS_IN_BLOCK then
          -- If all bytes in header_r have been processed and we are still not done, request new data
          fifo_out_ready <= '1';

          if fifo_out_valid = '1' then
            v.header_data := fifo_out_data;
            v.byte_counter := (others => '0');
          end if;

        else
          current_byte_valid <= '1';

          case r.header_state is
            when MIN_DELTA =>
              v.byte_counter := r.byte_counter + 1;
              v.header_data := std_logic_vector(shift_left(unsigned(r.header_data), 8));

              if r.bytes_packed_data > 0 then
                -- Skip useless bytes
                v.bytes_packed_data := r.bytes_packed_data - 1;
                start_varint <= '1';
              elsif current_byte(7) = '1' then
                v.bl_counter   := r.bl_counter + 1;
              else -- current_byte(7) = '0'
                -- After reading the min delta field we know the length of the entire block header and the value of min_delta.
                -- These values can now be streamed out.
                v.bl_handshake_state := VALID;
                v.md_handshake_state := VALID;
                v.bc_handshake_state := VALID;
                -- Total length of Block Header is bytes in min_delta plus one byte for every miniblock in the block
                v.bl_counter         := r.bl_counter + 1 + MINIBLOCKS_IN_BLOCK;
                v.bc_out             := std_logic_vector(resize(v.bl_counter, r.bc_out'length));
                v.header_state       := BIT_WIDTHS;
              end if;

            when BIT_WIDTHS =>
              -- Stream the bytes representing bit widths to the BlockValuesAligner while miniblock_counter < MINIBLOCKS_IN_BLOCK
              -- If all bytes have been read and the char_buffer is ready to receive a new value for bytes_consumed (it should be able
              -- to consume every cycle so this should never be a problem) proceed to SKIPPING.
              if r.miniblock_counter < MINIBLOCKS_IN_BLOCK then
                bw_valid <= '1';
  
                -- Only shift if the BlockValuesAligner handshakes the bit width
                if bw_ready = '1' then
                  v.byte_counter      := r.byte_counter + 1;
                  v.header_data       := std_logic_vector(shift_left(unsigned(r.header_data), 8));
                  v.miniblock_counter := r.miniblock_counter + 1;

                  -- Add to the page val counter for every miniblock processed
                  v.page_val_counter  := r.page_val_counter + VALUES_IN_MINIBLOCK;

                  -- If after previous miniblocks all values in the page have been read, then no more miniblocks will be encoded. No matter what the block header says.
                  if r.page_val_counter < unsigned(page_num_values) then
                    v.bytes_packed_data := r.bytes_packed_data + (unsigned(current_byte) * (VALUES_IN_MINIBLOCK/8));
                  end if;

                  -- Cycle save below does not work because of overwriting v.bytes_packed_data.
                  ---- Save a cycle by checking if we can progress to SKIPPING while streaming out the last byte. 
                  --if r.miniblock_counter = MINIBLOCKS_IN_BLOCK - 1 and r.bc_handshake_state = IDLE then
                  --  v.state              := SKIPPING;
                  --  v.bc_handshake_state := VALID;
                  --  v.bc_out             := std_logic_vector(r.bytes_packed_data);
                  --  -- Compensate bytes_packed_data (which will be used for SKIPPING) for the packed bytes present in the header_data register
                  --  v.bytes_packed_data  := r.bytes_packed_data - DEC_DATA_WIDTH/8 + v.byte_counter;
                  --end if;
                end if;
              else
                if r.bc_handshake_state = IDLE then
                  if r.bytes_packed_data < (DEC_DATA_WIDTH/8 - r.byte_counter) then
                    v.state              := BYPASS;
                  else
                    v.state              := SKIPPING;
  
                    -- Compensate bytes_packed_data (which will be used for SKIPPING) for the packed bytes present in the header_data register
                    v.bytes_packed_data  := r.bytes_packed_data - DEC_DATA_WIDTH/8 + r.byte_counter;
                  end if;

                  -- When decoding strings: tell CharBuffer the size of the packed data
                  v.bc_handshake_state := VALID;
                  v.bc_out             := std_logic_vector(r.bytes_packed_data);
                end if;
              end if;

          end case;

        end if;

      when SKIPPING =>
        adv_valid <= '1';

        if adv_ready = '1' then
          -- Change bytes_packed_data to reflect that a large portion of the packed data has been skipped in the advanceable FiFo.
          v.bytes_packed_data := (others => '0');
          v.bytes_packed_data(log2ceil(DEC_DATA_WIDTH/8)-1 downto 0) := r.bytes_packed_data(log2ceil(DEC_DATA_WIDTH/8)-1 downto 0);
          v.state             := IDLE;
          v.header_state      := MIN_DELTA;
        end if;

      when BYPASS =>
        -- Special state that is used when the bit packed data is very short (in the case of 0 width bit packing for example)
        -- If there is data from the next block header already present in the header_data register we bypass IDLE via this state
        if r.bl_handshake_state = IDLE and r.md_handshake_state = IDLE and r.bc_handshake_state = IDLE then
          v.bl_counter        := (others => '0');
          v.miniblock_counter := (others => '0');
          v.state             := READING;
          start_varint        <= '1';
          v.header_state      := MIN_DELTA;
        end if;

        if r.page_val_counter >= unsigned(page_num_values) then
          v.state := DONE;
        end if;

      when DONE =>
        page_done <= '1';
    end case;

    -----------------------------------------------------------
    -- Handshakes outside of main case
    -----------------------------------------------------------

    case r.bl_handshake_state is
      when IDLE =>
        bl_valid <= '0';

      when VALID =>
        bl_valid <= '1';

        if bl_ready = '1' then
          v.bl_handshake_state := IDLE;
        end if;
    end case;

    case r.bc_handshake_state is
      when IDLE =>
        bc_valid <= '0';

      when VALID =>
        bc_valid <= '1';

        if bc_ready = '1' then
          v.bc_handshake_state := IDLE;
        end if;
    end case;

    case r.md_handshake_state is
      when IDLE =>
        md_valid <= '0';

      when VALID =>
        md_valid <= '1';

        if md_ready = '1' then
          v.md_handshake_state := IDLE;
        end if;
    end case;

    d <= v;
  end process;

  clk_p: process(clk)
  begin
    if rising_edge(clk) then
      if reset= '1' then
        r.state               <= IDLE;
        r.header_state        <= MIN_DELTA;
        r.bl_handshake_state  <= IDLE;
        r.md_handshake_state  <= IDLE;
        r.bc_handshake_state  <= IDLE;
        --r.bc_out              <= (others => 'U');
        --r.byte_counter        <= (others => 'U');
        --r.bl_counter          <= (others => 'U');
        --r.miniblock_counter   <= (others => 'U');
        r.bytes_packed_data   <= (others => '0');
        --r.header_data         <= (others => 'U');
        r.page_val_counter    <= (others => '0');
      else
        r <= d;
      end if;
    end if;
  end process;

  varint_zigzag_t_inst: VarIntDecoder
    generic map (
      INT_BIT_WIDTH => PRIM_WIDTH,
      ZIGZAG_ENCODED => true
    )
    port map (
      clk => clk,
      reset => reset,
      start => start_varint,
      in_data => current_byte,
      in_valid => current_byte_valid,
      out_data => varint_zigzag_true
    );
end architecture;