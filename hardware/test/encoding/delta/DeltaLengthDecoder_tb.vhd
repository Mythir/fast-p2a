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

-- Testbench for DeltaLengthDecoder, adapted from the testbench for the DeltaDecoder. Unlike the DeltaDecoder testbench this testbench can not test multiple pages.
-- Testing for multiple pages will have to be done with the higher level testbench. Because this is a quick and dirty adaptation some code may be left in check_lengths_p
-- that used to deal with a multiple page test and is now useless.

entity DeltaLengthDecoder_tb is
end DeltaLengthDecoder_tb;

architecture tb of DeltaLengthDecoder_tb is

  constant BUS_DATA_WIDTH          : natural := 512;
  constant DEC_DATA_WIDTH          : natural := 64;
  constant INDEX_WIDTH             : natural := 32;
  constant LENGTHS_PER_CYCLE       : natural := 4;
  constant CHARS_PER_CYCLE         : natural := BUS_DATA_WIDTH/8;

  constant VALUES_TO_READ          : natural := 15000;
  constant PAGE_NUMBER_VALUES      : natural := 10000;
  constant BYTES_IN_TESTFILE       : natural := 1000000000;

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
  signal out_valid                 : std_logic_vector(1 downto 0);
  signal out_ready                 : std_logic_vector(1 downto 0);
  signal out_last                  : std_logic_vector(1 downto 0);
  signal out_data                  : std_logic_vector(log2ceil(CHARS_PER_CYCLE+1) + CHARS_PER_CYCLE*8 + log2ceil(LENGTHS_PER_CYCLE+1) + LENGTHS_PER_CYCLE*INDEX_WIDTH - 1 downto 0);

  signal out_length_count          : std_logic_vector(log2ceil(LENGTHS_PER_CYCLE+1)-1 downto 0);
  signal out_length_values         : std_logic_vector(LENGTHS_PER_CYCLE*INDEX_WIDTH-1 downto 0);

  signal out_char_count            : std_logic_vector(log2ceil(CHARS_PER_CYCLE+1) - 1 downto 0);
  signal out_char_values           : std_logic_vector(CHARS_PER_CYCLE*8-1 downto 0);

  -- Keep track of expected amount of chars
  signal total_chars               : integer;

begin
  -- Split out_data into its usable components
  out_length_count  <= out_data(log2ceil(LENGTHS_PER_CYCLE+1) + LENGTHS_PER_CYCLE*INDEX_WIDTH - 1 downto LENGTHS_PER_CYCLE*INDEX_WIDTH);
  out_length_values <= out_data(LENGTHS_PER_CYCLE*INDEX_WIDTH-1 downto 0);
  out_char_count    <= out_data(log2ceil(CHARS_PER_CYCLE+1) + CHARS_PER_CYCLE*8 + log2ceil(LENGTHS_PER_CYCLE+1) + LENGTHS_PER_CYCLE*INDEX_WIDTH - 1 downto CHARS_PER_CYCLE*8 + log2ceil(LENGTHS_PER_CYCLE+1) + LENGTHS_PER_CYCLE*INDEX_WIDTH);
  out_char_values   <= out_data(CHARS_PER_CYCLE*8 + log2ceil(LENGTHS_PER_CYCLE+1) + LENGTHS_PER_CYCLE*INDEX_WIDTH - 1 downto log2ceil(LENGTHS_PER_CYCLE+1) + LENGTHS_PER_CYCLE*INDEX_WIDTH);

  dut: DeltaLengthDecoder
    generic map(
      BUS_DATA_WIDTH              => BUS_DATA_WIDTH,
      DEC_DATA_WIDTH              => DEC_DATA_WIDTH,
      INDEX_WIDTH                 => INDEX_WIDTH,
      CHARS_PER_CYCLE             => CHARS_PER_CYCLE,
      LENGTHS_PER_CYCLE           => LENGTHS_PER_CYCLE,
      RAM_CONFIG                  => ""
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
      out_dvalid                  => open,
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
    page_num_values <= std_logic_vector(to_unsigned(PAGE_NUMBER_VALUES, total_num_values'length));
    -- Bytes_in_testfile should be big to ensure that the corresponding data at least contains the amount of values required by page_num_values
    uncompressed_size <= std_logic_vector(to_unsigned(BYTES_IN_TESTFILE, total_num_values'length));

    loop
      wait until rising_edge(clk);
      exit when reset = '0';
    end loop;
    file_open(input_data, "./test/encoding/delta/dld_tb_in.hex1", read_mode);

      -- Delay for a random amount of clock cycles to simulate a non-continuous stream
    uniform(seed1, seed2, stream_stop);
    if stream_stop < stream_stop_p then
      uniform(seed1, seed2, num_stopped_cycles);
      for i in 0 to integer(floor(num_stopped_cycles*max_stopped_cycles)) loop
        wait until rising_edge(clk);
      end loop;
    end if;
    
    new_page_valid <= '1';

    loop
      wait until rising_edge(clk);
      exit when new_page_ready = '1';
    end loop;

    new_page_valid <= '0';

    while not endfile(input_data) loop
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

    wait;
  end process;

  check_lengths_p: process
    file check_data             : text;

    constant stream_stop_p      : real    := 0.05;
    constant max_stopped_cycles : real    := 10.0;

    variable check_line         : line;
    variable check_value        : std_logic_vector(INDEX_WIDTH-1 downto 0);

    variable seed1              : positive := 137;
    variable seed2              : positive := 442;

    variable stream_stop        : real;
    variable num_stopped_cycles : real;

    variable values_in_page     : natural;
    variable page_val_count     : natural;
    variable total_val_count    : natural := 0;
    variable length_sum         : natural;
  begin
    total_chars  <= 0;
    out_ready(0) <= '0';

    loop
      wait until rising_edge(clk);
      exit when reset = '0';
    end loop;

    loop
      file_open(check_data, "./test/encoding/delta/dld_tb_check_lengths.hex1", read_mode);
      
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

        out_ready(0) <= '1';
  
        loop
          wait until rising_edge(clk);
          exit when out_valid(0) = '1';
        end loop;

        out_ready(0) <= '0';

        length_sum := total_chars;

        for i in 0 to to_integer(unsigned(out_length_count))-1 loop
          -- For each value in out_data, check if it is correctly decoded by using the check file for reference
          readline(check_data, check_line);
          hread(check_line, check_value);

          assert check_value = out_length_values(INDEX_WIDTH*(i+1)-1 downto INDEX_WIDTH*i)
            report "Unpacking and decoding aligned integer resulted in " & integer'image(to_integer(signed(out_length_values(INDEX_WIDTH*(i+1)-1 downto INDEX_WIDTH*i)))) 
              & " instead of the correct value " & integer'image(to_integer(signed(check_value))) 
              & ". Correctly processed values before this out_data: " & integer'image(page_val_count) & ", index in current out_data: " & integer'image(i) severity failure;

          length_sum := length_sum + to_integer(unsigned(check_value));
        end loop;

        total_chars <= length_sum;
        page_val_count  := page_val_count + to_integer(unsigned(out_length_count));
        total_val_count := total_val_count + to_integer(unsigned(out_length_count));

        assert to_integer(unsigned(out_length_count)) > 0
          report "DeltaDecoder outputs data with out_length_count 0" severity failure;

        if total_val_count = VALUES_TO_READ then
          report "All values read" severity note;
        elsif total_val_count >VALUES_TO_READ then
          report "DeltaDecoder outputs too many values" severity failure;
        end if;
      end loop;      
  
      file_close(check_data);
    end loop;

    loop
      wait until rising_edge(clk);
      if out_valid(0) = '1' then
          report "DeltaDecoder out_valid asserted when it should be done" severity failure;
      end if;
    end loop;

    wait;
  end process;

  check_chars_p: process
    file check_data             : text;

    constant stream_stop_p      : real    := 0.05;
    constant max_stopped_cycles : real    := 10.0;

    variable check_line         : line;
    variable check_value        : std_logic_vector(7 downto 0);

    variable seed1              : positive := 137;
    variable seed2              : positive := 442;

    variable stream_stop        : real;
    variable num_stopped_cycles : real;

    variable values_in_page     : natural;
    variable page_val_count     : natural;
  begin
    file_open(check_data, "./test/encoding/delta/dld_tb_check_chars.hex1", read_mode);

    out_ready(1) <= '0';

    loop
      wait until rising_edge(clk);
      exit when reset = '0';
    end loop;

    page_val_count := 0;

    while not endfile(check_data) loop

      -- Delay for a random amount of clock cycles to simulate a non-continuous stream
      uniform(seed1, seed2, stream_stop);
      if stream_stop < stream_stop_p then
        uniform(seed1, seed2, num_stopped_cycles);
        for i in 0 to integer(floor(num_stopped_cycles*max_stopped_cycles)) loop
          wait until rising_edge(clk);
        end loop;
      end if;
      
      out_ready(1) <= '1';
    
      loop
        wait until rising_edge(clk);
        exit when out_valid(1) = '1';
      end loop;
  
      out_ready(1) <= '0';

      for i in 0 to to_integer(unsigned(out_char_count))-1 loop
        -- For each value in out_data, check if it is correctly decoded by using the check file for reference
        readline(check_data, check_line);
        hread(check_line, check_value);

        assert check_value = out_char_values(8*(i+1)-1 downto 8*i)
          report "Unpacking and decoding aligned char resulted in " & integer'image(to_integer(signed(out_char_values(8*(i+1)-1 downto 8*i)))) 
            & " instead of the correct value " & integer'image(to_integer(signed(check_value))) 
            & ". Correctly processed values before this out_data: " & integer'image(page_val_count) & ", index in current out_data: " & integer'image(i) severity failure;
      end loop;

      page_val_count  := page_val_count + to_integer(unsigned(out_char_count));

      assert to_integer(unsigned(out_char_count)) > 0
        report "DeltaLengthDecoder outputs char data with out_char_count 0" severity failure;

      if page_val_count = total_chars then
        report "All char values read" severity note;
      elsif page_val_count > total_chars then
        report "DeltaLengthDecoder outputs too many char values" severity failure;
      end if;
    end loop;

    file_close(check_data);

    loop
      wait until rising_edge(clk);
      if out_valid(1) = '1' then
          report "DeltaLengthDecoder out_valid for chars asserted when it should be done" severity failure;
      end if;
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
