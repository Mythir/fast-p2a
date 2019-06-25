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
use work.Delta.all;
use work.Ptoa.all;

entity DeltaDecoder is
  generic (
    -- Bus data width
    BUS_DATA_WIDTH              : natural;

    -- Decoder data width
    DEC_DATA_WIDTH              : natural := 64;

    -- Bit width of a single primitive value
    PRIM_WIDTH                  : natural;

    -- Max amount of decoded integers produced at out_data per cycle
    -- Too large a value may cause timing issues
    ELEMENTS_PER_CYCLE          : natural;

    RAM_CONFIG                  : string := ""
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

    -- Uncompressed size of page (from MetadataInterpreter)
    uncompressed_size 			    : in  std_logic_vector(31 downto 0);

    --Data out stream to Fletcher ColumnWriter
    out_valid                   : out std_logic;
    out_ready                   : in  std_logic;
    out_last                    : out std_logic;
    out_dvalid                  : out std_logic := '1';
    out_data                    : out std_logic_vector(log2ceil(ELEMENTS_PER_CYCLE+1) + ELEMENTS_PER_CYCLE*PRIM_WIDTH - 1 downto 0)
  );
end DeltaDecoder;

architecture behv of DeltaDecoder is
  
  -- The current design requires these two encoding parameters to be constant.
  constant BLOCK_SIZE           : natural := 128;
  constant MINIBLOCKS_IN_BLOCK  : natural := 4;

  -- Width counters keeping track of the amount of bytes in a block
  constant BYTES_IN_BLOCK_WIDTH : natural := 16;

  constant COUNT_WIDTH          : natural := log2ceil(ELEMENTS_PER_CYCLE+1);
  constant WIDTH_WIDTH          : natural := log2ceil(PRIM_WIDTH+1);

  type state_t is (REQ_PAGE, IN_PAGE);

  type reg_record is record
    state             : state_t;
    page_num_values   : std_logic_vector(31 downto 0);
    uncompressed_size : std_logic_vector(31 downto 0);
    bytes_counted     : std_logic_vector(31 downto 0);
  end record;

  signal r : reg_record;
  signal d : reg_record;

  signal new_page_reset : std_logic;
  signal pipeline_reset : std_logic;

  --------------------------------------------------------------------
  -- Streams
  --------------------------------------------------------------------
  ------------------------------
  -- External
  ------------------------------
  -- Data in to DeltaHeaderReader
  signal dhr_in_valid      : std_logic;
  signal dhr_in_ready      : std_logic;
  signal dhr_in_last       : std_logic;
  
  -- New page handshake to DeltaAccumulator
  signal da_new_page_valid : std_logic;
  signal da_new_page_ready : std_logic;

  -- Data out from DeltaAccumulator to Fletcher ArrayWriter
  signal da_out_valid         : std_logic;
  signal da_out_ready         : std_logic;
  signal da_out_last          : std_logic;
  signal da_out_data          : std_logic_vector(log2ceil(ELEMENTS_PER_CYCLE+1) + ELEMENTS_PER_CYCLE*PRIM_WIDTH - 1 downto 0);

  ------------------------------
  -- From DeltaHeaderReader
  ------------------------------
  -- First value stream to DeltaAccumulator
  signal fv_valid          : std_logic;
  signal fv_ready          : std_logic;
  signal fv_data           : std_logic_vector(PRIM_WIDTH-1 downto 0);

  -- Data DeltaHeaderReader->StreamSerializer
  signal dhr_ss_valid      : std_logic;
  signal dhr_ss_ready      : std_logic;
  signal dhr_ss_data       : std_logic_vector(BUS_DATA_WIDTH-1 downto 0);

  ------------------------------
  -- From StreamSerializer
  ------------------------------
  -- Data StreamSerializer->BlockValuesAligner
  signal ss_bva_valid      : std_logic;
  signal ss_bva_ready      : std_logic;
  signal ss_bva_data       : std_logic_vector(DEC_DATA_WIDTH-1 downto 0);

  ------------------------------
  -- From BlockValuesAligner
  ------------------------------
  -- Minimum delta stream to DeltaAccumulator
  signal md_valid          : std_logic;
  signal md_ready          : std_logic;
  signal md_data           : std_logic_vector(PRIM_WIDTH-1 downto 0);

  -- Bytes consumed stream (unused in this decoder)
  signal bc_valid          : std_logic;
  signal bc_ready          : std_logic;
  signal bc_data           : std_logic_vector(BYTES_IN_BLOCK_WIDTH-1 downto 0);

  -- Data BlockValuesAligner->BitUnpacker
  signal bva_bu_valid      : std_logic;
  signal bva_bu_ready      : std_logic;
  signal bva_bu_data       : std_logic_vector(DEC_DATA_WIDTH-1 downto 0);
  signal bva_bu_count      : std_logic_vector(COUNT_WIDTH-1 downto 0);
  signal bva_bu_width      : std_logic_vector(WIDTH_WIDTH-1 downto 0);

  ------------------------------
  -- From BitUnpacker
  ------------------------------
  -- Data BitUnpacker->DeltaAccumulator
  signal bu_da_valid       : std_logic;
  signal bu_da_ready       : std_logic;
  signal bu_da_count       : std_logic_vector(COUNT_WIDTH-1 downto 0);
  signal bu_da_data        : std_logic_vector(ELEMENTS_PER_CYCLE*PRIM_WIDTH-1 downto 0);

begin
  
  pipeline_reset <= reset or new_page_reset;

  -- Bytes consumed stream is only important when decoding strings.
  bc_ready <= '1';

  input_p: process(r, in_valid, da_new_page_valid, dhr_in_valid, da_new_page_ready, new_page_valid, page_num_values, uncompressed_size, dhr_in_ready)
    variable v : reg_record;
  begin
    v := r;

    new_page_reset <= '0';

    dhr_in_last    <= '0';

    case r.state is
      when REQ_PAGE =>
        -- Wait for new page handshake. When a new page is handshaked, set all registers to the new metadata values and reset where needed.
        new_page_ready    <= da_new_page_ready;
        da_new_page_valid <= new_page_valid;

        in_ready     <= '0';
        dhr_in_valid <= '0';
  
        if da_new_page_valid = '1' and da_new_page_ready = '1' then
          v.page_num_values   := page_num_values;
          v.uncompressed_size := uncompressed_size;
          v.bytes_counted     := (others => '0');
          v.state             := IN_PAGE;
          new_page_reset      <= '1';
        end if;

      when IN_PAGE =>
        -- Connect input of DeltaHeaderReader with input of DeltaDecoder and count bytes transferred until a full page has been transferred.
        new_page_ready    <= '0';
        da_new_page_valid <= '0';

        in_ready     <= dhr_in_ready;
        dhr_in_valid <= in_valid;

        if dhr_in_valid = '1' and dhr_in_ready = '1' then
          v.bytes_counted := std_logic_vector(unsigned(r.bytes_counted) + BUS_DATA_WIDTH/8);
        end if;

        if unsigned(v.bytes_counted) >= unsigned(r.uncompressed_size) then
          v.state := REQ_PAGE;
          dhr_in_last <= '1';
        end if;
      end case;

    d <= v;
  end process;

  dhr_inst: DeltaHeaderReader
    generic map(
      BUS_DATA_WIDTH             => BUS_DATA_WIDTH,
      NUM_SHIFT_STAGES           => 3,
      BLOCK_SIZE                 => BLOCK_SIZE,
      MINIBLOCKS_IN_BLOCK        => MINIBLOCKS_IN_BLOCK,
      PRIM_WIDTH                 => PRIM_WIDTH
    )
    port map(
      clk                        => clk,
      reset                      => pipeline_reset,
      in_valid                   => dhr_in_valid,
      in_ready                   => dhr_in_ready,
      in_last                    => dhr_in_last,
      in_data                    => in_data,
      fv_valid                   => fv_valid,
      fv_ready                   => fv_ready,
      first_value                => fv_data,
      out_valid                  => dhr_ss_valid,
      out_ready                  => dhr_ss_ready,
      out_data                   => dhr_ss_data
    );

  ss_inst: StreamGearboxSerializer
    generic map(
      ELEMENT_WIDTH                => DEC_DATA_WIDTH,
      IN_COUNT_MAX              => BUS_DATA_WIDTH/DEC_DATA_WIDTH,
      IN_COUNT_WIDTH            => log2ceil(BUS_DATA_WIDTH/DEC_DATA_WIDTH)
    )
    port map(
      clk                       => clk,
      reset                     => pipeline_reset,
      in_valid                  => dhr_ss_valid,
      in_ready                  => dhr_ss_ready,
      in_data                   => element_swap(dhr_ss_data, DEC_DATA_WIDTH),
      out_valid                 => ss_bva_valid,
      out_ready                 => ss_bva_ready,
      out_data                  => ss_bva_data
    );


  bva_inst: BlockValuesAligner
    generic map(
      DEC_DATA_WIDTH              => DEC_DATA_WIDTH,
      BLOCK_SIZE                  => BLOCK_SIZE,
      MINIBLOCKS_IN_BLOCK         => MINIBLOCKS_IN_BLOCK,
      MAX_DELTAS_PER_CYCLE        => ELEMENTS_PER_CYCLE,
      BYTES_IN_BLOCK_WIDTH        => BYTES_IN_BLOCK_WIDTH,
      PRIM_WIDTH                  => PRIM_WIDTH,
      RAM_CONFIG                  => RAM_CONFIG
    )
    port map(
      clk                         => clk,
      reset                       => pipeline_reset,
      in_valid                    => ss_bva_valid,
      in_ready                    => ss_bva_ready,
      in_data                     => ss_bva_data,
      page_num_values             => r.page_num_values,
      md_valid                    => md_valid,
      md_ready                    => md_ready,
      md_data                     => md_data,
      bc_valid                    => bc_valid,
      bc_ready                    => bc_ready,
      bc_data                     => bc_data,
      out_valid                   => bva_bu_valid,
      out_ready                   => bva_bu_ready,
      out_data                    => bva_bu_data,
      out_count                   => bva_bu_count,
      out_width                   => bva_bu_width
    );

  bu_inst: BitUnpacker
    generic map(
      DEC_DATA_WIDTH              => DEC_DATA_WIDTH,
      MAX_DELTAS_PER_CYCLE        => ELEMENTS_PER_CYCLE,
      PRIM_WIDTH                  => PRIM_WIDTH
    )
    port map(
      clk                         => clk,
      reset                       => pipeline_reset,
      in_valid                    => bva_bu_valid,
      in_ready                    => bva_bu_ready,
      in_data                     => bva_bu_data,
      in_count                    => bva_bu_count,
      in_width                    => bva_bu_width,
      out_valid                   => bu_da_valid,
      out_ready                   => bu_da_ready,
      out_count                   => bu_da_count,
      out_data                    => bu_da_data
    );

  da_inst: DeltaAccumulator
    generic map(
      MAX_DELTAS_PER_CYCLE        => ELEMENTS_PER_CYCLE,
      BLOCK_SIZE                  => BLOCK_SIZE,
      MINIBLOCKS_IN_BLOCK         => MINIBLOCKS_IN_BLOCK,
      PRIM_WIDTH                  => PRIM_WIDTH
    )
    port map(
      clk                         => clk,
      reset                       => reset,
      total_num_values            => total_num_values,
      page_num_values             => page_num_values,
      new_page_valid              => da_new_page_valid,
      new_page_ready              => da_new_page_ready,
      in_valid                    => bu_da_valid,
      in_ready                    => bu_da_ready,
      in_data                     => bu_da_data,
      in_count                    => bu_da_count,
      fv_valid                    => fv_valid,
      fv_ready                    => fv_ready,
      fv_data                     => fv_data,
      md_valid                    => md_valid,
      md_ready                    => md_ready,
      md_data                     => md_data,
      out_valid                   => da_out_valid,
      out_ready                   => da_out_ready,
      out_last                    => da_out_last,
      out_count                   => da_out_data(COUNT_WIDTH + ELEMENTS_PER_CYCLE*PRIM_WIDTH - 1 downto ELEMENTS_PER_CYCLE*PRIM_WIDTH),
      out_data                    => da_out_data(ELEMENTS_PER_CYCLE*PRIM_WIDTH-1 downto 0)
    );

  out_valid    <= da_out_valid;
  da_out_ready <= out_ready;
  out_last     <= da_out_last;
  out_data     <= da_out_data;

  clk_p: process(clk)
  begin
    if rising_edge(clk) then
      if reset = '1' then
        r.state <= REQ_PAGE;
      else
        r <= d;
      end if;
    end if;
  end process;

end architecture;