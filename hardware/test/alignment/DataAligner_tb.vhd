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

entity DataAligner_tb is
end DataAligner_tb;

architecture tb of DataAligner_tb is
  constant BUS_DATA_WIDTH       : natural := 512;
  constant BUS_ADDR_WIDTH       : natural := 64;
  constant NUM_CONSUMERS        : natural := 5;
  constant NUM_SHIFT_STAGES     : natural := 6;
  constant SHIFT_WIDTH          : natural := log2ceil(BUS_DATA_WIDTH/8);
  constant last_word_enc_width  : natural := 40;
  constant clk_period           : time    := 10 ns;

  constant stream_stop_p        : real    := 0.05;
  constant max_stopped_cycles   : real    := 16.0;

  -- These constants should be changed when a new DataAligner_input file is created
  constant init_misalignment    : natural := 62;
  constant data_size            : natural := 69025;

  signal clk                    : std_logic;
  signal reset                  : std_logic;
  signal in_valid               : std_logic;
  signal in_ready               : std_logic;
  signal in_data                : std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
  signal out_valid              : std_logic_vector(NUM_CONSUMERS-1 downto 0);
  signal out_ready              : std_logic_vector(NUM_CONSUMERS-1 downto 0);
  signal out_data               : std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
  signal bytes_consumed         : std_logic_vector(NUM_CONSUMERS*(SHIFT_WIDTH+1)-1 downto 0);
  signal bc_valid               : std_logic_vector(NUM_CONSUMERS-1 downto 0);
  signal bc_ready               : std_logic_vector(NUM_CONSUMERS-1 downto 0);
  signal prod_alignment         : std_logic_vector(SHIFT_WIDTH-1 downto 0);
  signal pa_valid               : std_logic;
  signal pa_ready               : std_logic;

begin
  dut: entity work.DataAligner
  generic map(
    BUS_DATA_WIDTH              => BUS_DATA_WIDTH,
    BUS_ADDR_WIDTH              => BUS_ADDR_WIDTH,
    NUM_CONSUMERS               => NUM_CONSUMERS,
    NUM_SHIFT_STAGES            => NUM_SHIFT_STAGES
  )
  port map(
    clk                         => clk,
    reset                       => reset,
    in_valid                    => in_valid,
    in_ready                    => in_ready,
    in_data                     => in_data,
    out_valid                   => out_valid,
    out_ready                   => out_ready,
    out_data                    => out_data,
    bytes_consumed              => bytes_consumed,
    bc_valid                    => bc_valid,
    bc_ready                    => bc_ready,
    prod_alignment              => prod_alignment,
    pa_valid                    => pa_valid,
    pa_ready                    => pa_ready,
    data_size                   => std_logic_vector(to_unsigned(data_size, BUS_ADDR_WIDTH))
  );

  upstream_p : process
    file input_data             : text;

    variable input_line         : line;
    variable bus_word           : std_logic_vector(BUS_DATA_WIDTH-1 downto 0);

    variable seed1              : positive := 1337;
    variable seed2              : positive := 4242;

    variable stream_stop        : real;
    variable num_stopped_cycles : real;
  begin
    file_open(input_data, "./test/alignment/DataAligner_input.hex", read_mode);
    --file_open(input_data, "DataAligner_input.hex", read_mode);

    in_valid <= '0';
    in_data <= (others => '0');
    prod_alignment <= (others => '0');
    pa_valid <= '0';

    loop
      wait until rising_edge(clk);
      exit when reset = '0';
    end loop;

    -- Transfer initial alignment
    wait for 1 ns;
    pa_valid <= '1';
    prod_alignment <= std_logic_vector(to_unsigned(init_misalignment, prod_alignment'length));

    loop
      wait until rising_edge(clk);
      exit when pa_ready = '1';
    end loop;
    wait for 1 ps;

    pa_valid <= '0';
    prod_alignment <= (others => '0');

    while not endfile(input_data) loop
      readline(input_data, input_line);
      hread(input_line, bus_word);

      in_valid <= '1';
      in_data <= bus_word;

      loop 
        wait until rising_edge(clk);
        exit when in_ready = '1';
      end loop;
      wait for 1 ps;

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

    report "All input data has been processed.";

    wait;
  end process;

  gen_consumers : for i in 0 to NUM_CONSUMERS-1 generate
    consumer_p : process
      file output_check           : text;
  
      variable check_line         : line;
      variable expected_output    : std_logic_vector(BUS_DATA_WIDTH-1 downto 0); 

      variable seed1              : positive := 137;
      variable seed2              : positive := 442;
  
      variable stream_stop        : real;
      variable num_stopped_cycles : real;

      variable v_out_data         : std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
    begin
      file_open(output_check, "./test/alignment/DataAligner_out" & integer'image(i) & ".hex", read_mode);
      --file_open(output_check, "DataAligner_out" & integer'image(i) & ".hex", read_mode);

      out_ready(i) <= '0';
      bc_valid(i) <= '0';
      bytes_consumed((SHIFT_WIDTH+1)*(i+1)-1 downto (SHIFT_WIDTH+1)*i) <= (others => '0');

      loop
        wait until rising_edge(clk);
        exit when reset = '0';
      end loop;

      while not endfile(output_check) loop
        readline(output_check, check_line);
        out_ready(i) <= '1';
  
        loop
          wait until rising_edge(clk);
          exit when out_valid(i) = '1';
        end loop;
        wait for 1 ps;
  
        out_ready(i) <= '0';
        v_out_data := out_data;

        -- After receiving data from DataAligner, wait for a random amount of cycles to simulate backpressure from downstream slowdowns
        uniform(seed1, seed2, stream_stop);
        if stream_stop < stream_stop_p then
          uniform(seed1, seed2, num_stopped_cycles);
          for i in 0 to integer(floor(num_stopped_cycles*max_stopped_cycles)) loop
            wait until rising_edge(clk);
          end loop;
        end if;

        -- Check if this is the last word of this alignment block, if yes, tell the DataAligner to realign with bytes_consumed
        if v_out_data(BUS_DATA_WIDTH-1 downto BUS_DATA_WIDTH-8) = x"00" then
          bc_valid(i) <= '1';
          bytes_consumed((SHIFT_WIDTH+1)*(i+1)-1 downto (SHIFT_WIDTH+1)*i) <= std_logic_vector(resize(unsigned(v_out_data(BUS_DATA_WIDTH-9 downto BUS_DATA_WIDTH-last_word_enc_width)), SHIFT_WIDTH+1));

          loop
            wait until rising_edge(clk);
            exit when bc_ready(i) = '1';
          end loop;
          wait for 1 ps;
          
          bc_valid(i) <= '0';
        else
          -- Verify DataAligner output
          hread(check_line, expected_output);

          assert v_out_data = expected_output
            report "Incorrect bus word received from DataAligner in consumer " & integer'image(i);
        end if;

        -- Wait for a random amount of cycles to simulate backpressure from downstream slowdowns
        uniform(seed1, seed2, stream_stop);
        if stream_stop < stream_stop_p then
          uniform(seed1, seed2, num_stopped_cycles);
          for i in 0 to integer(floor(num_stopped_cycles*max_stopped_cycles)) loop
            wait until rising_edge(clk);
          end loop;
        end if;

      end loop;

      report "Consumer " & integer'image(i) & " has received all expected data.";

      wait;
    end process;
  end generate;

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