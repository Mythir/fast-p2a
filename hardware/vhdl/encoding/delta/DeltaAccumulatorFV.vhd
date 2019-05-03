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
use work.Utils.all;

entity DeltaAccumulatorFV is
  generic (
    -- Maximum number of unpacked deltas per cycle
    MAX_DELTAS_PER_CYCLE        : natural;

    -- Amount of values in a block
    BLOCK_SIZE                  : natural;

    -- Bit width of a single primitive value
    PRIM_WIDTH                  : natural
  );
  port (
    -- Rising-edge sensitive clock.
    clk                         : in  std_logic;

    -- Active-high synchronous reset.
    reset                       : in  std_logic;

    ctrl_done                   : out std_logic;

    -- Total number of requested values (from host)
    total_num_values            : in  std_logic_vector(31 downto 0);

    -- Number of values in the page (from MetadataInterpreter)
    page_num_values             : in  std_logic_vector(31 downto 0);

    -- Handshake signaling start of new page
    new_page_valid              : in  std_logic;
    new_page_ready              : out std_logic;
    
    -- Data in stream from DeltaAccumulator
    in_valid                    : in  std_logic;
    in_ready                    : out std_logic;
    in_data                     : in  std_logic_vector(MAX_DELTAS_PER_CYCLE*PRIM_WIDTH-1 downto 0);
    in_count                    : in  std_logic_vector(log2floor(MAX_DELTAS_PER_CYCLE) downto 0);

    -- First value stream from DeltaHeaderReader
    fv_valid                    : in  std_logic;
    fv_ready                    : out std_logic;
    fv_data                     : in  std_logic_vector(PRIM_WIDTH-1 downto 0);

    --Data out stream to ValuesBuffer
    out_valid                   : out std_logic;
    out_ready                   : in  std_logic;
    out_last                    : out std_logic;
    out_count                   : out std_logic_vector(log2floor(MAX_DELTAS_PER_CYCLE) downto 0);
    out_data                    : out std_logic_vector(MAX_DELTAS_PER_CYCLE*PRIM_WIDTH-1 downto 0)
  );
end DeltaAccumulatorFV;

architecture behv of DeltaAccumulatorFV is

  type state_t is (REQ_PAGE, REQ_FV, SUMMING, DONE);

  type reg_record is record
    state           : state_t;
    last_value      : unsigned(PRIM_WIDTH-1 downto 0);
    page_val_count  : unsigned(31 downto 0);
    total_val_count : unsigned(31 downto 0);
  end record;

  signal r : reg_record;
  signal d : reg_record;

begin
  
  logic_p: process(r)
    variable v : reg_record;
  begin
    v := r;

    new_page_ready <= '0';
    fv_ready       <= '0';
    in_ready       <= '0';
    out_valid      <= '0';

    ctrl_done <= '0';

    out_count <= in_count;

    case r.state is
      when REQ_PAGE =>
        new_page_ready <= '1';

        if new_page_valid = '1' then
          v.state := REQ_FV;
          v.page_val_count := (others => '0');
        end if;

      when REQ_FV =>
        fv_ready <= '1';

        if fv_valid = '1' then
          v.last_value := unsigned(fv_data);
          v.state := SUMMING;
        end if;

      when SUMMING =>
        in_ready  <= out_ready;
        out_valid <= in_valid;
        -- Todo: continue here Idea: maybe use records for stages and pipeline this so that calculations for out_count and the prefix sum are separated
        if in_valid = '1' and out_ready = '1' then
          v.page_val_count  := r.page_val_count + unsigned(in_count);
          v.total_val_count := r.total_val_count + unsigned(in_count);
        end if;

      when DONE =>
        ctrl_done <= '1';

    end case;

    d <= r;
  end process;

  clk_p: process(clk)
  begin
    if rising_edge(clk) then
      if reset = '1' then
        r.state <= REQ_PAGE;
        r.total_val_count <= (others => '0');
      else
        r <= d;
      end if;
    end if;
  end process;
end architecture;