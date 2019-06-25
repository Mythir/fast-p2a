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

-- This module adds each delta supplied by DeltaAccumulatorMD to produce the final values.
-- Also keeps track of the page value count and total value count and is therefore responsible for the control logic
-- involved with page requests and completion detection.
-- The addition to the value counts and the control logic involved with the resulting value counts are separated in different stages
-- to avoid critical path issues.

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

  type state_t is (REQ_PAGE, REQ_FV, SEND_FV, SUMMING, DONE);

  type int_array is array (MAX_DELTAS_PER_CYCLE-1 downto 0) of signed(PRIM_WIDTH-1 downto 0);

  type reg_record is record
    state           : state_t;
    -- Number of values in page locally stored
    page_num_val    : std_logic_vector(31 downto 0);
    -- Asserted when processing the last page
    last_page       : std_logic;
    -- Register for storing the most recently calculated value in the prefix sum
    last_value      : signed(PRIM_WIDTH-1 downto 0);
    -- Register used for storing how many values to process in this page (also used for storing total_val_count_prev in REQ_PAGE as a small optimization)
    max_values      : unsigned(31 downto 0);
    -- Amount of values processed in this page, updated every cycle.
    page_val_count  : unsigned(31 downto 0);
    -- Total amount of values processed once current page is done
    total_val_count : unsigned(31 downto 0);
  end record;

  constant SLICE_WIDTH : natural := page_num_values'length*2 + in_data'length + in_count'length;

  signal r : reg_record;
  signal d : reg_record;

  signal slice_in_valid     : std_logic;
  signal slice_in_ready     : std_logic;
  signal slice_in_concat    : std_logic_vector(SLICE_WIDTH-1 downto 0);
  
  signal slice_out_valid    : std_logic;
  signal slice_out_ready    : std_logic;
  signal slice_out_concat   : std_logic_vector(SLICE_WIDTH-1 downto 0);
  
  -- Slice input signals split
  signal slice_in_pvc       : std_logic_vector(r.page_val_count'length-1 downto 0);
  signal slice_in_pvc_prev  : std_logic_vector(r.page_val_count'length-1 downto 0);
  signal slice_in_data      : std_logic_vector(in_data'length-1 downto 0);
  signal slice_in_count     : std_logic_vector(in_count'length-1 downto 0);
  
  -- Slice output signals split
  signal slice_out_pvc      : std_logic_vector(r.page_val_count'length-1 downto 0);
  signal slice_out_pvc_prev : std_logic_vector(r.page_val_count'length-1 downto 0);
  signal slice_out_data     : int_array;
  signal slice_out_count    : std_logic_vector(in_count'length-1 downto 0);

  -- out_data as array
  signal out_data_arr       : int_array;

  -- Internal copy of out_count output
  signal s_out_count        : std_logic_vector(out_count'length-1 downto 0);

  -- In the case of a new page the slice needs to be reset
  signal new_page_handshake : std_logic;
  signal slice_reset        : std_logic;

begin
  
  out_count <= s_out_count;

  -------------------------------------------------------------------------------
  -- Slice for separating value count addition from control logic based on result
  -------------------------------------------------------------------------------
  slice_in_concat <= slice_in_pvc & slice_in_pvc_prev & slice_in_data & slice_in_count;

  slice_reset <= reset or new_page_handshake;

  slice: StreamSlice 
    generic map (
      DATA_WIDTH                  => SLICE_WIDTH
    )
    port map (
      clk                         => clk,
      reset                       => slice_reset,
      in_valid                    => slice_in_valid,
      in_ready                    => slice_in_ready,
      in_data                     => slice_in_concat,
      out_valid                   => slice_out_valid,
      out_ready                   => slice_out_ready,
      out_data                    => slice_out_concat
    );

  slice_out_pvc       <= slice_out_concat(SLICE_WIDTH-1 downto r.page_val_count'length+in_data'length+in_count'length);
  slice_out_pvc_prev  <= slice_out_concat(SLICE_WIDTH-r.page_val_count'length-1 downto in_data'length+in_count'length);

  slice_out_deser: for i in 0 to MAX_DELTAS_PER_CYCLE-1 generate
    slice_out_data(i) <= signed(slice_out_concat(PRIM_WIDTH*(i+1)+in_count'length-1 downto PRIM_WIDTH*i+in_count'length));
  end generate slice_out_deser;

  slice_out_count     <= slice_out_concat(in_count'length-1 downto 0);

  slice_in_pvc      <= std_logic_vector(r.page_val_count + unsigned(in_count));
  slice_in_pvc_prev <= std_logic_vector(r.page_val_count);
  slice_in_data     <= in_data;
  slice_in_count    <= in_count;

  -------------------------------------------------------------------------------
  -- Prefix sum
  -------------------------------------------------------------------------------
  out_data_arr(0) <= slice_out_data(0) + r.last_value;

  prefix_sum_gen: for i in 1 to MAX_DELTAS_PER_CYCLE-1 generate
    out_data_arr(i) <= slice_out_data(i) + out_data_arr(i-1);
  end generate prefix_sum_gen;

  -------------------------------------------------------------------------------
  -- Control logic
  -------------------------------------------------------------------------------  

  logic_p: process(r, new_page_valid, fv_valid, in_valid, out_ready, out_data_arr, s_out_count, slice_in_ready, slice_out_count, page_num_values, total_num_values,
                    slice_in_pvc, slice_out_pvc_prev, slice_out_pvc, slice_out_ready, slice_out_valid, slice_in_valid, fv_data)
    variable v : reg_record;
  begin
    v := r;

    new_page_ready <= '0';
    fv_ready       <= '0';
    in_ready       <= '0';
    out_valid      <= '0';
    out_last       <= '0';

    slice_in_valid  <= '0';
    slice_out_ready <= '0';

    new_page_handshake <= '0';
    
    ctrl_done <= '0';

    s_out_count <= slice_out_count;

    for i in 0 to MAX_DELTAS_PER_CYCLE-1 loop
      out_data(PRIM_WIDTH*(i+1)-1 downto PRIM_WIDTH*i) <= std_logic_vector(out_data_arr(i));
    end loop;

    case r.state is
      when REQ_PAGE =>
        -- Handshake a new page with the PreDecBuffer and store relevant page metadata.
        new_page_ready <= '1';

        if new_page_valid = '1' then
          v.state := REQ_FV;
          v.page_val_count := (others => '0');
          v.total_val_count := r.total_val_count + unsigned(page_num_values);

          -- Use the max values register to store the previous value of total_val_count for the next cycle
          v.max_values := r.total_val_count;

          v.page_num_val := page_num_values;

          new_page_handshake <= '1';
        end if;

      when REQ_FV =>
        -- The first value of the page is encoded in the Delta header. In this state the DeltaAccumulator receives that value.
        -- This state is also used to determine the amount of values we are going to read from this page.
        fv_ready <= '1';

        if fv_valid = '1' then
          v.last_value := signed(fv_data);
          v.state := SEND_FV;

          -- Cap max values to read such that we never read more than the total amount of requested values.
          if r.total_val_count >= unsigned(total_num_values) then
            v.last_page  := '1';
            v.max_values := unsigned(total_num_values) - r.max_values;
          else
            v.max_values := unsigned(r.page_num_val);
          end if;
        end if;

      when SEND_FV =>
        -- Transfer the first value to the ArrayWriters before we start decoding.
        out_valid <= '1';

        s_out_count <= std_logic_vector(to_unsigned(1, s_out_count'length));
        out_data(PRIM_WIDTH-1 downto 0) <= std_logic_vector(r.last_value);

        if out_ready = '1' then
          v.state := SUMMING;
          v.page_val_count := r.page_val_count + 1;
        end if;


      when SUMMING =>
        -- First stage: calculate new value counts
        in_ready <= slice_in_ready;
        slice_in_valid <= in_valid;
        
        if slice_in_valid = '1' and slice_in_ready = '1' then
          -- Upon transfer to slice update value counts
          v.page_val_count  := unsigned(slice_in_pvc);
        end if;

        -- Second stage: prefix sum and value count check
        slice_out_ready <= out_ready;
        out_valid <= slice_out_valid;

        if unsigned(slice_out_pvc) >= r.max_values then
          -- out_count is capped to avoid sending more values to the arraywriters than the amount of values in a page
          s_out_count <= std_logic_vector(resize(r.max_values - unsigned(slice_out_pvc_prev), out_count'length));
          if slice_out_ready = '1' and slice_out_valid = '1' then
            if r.last_page = '1' then
              v.state := DONE;
              out_last <= '1';
            else
              v.state := REQ_PAGE;
            end if;
          end  if;
        end if;

        if slice_out_ready = '1' and slice_out_valid = '1' then
          v.last_value := out_data_arr(to_integer(unsigned(s_out_count(log2ceil(out_data_arr'length)-1 downto 0))-1));
        end  if;

      when DONE =>
        ctrl_done <= '1';

        -- Avoid blocking the stream (important in case of string decoding when chars follow the deltas)
        in_ready <= '1';

    end case;

    d <= v;
  end process;

  clk_p: process(clk)
  begin
    if rising_edge(clk) then
      if reset = '1' then
        r.state           <= REQ_PAGE;
        r.total_val_count <= (others => '0');
        r.last_page       <= '0';
      else
        r <= d;
      end if;
    end if;
  end process;
end architecture;