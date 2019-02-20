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

entity DataAligner_tb is
end DataAligner_tb;

architecture tb of DataAligner_tb is
  constant BUS_DATA_WIDTH       : natural := 512;
  constant NUM_CONSUMERS        : natural := 3;
  constant NUM_SHIFT_STAGES     : natural := 6;
  constant clk_period           : time    := 10 ns;

  signal clk                    : std_logic;
  signal reset                  : std_logic;
  signal in_valid               : std_logic;
  signal in_ready               : std_logic;
  signal in_data                : std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
  signal out_valid              : std_logic_vector(NUM_CONSUMERS-1 downto 0);
  signal out_ready              : std_logic_vector(NUM_CONSUMERS-1 downto 0);
  signal out_data               : std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
  signal bytes_consumed         : std_logic_vector(NUM_CONSUMERS*log2ceil(BUS_DATA_WIDTH/8)-1 downto 0);
  signal bc_valid               : std_logic_vector(NUM_CONSUMERS-1 downto 0);
  signal bc_ready               : std_logic_vector(NUM_CONSUMERS-1 downto 0);
  signal prod_alignment         : std_logic_vector(log2ceil(BUS_DATA_WIDTH/8)-1 downto 0);
  signal pa_valid               : std_logic;
  signal pa_ready               : std_logic;

begin
  dut: entity work.DataAligner
  generic map(
    BUS_DATA_WIDTH              => BUS_DATA_WIDTH,
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
    pa_ready                    => pa_ready
  );

  

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