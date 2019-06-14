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

library std;
use std.textio.all;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_textio.all;
use ieee.math_real.all;

library work;
-- Fletcher utils for use of the log2ceil function
use work.UtilInt_pkg.all;
use work.Delta.all;

-- This testbench tests both the decoding and page handling capabilities of the DeltaDecoder.
-- A file should be provided containing the (uncompressed) value data of a page that has been encoded with Delta encoding.
-- Because generating a file with random page sizes using Parquet-MR is not trivial, this testbench emulates this by providing a
-- random page_num_values in its new_page handshake with the decoder, the decoder should then read that amount of values and request a new page.
-- The testbench then closes and re-opens the testfile and pretends it is a new page. This should result in the DeltaDecoder reading 
-- the same sequence of values over and over again until it has reached VALUES_TO_READ (total_num_values).

-- The strategy requires uncompressed_size to be sufficiently high or the DeltaDecoder will block its own input stream.
-- This brings us to the main downside of this testing strategy, the DeltaDecoder will read a full uncompressed_size's worth of data every time because
-- it always wants to see every byte in a page (as determined by uncompressed_size) to avoid prematurely backpressuring the decompressor.

entity DeltaDecoder_tb is
end DeltaDecoder_tb;

architecture tb of DeltaDecoder_tb is

  constant BUS_DATA_WIDTH          : natural := 512;
  constant DEC_DATA_WIDTH          : natural := 64;
  constant PRIM_WIDTH              : natural := 32;
  constant ELEMENTS_PER_CYCLE      : natural := 16;

  constant VALUES_TO_READ          : natural := 30000;
  constant VALUES_IN_TESTFILE      : natural := 10000;
  constant BYTES_IN_TESTFILE       : natural := 25000;

  constant clk_period           : time    := 10 ns;

  signal clk                       : std_logic;
  signal reset                     : std_logic;
  signal ctrl_done                 : std_logic;
  signal in_valid                  : std_logic;
  signal in_ready                  : std_logic;
  signal in_data                   : std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
  signal new_page_valid            : std_logic;
  signal new_page_ready            : std_logic;
  signal total_num_values          : std_logic_vector(31 downto 0);
  signal page_num_values           : std_logic_vector(31 downto 0);
  signal uncompressed_size         : std_logic_vector(31 downto 0);
  signal out_valid                 : std_logic;
  signal out_ready                 : std_logic;
  signal out_last                  : std_logic;
  signal out_dvalid                : std_logic := '1';
  signal out_data                  : std_logic_vector(log2ceil(ELEMENTS_PER_CYCLE+1) + ELEMENTS_PER_CYCLE*PRIM_WIDTH - 1 downto 0);

  signal out_count                 : std_logic_vector(log2ceil(ELEMENTS_PER_CYCLE+1)-1 downto 0);
  signal out_values                : std_logic_vector(ELEMENTS_PER_CYCLE*PRIM_WIDTH-1 downto 0);

begin
  -- Split out_data into its usable components
  out_count <= out_data(log2ceil(ELEMENTS_PER_CYCLE+1) + ELEMENTS_PER_CYCLE*PRIM_WIDTH - 1 downto ELEMENTS_PER_CYCLE*PRIM_WIDTH);
  out_values <= out_data(ELEMENTS_PER_CYCLE*PRIM_WIDTH-1 downto 0);

  dut: DeltaDecoder
    generic map(
      BUS_DATA_WIDTH              => BUS_DATA_WIDTH,
      DEC_DATA_WIDTH              => DEC_DATA_WIDTH,
      PRIM_WIDTH                  => PRIM_WIDTH,
      ELEMENTS_PER_CYCLE          => ELEMENTS_PER_CYCLE
    )
    port map(
      clk                         => clk,
      reset                       => reset,
      ctrl_done                   => ctrl_done,
      in_valid                    => in_valid,
      in_ready                    => in_ready,
      in_data                     => in_data,
      new_page_valid              => new_page_valid,
      new_page_ready              => new_page_ready,
      total_num_values            => total_num_values,
      page_num_values             => page_num_values,
      uncompressed_size           => uncompressed_size,
      out_valid                   => out_valid,
      out_ready                   => out_ready,
      out_last                    => out_last,
      out_dvalid                  => out_dvalid,
      out_data                    => out_data
    );

  data_p: process
    file input_data             : text;

    constant stream_stop_p      : real    := 0.05;
    constant max_stopped_cycles : real    := 10.0;

    variable input_line         : line;
    variable page_data          : std_logic_vector(BUS_DATA_WIDTH-1 downto 0);

    variable seed1              : positive := 137;
    variable seed2              : positive := 442;

    variable stream_stop        : real;
    variable num_stopped_cycles : real;

    variable values_in_page     : real;
  begin
    in_valid <= '0';
    new_page_valid <= '0';

    -- Total num values is capped by a constant
    total_num_values <= std_logic_vector(to_unsigned(VALUES_TO_READ, total_num_values'length));
    page_num_values <= (others => '0');
    -- Bytes_in_testfile should be big to ensure that the corresponding data at least contains the amount of values required by page_num_values
    uncompressed_size <= std_logic_vector(to_unsigned(BYTES_IN_TESTFILE, total_num_values'length));

    loop
      wait until rising_edge(clk);
      exit when reset = '0';
    end loop;

    loop
      file_open(input_data, "./test/encoding/delta/dd_tb_in.hex1", read_mode);

        -- Delay for a random amount of clock cycles to simulate a non-continuous stream
      uniform(seed1, seed2, stream_stop);
      if stream_stop < stream_stop_p then
        uniform(seed1, seed2, num_stopped_cycles);
        for i in 0 to integer(floor(num_stopped_cycles*max_stopped_cycles)) loop
          wait until rising_edge(clk);
        end loop;
      end if;

      -- Randomize number of values in the page
      uniform(seed1, seed2, values_in_page);
      page_num_values <= std_logic_vector(to_unsigned(integer(floor(values_in_page*real(VALUES_IN_TESTFILE))), page_num_values'length));
      new_page_valid <= '1';
  
      loop
        wait until rising_edge(clk);
        exit when new_page_ready = '1';
      end loop;
  
      new_page_valid <= '0';
  
      for i in 0 to integer(ceil(real(BYTES_IN_TESTFILE)/real(BUS_DATA_WIDTH/8)))-1 loop
        readline(input_data, input_line);
        hread(input_line, page_data);
  
        in_valid <= '1';
        in_data <= page_data;
  
        loop 
          wait until rising_edge(clk);
          exit when in_ready = '1';
        end loop;
  
        in_valid <= '0';
  
        -- Delay for a random amount of clock cycles to simulate a non-continuous stream
        uniform(seed1, seed2, stream_stop);
        if stream_stop < stream_stop_p then
          uniform(seed1, seed2, num_stopped_cycles);
          for i in 0 to integer(floor(num_stopped_cycles*max_stopped_cycles)) loop
            wait until rising_edge(clk);
          end loop;
        end if;
      end loop;
  
      file_close(input_data);
    end loop;

    wait;
  end process;

  check_p: process
    file check_data             : text;

    constant stream_stop_p      : real    := 0.05;
    constant max_stopped_cycles : real    := 10.0;

    variable check_line         : line;
    variable check_value        : std_logic_vector(PRIM_WIDTH-1 downto 0);

    variable seed1              : positive := 137;
    variable seed2              : positive := 442;

    variable stream_stop        : real;
    variable num_stopped_cycles : real;

    variable values_in_page     : natural;
    variable page_val_count     : natural;
    variable total_val_count    : natural := 0;
  begin
    out_ready <= '0';

    loop
      wait until rising_edge(clk);
      exit when reset = '0';
    end loop;

    loop
      file_open(check_data, "./test/encoding/delta/dd_tb_check.hex1", read_mode);
      
      -- Wait until a new page is handshaked and store the number of values in the page
      loop
        wait until rising_edge(clk);
        exit when new_page_ready = '1' and new_page_valid = '1';
      end loop;
  
      values_in_page := to_integer(unsigned(page_num_values));
      page_val_count := 0;
  
      while page_val_count < values_in_page loop
        -- Keep iterating through the check file containing correctly decoded values while there are still remaining values in the page

        -- Delay for a random amount of clock cycles to simulate a non-continuous stream
        uniform(seed1, seed2, stream_stop);
        if stream_stop < stream_stop_p then
          uniform(seed1, seed2, num_stopped_cycles);
          for i in 0 to integer(floor(num_stopped_cycles*max_stopped_cycles)) loop
            wait until rising_edge(clk);
          end loop;
        end if;

        out_ready <= '1';
  
        loop
          wait until rising_edge(clk);
          exit when out_valid = '1';
        end loop;

        out_ready <= '0';

        for i in 0 to to_integer(unsigned(out_count))-1 loop
          -- For each value in out_data, check if it is correctly decoded by using the check file for reference
          readline(check_data, check_line);
          hread(check_line, check_value);

          assert check_value = out_data(PRIM_WIDTH*(i+1)-1 downto PRIM_WIDTH*i)
            report "Unpacking and decoding aligned integer resulted in " & integer'image(to_integer(signed(out_data(PRIM_WIDTH*(i+1)-1 downto PRIM_WIDTH*i)))) 
              & " instead of the correct value " & integer'image(to_integer(signed(check_value))) 
              & ". Correctly processed values before this out_data: " & integer'image(page_val_count) & ", index in current out_data: " & integer'image(i) severity failure;
        end loop;

        page_val_count  := page_val_count + to_integer(unsigned(out_count));
        total_val_count := total_val_count + to_integer(unsigned(out_count));

        assert to_integer(unsigned(out_count)) > 0
          report "DeltaDecoder outputs data with out_count 0" severity failure;

        if total_val_count = VALUES_TO_READ then
          report "All values read" severity note;
        elsif total_val_count >VALUES_TO_READ then
          report "DeltaDecoder outputs too many values" severity failure;
        end if;
      end loop;      
  
      file_close(check_data);
    end loop;

    wait;
  end process;

  clk_p : process
  begin
    clk <= '0';
    wait for clk_period/2;
    clk <= '1';
    wait for clk_period/2;
  end process;

  reset_p : process is
  begin
    reset <= '1';
    wait for 20 ns;
    wait until rising_edge(clk);
    reset <= '0';
    wait;
  end process;
end architecture;
