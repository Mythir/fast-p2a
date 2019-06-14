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
use work.UtilInt_pkg.all;
use work.Interconnect_pkg.all;
use work.Ptoa_sim.all;

-- Todo: description

entity Ingester_tb is
end Ingester_tb;

architecture tb of Ingester_tb is
  constant p_base_address       : natural := 128;
  constant p_data_size          : natural := 1024;

  constant BUS_DATA_WIDTH       : natural := 512;
  constant BUS_ADDR_WIDTH       : natural := 64;
  constant BUS_LEN_WIDTH        : natural := 8;
  constant BUS_BURST_MAX_LEN    : natural := 16;
  constant BUS_FIFO_DEPTH       : natural := 32;
  constant BUS_FIFO_RAM_CONFIG  : string  := "";
  constant clk_period           : time    := 10 ns;
  constant SREC_FILE            : string  := "./test/ingestion/test.srec";

  signal clk                    : std_logic;
  signal reset                  : std_logic;
  signal bus_rreq_valid         : std_logic;
  signal bus_rreq_ready         : std_logic;
  signal bus_rreq_addr          : std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
  signal bus_rreq_len           : std_logic_vector(BUS_LEN_WIDTH-1 downto 0);
  signal bus_rdat_valid         : std_logic;
  signal bus_rdat_ready         : std_logic;
  signal bus_rdat_data          : std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
  signal bus_rdat_last          : std_logic;
  signal out_valid              : std_logic;
  signal out_ready              : std_logic;
  signal out_data               : std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
  signal pa_valid               : std_logic;
  signal pa_ready               : std_logic;
  signal pa_data                : std_logic_vector(log2ceil(BUS_DATA_WIDTH/8)-1 downto 0);
  signal start                  : std_logic;
  signal stop                   : std_logic;
  signal base_address           : std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
  signal data_size              : std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
begin
  slave_mock: entity work.BusReadSlaveMock
  generic map(
    BUS_ADDR_WIDTH              => BUS_ADDR_WIDTH,
    BUS_LEN_WIDTH               => BUS_LEN_WIDTH,
    BUS_DATA_WIDTH              => BUS_DATA_WIDTH,
    SEED                        => 1337,
    RANDOM_REQUEST_TIMING       => false,
    RANDOM_RESPONSE_TIMING      => false,
    SREC_FILE                   => SREC_FILE
  )
  port map(
    clk                         => clk,
    reset                       => reset,
    rreq_valid                  => bus_rreq_valid,
    rreq_ready                  => bus_rreq_ready,
    rreq_addr                   => bus_rreq_addr,
    rreq_len                    => bus_rreq_len,
    rdat_valid                  => bus_rdat_valid,
    rdat_ready                  => bus_rdat_ready,
    rdat_data                   => bus_rdat_data,
    rdat_last                   => bus_rdat_last
  );

  dut: entity work.Ingester
  generic map(
    BUS_DATA_WIDTH      => BUS_DATA_WIDTH,
    BUS_ADDR_WIDTH      => BUS_ADDR_WIDTH,
    BUS_LEN_WIDTH       => BUS_LEN_WIDTH,
    BUS_BURST_MAX_LEN   => BUS_BURST_MAX_LEN,
    BUS_FIFO_DEPTH      => BUS_FIFO_DEPTH,
    BUS_FIFO_RAM_CONFIG => BUS_FIFO_RAM_CONFIG
  )
  port map(
    clk                 => clk,
    reset               => reset,
    bus_rreq_valid      => bus_rreq_valid,
    bus_rreq_ready      => bus_rreq_ready,
    bus_rreq_addr       => bus_rreq_addr,
    bus_rreq_len        => bus_rreq_len,
    bus_rdat_valid      => bus_rdat_valid,
    bus_rdat_ready      => bus_rdat_ready,
    bus_rdat_data       => bus_rdat_data,
    bus_rdat_last       => bus_rdat_last,
    out_valid           => out_valid,
    out_ready           => out_ready,
    out_data            => out_data,
    pa_valid            => pa_valid,
    pa_ready            => pa_ready,
    pa_data             => pa_data,
    start               => start,
    stop                => stop,
    base_address        => base_address,
    data_size           => data_size
  );

  ctrl_p: process
  begin
    start <= '0';
    stop <= '0';
    base_address <= (others => '0');
    data_size <= (others => '0');

    loop
      wait until rising_edge(clk);
      exit when reset = '0';
    end loop;

    -- Wait a bit before starting the ingester
    for i in 0 to 4 loop
      wait until rising_edge(clk);
    end loop;

    -- Skip PAR1 magic number in Parquet file
    base_address <= std_logic_vector(to_unsigned(p_base_address, base_address'length));
    -- The amount of bytes in the data intended for the hardware
    data_size <= std_logic_vector(to_unsigned(p_data_size, data_size'length));
    -- Start the hardware
    start <= '1';
    wait;
  end process;

  downstream_p: process
    file input_data             : text;

    variable input_line         : line;
    variable bus_word           : std_logic_vector(BUS_DATA_WIDTH-1 downto 0);

    -- Variables for randomizing handshake timing in the stream
    variable seed1    : positive := 4343;
    variable seed2    : positive := 4242;
    variable p_wait   : real     := 0.05;
    variable min_cyc  : positive := 1;
    variable max_cyc  : positive := 10;
  begin
    file_open(input_data, "./test/ingestion/test.hex1", read_mode);
    pa_ready <= '0';
    out_ready <= '0';

    loop
      wait until rising_edge(clk);
      exit when reset = '0';
    end loop;

    -- Read initial misalignment from Ingester
    pa_ready <= '1';

    loop
      wait until rising_edge(clk);
      exit when pa_valid = '1';
    end loop;

    pa_ready <= '0';

    -- Start receiving output from ingester
    while not endfile(input_data) loop
      readline(input_data, input_line);
      hread(input_line, bus_word);

      out_ready <= '1';
  
      loop 
        wait until rising_edge(clk);
        exit when out_valid = '1';
      end loop;

      out_ready <= '0';

      assert bus_word = out_data
        report "Unexpected out data" severity failure;

      rand_wait_cycles(clk, seed1, seed2, p_wait, min_cyc, max_cyc);
    end loop;

    report "Reached end of expected output file" severity note;

    loop
      wait until rising_edge(clk);
      assert out_valid = '0'
        report "Ingester outputting more data than required" severity failure;
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