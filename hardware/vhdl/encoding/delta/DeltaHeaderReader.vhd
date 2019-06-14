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
use ieee.math_real.all;

library work;
-- Fletcher utils for use of log2ceil function.
use work.UtilInt_pkg.all;
use work.Stream_pkg.all;
use work.Encoding.all;

-- This module reads the values in the Delta header and aligns the data to the first block header.

entity DeltaHeaderReader is
  generic (
    -- Bus data width
    BUS_DATA_WIDTH              : natural;

    -- Number of stages in the shifter
    NUM_SHIFT_STAGES            : natural;

    -- Block size in values
    BLOCK_SIZE                  : natural := 128;

    -- Number of miniblocks in a block
    MINIBLOCKS_IN_BLOCK         : natural := 4;

    -- Bit width of a single primitive value
    PRIM_WIDTH                  : natural
  );
  port (
    -- Rising-edge sensitive clock.
    clk                         : in  std_logic;

    -- Active-high synchronous reset.
    reset                       : in  std_logic;

    -- Data in stream from decompressor
    in_valid                    : in  std_logic;
    in_ready                    : out std_logic;
    in_last                     : in  std_logic;
    in_data                     : in  std_logic_vector(BUS_DATA_WIDTH-1 downto 0);

    --------------------------------------------------------------------------------
    -- Read values in Delta header.
    -- The commented values are either not necessary or not supported in this design
    --------------------------------------------------------------------------------

    -- First value stream to DeltaAccumulator
    fv_valid                    : out std_logic;
    fv_ready                    : in  std_logic;
    first_value                 : out std_logic_vector(PRIM_WIDTH-1 downto 0);

    --block_size                : out std_logic_vector(31 downto 0);
    --miniblocks_in_block       : out std_logic_vector(31 downto 0);
    --total_value_count         : out std_logic_vector(31 downto 0);

    --Data out stream to StreamSerializer
    out_valid                   : out std_logic;
    out_ready                   : in  std_logic;
    out_last                    : out std_logic;
    out_data                    : out std_logic_vector(BUS_DATA_WIDTH-1 downto 0)
  );
end DeltaHeaderReader;

architecture behv of DeltaHeaderReader is

  -- Used to skip the (for now presumed constant) block_size and num_miniblocks fields in header
  constant BLOCK_SIZE_MAX_WIDTH       : natural := natural(CEIL(real(log2floor(BLOCK_SIZE)+1)/real(7)));
  constant NUM_MINIBLOCKS_MAX_WIDTH   : natural := natural(CEIL(real(log2floor(MINIBLOCKS_IN_BLOCK)+1)/real(7)));
  -- Max width of varint in bytes
  constant TOT_VAL_COUNT_MAX_WIDTH    : natural := 5;
  -- Max width of varint in bytes
  constant FIRST_VALUE_MAX_WIDTH      : natural := natural(CEIL(real(PRIM_WIDTH)/real(7)));
  -- Max width of delta header in bytes
  constant DELTA_HEADER_MAX_WIDTH     : natural := BLOCK_SIZE_MAX_WIDTH + NUM_MINIBLOCKS_MAX_WIDTH + TOT_VAL_COUNT_MAX_WIDTH + FIRST_VALUE_MAX_WIDTH;

  type state_t is (IDLE, READING, SHIFTING);
  type header_state_t is (BLOCK_SIZE_FIELD, NUM_MINIBLOCKS_FIELD, TOT_VAL_COUNT_FIELD, FIRST_VALUE_FIELD);
  type handshake_state_t is (IDLE, VALID);

  type reg_record is record 
    state             : state_t;
    header_state      : header_state_t;
    handshake_state   : handshake_state_t;
    byte_counter      : unsigned(log2floor(BUS_DATA_WIDTH/8) downto 0);
    header_data       : std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
  end record;

  signal r : reg_record;
  signal d : reg_record;

  signal shifter_in_valid             : std_logic;
  signal shifter_in_ready             : std_logic;
  -- 1 bit for last signal plus bus_data_width bits for data
  signal shifter_in_data              : std_logic_vector(BUS_DATA_WIDTH downto 0);
  signal shifter_out_valid            : std_logic;
  -- 1 bit for last signal plus bus_data_width bits for data
  signal shifter_out_data             : std_logic_vector(BUS_DATA_WIDTH downto 0);

  signal recombiner_r_in_ready        : std_logic;
  signal recombiner_r_out_data        : std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
  signal recombiner_r_out_valid       : std_logic;
  signal recombiner_r_out_last        : std_logic;

  -- Signal copy of out_valid output
  signal s_out_valid                  : std_logic;

  signal s_pipe_delete                : std_logic;
  signal s_pipe_valid                 : std_logic_vector(0 to NUM_SHIFT_STAGES);

  -- 1 bit for last signal plus bus_data_width bits for data
  signal s_pipe_input                 : std_logic_vector(BUS_DATA_WIDTH downto 0);
  signal s_pipe_output                : std_logic_vector(BUS_DATA_WIDTH downto 0);

  signal start_varint                 : std_logic;
  signal current_byte_valid           : std_logic;
  signal current_byte                 : std_logic_vector(7 downto 0);

begin

  -- Unnecessary signal
  s_pipe_delete <= '0';

  -- Currently inspected byte of the header_data register
  current_byte <= r.header_data(BUS_DATA_WIDTH-1 downto BUS_DATA_WIDTH-8);

  shifter_in_data <= in_last & in_data;

  out_last <= recombiner_r_out_last;

  logic_p: process(in_valid, in_data, r, current_byte, fv_ready, shifter_in_ready)
    variable v : reg_record;
  begin
    v := r;
    in_ready <= '0';

    start_varint <= '0';
    current_byte_valid <= '0';

    shifter_in_valid <= '0';

    case r.state is
      when IDLE =>
        -- Copy (!) from input
        if in_valid = '1' then
          v.header_data := in_data;
          v.byte_counter := (others => '0');
          v.state := READING;
        end if;

      when READING =>
        if r.byte_counter = to_unsigned(BUS_DATA_WIDTH/8, r.byte_counter'length) then
          -- If all bytes in header_r have been processed and we are still not done, request new data
          in_ready <= '1';

          if in_valid = '1' then
            v.state := IDLE;
          end if;

        else
          current_byte_valid <= '1';

          v.byte_counter := r.byte_counter + 1;
  
          -- Shift the metadata register with one byte to the left every clock cycle.
          v.header_data := std_logic_vector(shift_left(unsigned(r.header_data), 8));

          case r.header_state is
            when BLOCK_SIZE_FIELD =>
              if current_byte(7) = '0' then
                v.header_state := NUM_MINIBLOCKS_FIELD;
              end if;

            when NUM_MINIBLOCKS_FIELD =>
              if current_byte(7) = '0' then
                v.header_state := TOT_VAL_COUNT_FIELD;
              end if;

            when TOT_VAL_COUNT_FIELD =>
              if current_byte(7) = '0' then
                v.header_state := FIRST_VALUE_FIELD;
                start_varint <= '1';
              end if;

            when FIRST_VALUE_FIELD =>
              if current_byte(7) = '0' then
                v.header_state := BLOCK_SIZE_FIELD;
                v.state := SHIFTING;
                v.handshake_state := VALID;
              end if;

          end case;

        end if;

      when SHIFTING =>
        shifter_in_valid <= in_valid;
        in_ready <= shifter_in_ready;
  
    end case;

    case r.handshake_state is
      when IDLE =>
        fv_valid <= '0';

      when VALID =>
        fv_valid <= '1';

        if fv_ready = '1' then
          v.handshake_state := IDLE;
        end if;
    end case;

    d <= v;
  end process;

  out_data_p: process(r, recombiner_r_out_data, shifter_out_data)
  begin
    out_data <= recombiner_r_out_data;
    for i in 1 to BUS_DATA_WIDTH/8-1 loop
      if i = to_integer(r.byte_counter) then
        out_data <= recombiner_r_out_data(BUS_DATA_WIDTH-1 downto 8*i) & shifter_out_data(8*i-1 downto 0);
      end if;
    end loop;
  end process;

  -- Recombiner_r is ready to receive data when downstream can consume its stored data or when no stored data is present (recombiner_r_out_valid = '0')
  recombiner_r_in_ready <= out_ready or not recombiner_r_out_valid;

  -- The output of the entire entity is only valid when both the shifter and the recombiner register have valid data. Unless alignment is 0, in which case no recombining is needed.
  s_out_valid <= recombiner_r_out_valid when r.byte_counter = to_unsigned(0, r.byte_counter'length) else
                 (recombiner_r_out_valid and shifter_out_valid) or (recombiner_r_out_valid and recombiner_r_out_last);
  out_valid <= s_out_valid;

  shifter_ctrl_inst: StreamPipelineControl
    generic map (
      IN_DATA_WIDTH             => 1+BUS_DATA_WIDTH,
      OUT_DATA_WIDTH            => 1+BUS_DATA_WIDTH,
      NUM_PIPE_REGS             => NUM_SHIFT_STAGES,
      INPUT_SLICE               => false,
      RAM_CONFIG                => ""
    )
    port map (
      clk                       => clk,
      reset                     => reset,
      in_valid                  => shifter_in_valid,
      in_ready                  => shifter_in_ready,
      in_data                   => shifter_in_data,
      out_valid                 => shifter_out_valid,
      out_ready                 => recombiner_r_in_ready,
      out_data                  => shifter_out_data,
      pipe_delete               => s_pipe_delete,
      pipe_valid                => s_pipe_valid,
      pipe_input                => s_pipe_input,
      pipe_output               => s_pipe_output
    );

  shifter_barrel_inst: StreamPipelineBarrel
    generic map (
      ELEMENT_WIDTH             => 8,
      ELEMENT_COUNT             => BUS_DATA_WIDTH/8,
      AMOUNT_WIDTH              => log2floor(DELTA_HEADER_MAX_WIDTH)+1,
      DIRECTION                 => "left",
      OPERATION                 => "rotate",
      NUM_STAGES                => NUM_SHIFT_STAGES
    )
    port map (
      clk                       => clk,
      reset                     => reset,
      in_data                   => s_pipe_input(BUS_DATA_WIDTH-1 downto 0),
      in_ctrl(0)                => s_pipe_input(BUS_DATA_WIDTH),
      in_amount                 => std_logic_vector(r.byte_counter(log2floor(DELTA_HEADER_MAX_WIDTH) downto 0)),
      out_data                  => s_pipe_output(BUS_DATA_WIDTH-1 downto 0),
      out_ctrl(0)               => s_pipe_output(BUS_DATA_WIDTH)
    );

  varint_first_value_inst: VarIntDecoder
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
      out_data => first_value
    );

  clk_p: process(clk)
  begin
    if rising_edge(clk) then
      -- Both the shifter and the recombiner register have valid data on their output, and downstream is ready to consume
      if s_out_valid = '1' and out_ready = '1' then
        recombiner_r_out_valid <= '0';
      end if;

      -- Recombiner register can receive data
      if recombiner_r_in_ready = '1' and shifter_out_valid = '1' then
        recombiner_r_out_data  <= shifter_out_data(BUS_DATA_WIDTH-1 downto 0);
        recombiner_r_out_valid <= '1';
        recombiner_r_out_last  <= shifter_out_data(BUS_DATA_WIDTH);
      end if;

      if reset = '1' then
        r.state <= IDLE;
        r.handshake_state <= IDLE;
        r.header_state <= BLOCK_SIZE_FIELD;
        recombiner_r_out_valid <= '0';
      else
         r <= d;
      end if;
    end if; 
  end process;

end architecture;