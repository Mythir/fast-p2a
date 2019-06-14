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
use work.Stream_pkg.all;

entity BitUnpackerShifter is
  generic (
    -- Identifier that determines which of the bit-packed values in the input it needs to unpack
    ID                          : natural;

    -- Decoder data width
    DEC_DATA_WIDTH              : natural;

    -- Maximum number of unpacked deltas per cycle
    MAX_DELTAS_PER_CYCLE        : natural;

    -- Width of bit packing width input
    WIDTH_WIDTH                 : natural;

    -- Width of an integer primitive
    PRIM_WIDTH                  : natural;

    -- Number of stages in the shifter
    NUM_SHIFT_STAGES            : natural;
    
    RAM_CONFIG                  : string := ""
  );
  port (
    -- Rising-edge sensitive clock.
    clk                         : in  std_logic;

    -- Active-high synchronous reset.
    reset                       : in  std_logic;

    -- Data in stream
    in_valid                    : in  std_logic;
    in_ready                    : out std_logic;
    in_data                     : in  std_logic_vector(DEC_DATA_WIDTH-1 downto 0);
    in_width                    : in  std_logic_vector(WIDTH_WIDTH-1 downto 0);

    --Data out stream
    out_valid                   : out std_logic;
    out_ready                   : in  std_logic;
    out_data                    : out std_logic_vector(PRIM_WIDTH-1 downto 0)
  );
end BitUnpackerShifter;

architecture behv of BitUnpackerShifter is
  -- Width of shift amount input of the shifters
  constant SHIFT_AMOUNT_WIDTH   : natural := log2ceil(DEC_DATA_WIDTH);

  constant SHIFTER_CTRL_WIDTH   : natural := 0;
  constant SHIFTER_DATA_WIDTH   : natural := DEC_DATA_WIDTH;
  constant SHIFTER_INPUT_WIDTH  : natural := SHIFT_AMOUNT_WIDTH + SHIFTER_CTRL_WIDTH + SHIFTER_DATA_WIDTH;
  constant SHIFTER_OUTPUT_WIDTH : natural := SHIFTER_CTRL_WIDTH + SHIFTER_DATA_WIDTH;

  -- Stream in to shifter
  signal shifter_in_valid       : std_logic;
  signal shifter_in_ready       : std_logic;
  signal shifter_in_data        : std_logic_vector(SHIFTER_INPUT_WIDTH-1 downto 0);

  signal in_amount              : std_logic_vector(SHIFT_AMOUNT_WIDTH-1 downto 0);

  -- Stream out from shifter
  signal shifter_out_valid      : std_logic;
  signal shifter_out_ready      : std_logic;
  signal shifter_out_data       : std_logic_vector(SHIFTER_OUTPUT_WIDTH-1 downto 0);

  signal s_pipe_input           : std_logic_vector(SHIFTER_INPUT_WIDTH-1 downto 0);
  signal s_pipe_output          : std_logic_vector(SHIFTER_OUTPUT_WIDTH-1 downto 0);
begin
  
  -- ID equals the index of the value we are unpacking. Therefore we shift by width*ID to the right.
  in_amount <= std_logic_vector(resize(unsigned(in_width)*ID, in_amount'length));

  shifter_in_valid <= in_valid;
  in_ready         <= shifter_in_ready;
  shifter_in_data  <= in_amount & in_data;

  out_valid         <= shifter_out_valid;
  shifter_out_ready <= out_ready;
  out_data          <= shifter_out_data(PRIM_WIDTH-1 downto 0);

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
      reset                     => reset,
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
      ELEMENT_WIDTH             => 1,
      ELEMENT_COUNT             => SHIFTER_DATA_WIDTH,
      AMOUNT_WIDTH              => SHIFT_AMOUNT_WIDTH,
      DIRECTION                 => "right",
      OPERATION                 => "shift",
      NUM_STAGES                => NUM_SHIFT_STAGES,
      CTRL_WIDTH                => SHIFTER_CTRL_WIDTH
    )
    port map (
      clk                       => clk,
      reset                     => reset,
      in_data                   => s_pipe_input(SHIFTER_DATA_WIDTH-1 downto 0),
      in_amount                 => s_pipe_input(SHIFTER_INPUT_WIDTH-1 downto SHIFTER_CTRL_WIDTH+SHIFTER_DATA_WIDTH),
      out_data                  => s_pipe_output(SHIFTER_DATA_WIDTH-1 downto 0)
    );

end architecture;