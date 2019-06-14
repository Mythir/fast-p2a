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
-- Fletcher streams library for use of the pipelined barrel shifter
use work.Stream_pkg.all;

-- The ShifterRecombiner can shift and recombine its input words with an arbitrary amount of bits. For this it uses the PipelineBarrelShifter from the Fletcher streams library.
-- To be used when unaligned data crosses bus word boundaries as seen in this example:
--                  INPUT                                 ->                                OUTPUT
-- -----------------------------------------              ->              -----------------------------------------
-- -    X      |             bw1           -              ->              -                  bw1                  -
-- -----------------------------------------              ->              -----------------------------------------
-- -----------------------------------------              ->              -----------------------------------------
-- -     bw1   |             bw2           -              ->              -                  bw2                  -
-- -----------------------------------------              ->              -----------------------------------------
-- -----------------------------------------              ->              -----------------------------------------
-- -     bw2   |             bw3           -              ->              -                  bw3                  -
-- -----------------------------------------              ->              -----------------------------------------
-- -----------------------------------------              ->              
-- -     bw3   |              X            -              ->              
-- -----------------------------------------              ->              

entity ShifterRecombiner is
  generic (
    -- Bus data width
    BUS_DATA_WIDTH              : natural := 512;

    -- Width of shifting amount input (alignment)
    SHIFT_WIDTH                 : natural := 6;

    -- Width of elements to shift. (A byte for the ptoa use case).
    ELEMENT_WIDTH               : natural := 8;

    -- Number of stages in the barrel shifter pipeline
    NUM_SHIFT_STAGES            : natural := 6
  );
  port (

    -- Rising-edge sensitive clock.
    clk                         : in  std_logic;

    -- Active-high synchronous reset.
    reset                       : in  std_logic;
    clear                       : in  std_logic;

    -- Stream data in
    in_valid                    : in  std_logic;
    in_ready                    : out std_logic;
    in_data                     : in  std_logic_vector(BUS_DATA_WIDTH-1 downto 0);

    -- Stream data out
    out_valid                   : out std_logic;
    out_ready                   : in  std_logic;
    out_data                    : out std_logic_vector(BUS_DATA_WIDTH-1 downto 0);

    alignment                   : in  std_logic_vector(SHIFT_WIDTH-1 downto 0)
  );
end ShifterRecombiner;

architecture behv of ShifterRecombiner is
  
  signal reset_pipeline               : std_logic;

  signal s_pipe_delete                : std_logic;
  signal s_pipe_valid                 : std_logic_vector(0 to NUM_SHIFT_STAGES);
  signal s_pipe_input                 : std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
  signal s_pipe_output                : std_logic_vector(BUS_DATA_WIDTH-1 downto 0);

  signal shifter_out_valid            : std_logic;
  signal shifter_out_data             : std_logic_vector(BUS_DATA_WIDTH-1 downto 0);

  signal recombiner_r_in_ready        : std_logic;
  signal recombiner_r_out_data        : std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
  signal recombiner_r_out_valid       : std_logic;

  -- Signal copy of out_valid output
  signal s_out_valid                  : std_logic;

begin
  
  -- Pipeline can be flushed/cleared by both the hardware reset or the clear signal
  reset_pipeline <= reset or clear;

  -- Unnecessary signal
  s_pipe_delete <= '0';

  -- Data presented at the output is a combination of the shifter output and the recombiner register.
  -- In other words: a new (aligned) bus word is created from parts of two input bus words.
  -- out_data <= recombiner_r_out_data when alignment = std_logic_vector(to_unsigned(0, SHIFT_WIDTH)) else
  --             recombiner_r_out_data(BUS_DATA_WIDTH-1 downto ELEMENT_WIDTH*to_integer(unsigned(alignment))) & shifter_out_data(ELEMENT_WIDTH*to_integer(unsigned(alignment))-1 downto 0);
              
  out_data_p: process(alignment, recombiner_r_out_data, shifter_out_data)
  begin
    out_data <= recombiner_r_out_data;
    for i in 1 to BUS_DATA_WIDTH/8-1 loop
      if i = to_integer(unsigned(alignment)) then
        out_data <= recombiner_r_out_data(BUS_DATA_WIDTH-1 downto ELEMENT_WIDTH*i) & shifter_out_data(ELEMENT_WIDTH*i-1 downto 0);
      end if;
    end loop;
  end process;

  shifter_ctrl_inst: StreamPipelineControl
    generic map (
      IN_DATA_WIDTH             => BUS_DATA_WIDTH,
      OUT_DATA_WIDTH            => BUS_DATA_WIDTH,
      NUM_PIPE_REGS             => NUM_SHIFT_STAGES,
      INPUT_SLICE               => false, -- Todo: Maybe supposed to be true?
      RAM_CONFIG                => ""
    )
    port map (
      clk                       => clk,
      reset                     => reset_pipeline,
      in_valid                  => in_valid,
      in_ready                  => in_ready,
      in_data                   => in_data,
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
      ELEMENT_WIDTH             => ELEMENT_WIDTH,
      ELEMENT_COUNT             => BUS_DATA_WIDTH/ELEMENT_WIDTH,
      AMOUNT_WIDTH              => SHIFT_WIDTH,
      DIRECTION                 => "left",
      OPERATION                 => "rotate",
      NUM_STAGES                => NUM_SHIFT_STAGES
    )
    port map (
      clk                       => clk,
      reset                     => reset_pipeline,
      in_data                   => s_pipe_input,
      in_amount                 => alignment,
      out_data                  => s_pipe_output
    );

  -- Recombiner_r is ready to receive data when downstream can consume its stored data or when no stored data is present (recombiner_r_out_valid = '0')
  recombiner_r_in_ready <= out_ready or not recombiner_r_out_valid;

  -- The output of the entire entity is only valid when both the shifter and the recombiner register have valid data. Unless alignment is 0, in which case no recombining is needed.
  s_out_valid <= recombiner_r_out_valid when alignment = std_logic_vector(to_unsigned(0, SHIFT_WIDTH)) else
                 recombiner_r_out_valid and shifter_out_valid;
  out_valid <= s_out_valid;

  reg_p: process (clk)
  begin
    if rising_edge(clk) then
      -- Both the shifter and the recombiner register have valid data on their output, and downstream is ready to consume
      if s_out_valid = '1' and out_ready = '1' then
        recombiner_r_out_valid <= '0';
      end if;

      -- Recombiner register can receive data
      if recombiner_r_in_ready = '1' and shifter_out_valid = '1' then
        recombiner_r_out_data <= shifter_out_data;
        recombiner_r_out_valid <= '1';
      end if;

      if reset_pipeline = '1' then
        recombiner_r_out_data <= (others => '0');
        recombiner_r_out_valid <= '0';
      end if;
    end if;
  end process;

end architecture;