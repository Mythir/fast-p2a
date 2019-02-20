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

entity HistoryBuffer_tb is
end HistoryBuffer_tb;

architecture tb of HistoryBuffer_tb is
  -- For easy debugging we keep the data width at 8, in this project they are generally 512 bits wide
  constant BUS_DATA_WIDTH            : natural := 8;
  constant DEPTH_LOG2                : natural := 4;
  constant clk_period                : time := 10 ns;

  signal clk                         :  std_logic;
  signal reset                       :  std_logic;
  signal in_valid                    :  std_logic;
  signal in_ready                    :  std_logic;
  signal in_data                     :  std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
  signal out_valid                   :  std_logic;
  signal out_ready                   :  std_logic;
  signal out_data                    :  std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
  signal start_rewind                :  std_logic;
  signal end_rewind                  :  std_logic;
  signal delete_oldest               :  std_logic;

  signal consumed_word               : std_logic_vector(BUS_DATA_WIDTH-1 downto 0);

  -- Input for the control_p what it should do per clock cycle (after reset goes low). 0: nothing, 1: start_rewind, 2: delete_oldest, 3: start_rewind and delete_oldest
  type mem is array (0 to 29) of integer;
    constant Instruction_ROM : mem := (
      0 => 0,
      1 => 0,
      2 => 0,
      3 => 0,
      4 => 0,
      5 => 0,
      6 => 0,
      7 => 2,
      8 => 3,
      9 => 0,
      10 => 0,
      11 => 2,
      12 => 2,
      13 => 2,
      14 => 0,
      15 => 1,
      16 => 0,
      17 => 0,
      18 => 0,
      19 => 0,
      20 => 0,
      21 => 1,
      22 => 0,
      23 => 0,
      24 => 3,
      25 => 0,
      26 => 0,
      27 => 0,
      28 => 0,
      29 => 0
    );

begin

  dut: entity work.HistoryBuffer
    generic map(
      BUS_DATA_WIDTH              => BUS_DATA_WIDTH,
      DEPTH_LOG2                  => DEPTH_LOG2
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
      start_rewind                => start_rewind,
      end_rewind                  => end_rewind,
      delete_oldest               => delete_oldest
    );

    -- This process is responsible for data input into the HistoryBuffer
  upstream_p : process
    variable i : integer := 0;
  begin
    in_valid <= '0';
    loop
      wait until rising_edge(clk);
      exit when reset = '0';
    end loop;

    loop
      in_valid <= '1';

      in_data <= std_logic_vector(to_unsigned(i, in_data'length));
  
      loop
        wait until rising_edge(clk);
        exit when in_ready = '1';
      end loop;

      in_valid <= '0';

      i := i+1;
    end loop;
    wait;
  end process;

  -- This process reads the data coming out of the buffer in case of a rewind
  rewind_read_p : process
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

      consumed_word <= out_data;

      out_ready <= '0';
    end loop;
    wait;
  end process;

  -- This process reads the instruction rom and deletes data or starts rewinds accordingly
  control_p: process
    variable j : integer := 0;
  begin
    start_rewind <= '0';
    delete_oldest <= '0';
    loop
      wait until rising_edge(clk);
      exit when reset = '0';
    end loop;

    loop
      start_rewind <= '0';
      delete_oldest <= '0';

      if Instruction_ROM(j) = 1 then
        start_rewind <= '1';
      elsif Instruction_ROM(j) = 2 then
        delete_oldest <= '1';
      elsif Instruction_ROM(j) = 3 then
        start_rewind <= '1';
        delete_oldest <= '1';
      end if;

      wait until rising_edge(clk);
      j := j+1;
    end loop;
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