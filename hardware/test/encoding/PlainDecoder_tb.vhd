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

entity PlainDecoder_tb is
end PlainDecoder_tb;

architecture tb of PlainDecoder_tb is
  constant BUS_DATA_WIDTH       : natural := 512;
  constant PRIM_WIDTH           : natural := 64;
  constant TOTAL_NUM_VALUES     : natural := 15573;
  constant ELEMENTS_PER_CYCLE   : natural := BUS_DATA_WIDTH/PRIM_WIDTH;
  constant clk_period           : time    := 10 ns;

  signal clk                    : std_logic;
  signal reset                  : std_logic;
  signal ctrl_done              : std_logic;
  signal in_valid               : std_logic;
  signal in_ready               : std_logic;
  signal in_data                : std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
  signal new_page_valid         : std_logic;
  signal new_page_ready         : std_logic;
  signal page_num_values        : std_logic_vector(31 downto 0);
  signal out_valid              : std_logic;
  signal out_ready              : std_logic;
  signal out_last               : std_logic;
  signal out_dvalid             : std_logic := '1';
  signal out_data               : std_logic_vector(log2ceil(ELEMENTS_PER_CYCLE+1) + ELEMENTS_PER_CYCLE*PRIM_WIDTH - 1 downto 0);
begin

  dut: entity work.PlainDecoder
    generic map(
      BUS_DATA_WIDTH            => BUS_DATA_WIDTH,
      ELEMENTS_PER_CYCLE        => ELEMENTS_PER_CYCLE,
      PRIM_WIDTH                => PRIM_WIDTH
    )
    port map(
      clk                       => clk,
      reset                     => reset,
      ctrl_done                 => ctrl_done,
      in_valid                  => in_valid,
      in_ready                  => in_ready,
      in_data                   => in_data,
      new_page_valid            => new_page_valid,
      new_page_ready            => new_page_ready,
      total_num_values          => std_logic_vector(to_unsigned(TOTAL_NUM_VALUES, 32)),
      page_num_values           => page_num_values,
      out_valid                 => out_valid,
      out_ready                 => out_ready,
      out_last                  => out_last,
      out_dvalid                => out_dvalid,
      out_data                  => out_data
    );

  page_num_p: process
    file input_data             : text;

    constant stream_stop_p      : real    := 0.05;
    constant max_stopped_cycles : real    := 50.0;

    variable input_line         : line;
    variable num_values         : std_logic_vector(31 downto 0);

    variable seed1              : positive := 1337;
    variable seed2              : positive := 4242;

    variable stream_stop        : real;
    variable num_stopped_cycles : real;
  begin
    file_open(input_data, "./test/encoding/PageNumValues_input.hex", read_mode);
    page_num_values <= (others => '0');

    loop
      wait until rising_edge(clk);
      exit when reset = '0';
    end loop;

    while not endfile(input_data) loop
      readline(input_data, input_line);
      hread(input_line, num_values);

      new_page_valid <= '1';
      page_num_values <= num_values;

      loop 
        wait until rising_edge(clk);
        exit when new_page_ready = '1';
      end loop;

      new_page_valid <= '0';

      -- Delay for a random amount of clock cycles to simulate a non-continuous stream
      uniform(seed1, seed2, stream_stop);
      if stream_stop < stream_stop_p then
        uniform(seed1, seed2, num_stopped_cycles);
        for i in 0 to integer(floor(num_stopped_cycles*max_stopped_cycles)) loop
          wait until rising_edge(clk);
        end loop;
      end if;
    end loop;

    report "All pages have been handshaked" severity note;

    wait;
  end process;

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
  begin
    file_open(input_data, "./test/encoding/PageData_input.hex", read_mode);
    in_valid <= '0';

    loop
      wait until rising_edge(clk);
      exit when reset = '0';
    end loop;

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

    report "PageData_input.hex has been fully read";

    wait;
  end process;

  check_p: process
    constant stream_stop_p      : real    := 0.05;
    constant max_stopped_cycles : real    := 10.0;

    variable counter            : natural := 0;
    variable read_data          : std_logic_vector(log2ceil(ELEMENTS_PER_CYCLE+1) + ELEMENTS_PER_CYCLE*PRIM_WIDTH - 1 downto 0);
    variable check_out_last     : std_logic;

    variable seed1              : positive := 1227;
    variable seed2              : positive := 4422;

    variable stream_stop        : real;
    variable num_stopped_cycles : real;
  begin
    out_ready <= '0';

    loop
      wait until rising_edge(clk);
      exit when reset = '0';
    end loop;

    loop
      out_ready <= '1';
  
      loop
        wait until rising_edge(clk);
        exit when out_valid = '1';
      end loop;
  
      out_ready <= '0';

      read_data      := out_data;
      check_out_last := out_last;
  
      for i in 0 to integer(floor(real(BUS_DATA_WIDTH)/real(PRIM_WIDTH)))-1 loop
        assert read_data(PRIM_WIDTH*(i+1)-1 downto PRIM_WIDTH*i) = std_logic_vector(to_unsigned(counter, PRIM_WIDTH))
          report "Incorrect out_data. Read " & integer'image(to_integer(unsigned(read_data(PRIM_WIDTH*(i+1)-1 downto PRIM_WIDTH*i)))) & " expected " & integer'image(counter) severity failure;
  
        counter := counter + 1;

        if counter = TOTAL_NUM_VALUES then
          assert check_out_last = '1'
            report "Out_last not asserted on last transaction" severity failure;

          report "All values read" severity note;
          counter := 0;
          exit;
        end if;
        wait for 0 ns;
      end loop;
  
      -- Delay for a random amount of clock cycles to simulate a non-continuous stream
      uniform(seed1, seed2, stream_stop);
      if stream_stop < stream_stop_p then
        uniform(seed1, seed2, num_stopped_cycles);
        for i in 0 to integer(floor(num_stopped_cycles*max_stopped_cycles)) loop
          wait until rising_edge(clk);
        end loop;
      end if;

      exit when ctrl_done = '1' and counter = 0;
    end loop;

    loop
      wait until rising_edge(clk);
      assert out_valid = '0'
        report "ValBuffer offers data on its output despite all values having been read" severity failure;
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