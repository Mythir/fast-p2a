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
-- Fletcher utils, for use of log2ceil function.
use work.Utils.all;

entity ShifterRecombiner_tb is
end ShifterRecombiner_tb;

architecture tb of ShifterRecombiner_tb is
  constant BUS_DATA_WIDTH         : natural := 512;
  constant ELEMENT_WIDTH          : natural := 8;
  constant SHIFT_WIDTH            : natural := log2ceil(BUS_DATA_WIDTH/ELEMENT_WIDTH);
  constant NUM_SHIFT_STAGES       : natural := SHIFT_WIDTH;
  constant clk_period                : time := 10ns;

  signal clk                      : std_logic;
  signal reset                    : std_logic;
  signal clear                    : std_logic;
  signal in_valid                 : std_logic;
  signal in_ready                 : std_logic;
  signal in_data                  : std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
  signal out_valid                : std_logic;
  signal out_ready                : std_logic;
  signal out_data                 : std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
  signal alignment                : std_logic_vector(SHIFT_WIDTH-1 downto 0);

  signal consumed_word            : std_logic_vector(BUS_DATA_WIDTH-1 downto 0);

  type mem is array (0 to 14) of std_logic_vector(511 downto 0);
  constant ShifterRecombiner_ROM : mem := (
    0 => x"00001111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111", -- 4 bytes misaligned
    1 => x"11112222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222",
    2 => x"22223333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333",
    3 => x"33334444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444",
    4 => x"44445555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555",
    5 => x"55556666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666",
    6 => x"66667777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777",
    7 => x"77778888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888",
    8 => x"88889999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999",
    9 => x"99990000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
    10 => x"00000000000000000000000000000000001111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111", -- 17 bytes misaligned
    11 => x"11111111111111111111111111111111112222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222",
    12 => x"22222222222222222222222222222222223333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333",
    13 => x"33333333333333333333333333333333334444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444",
    14 => x"44444444444444444444444444444444445555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555"
  );

begin
  dut: entity work.ShifterRecombiner
  generic map(
    BUS_DATA_WIDTH              => BUS_DATA_WIDTH,
    SHIFT_WIDTH                 => SHIFT_WIDTH,
    ELEMENT_WIDTH               => ELEMENT_WIDTH,
    NUM_SHIFT_STAGES            => NUM_SHIFT_STAGES
  )
  port map(
    clk                         => clk,
    reset                       => reset,
    clear                       => clear,
    in_valid                    => in_valid,
    in_ready                    => in_ready,
    in_data                     => in_data,
    out_valid                   => out_valid,
    out_ready                   => out_ready,
    out_data                    => out_data,
    alignment                   => alignment
  );

  upstream_p : process
  begin
    loop
      wait until rising_edge(clk);
      exit when reset = '0';
    end loop;

    for i in 0 to ShifterRecombiner_ROM'length-1 loop
      alignment <= std_logic_vector(to_unsigned(2, alignment'length));

      if clear = '1' then
        exit;
      end if;

      in_valid <= '1';
      in_data <= ShifterRecombiner_ROM(i);

      loop
        wait until rising_edge(clk);
        exit when in_ready = '1';
      end loop;

      in_valid <= '0';

      -- Stall upstream a couple of cycles at index 5
      if i = 5 then
        wait until rising_edge(clk);
        wait until rising_edge(clk);
        wait until rising_edge(clk);
        wait until rising_edge(clk);
        wait until rising_edge(clk);
      end if;

    end loop;

    loop
      wait until rising_edge(clk);
      exit when clear = '1';
    end loop;

    for i in 10 to ShifterRecombiner_ROM'length-1 loop
      alignment <= std_logic_vector(to_unsigned(17, alignment'length));

      in_valid <= '1';
      in_data <= ShifterRecombiner_ROM(i);

      loop
        wait until rising_edge(clk);
        exit when in_ready = '1';
      end loop;

      in_valid <= '0';

      -- Stall upstream a couple of cycles at index 5
      if i = 5 then
        wait until rising_edge(clk);
        wait until rising_edge(clk);
        wait until rising_edge(clk);
        wait until rising_edge(clk);
        wait until rising_edge(clk);
      end if;

    end loop;
    wait;
  end process;

  downstream_p : process
  begin
    clear <= '0';
    loop
      wait until rising_edge(clk);
      exit when reset = '0';
    end loop;

    for i in 0 to 500 loop
      clear <= '0';
      out_ready <= '1';
      loop
        wait until rising_edge(clk);
        exit when out_valid = '1';
      end loop;

      consumed_word <= out_data;
      out_ready <= '0';

      -- After consuming index 9 we clear the pipeline for a new alignment.
      if i = 9 then
        clear <= '1';
        wait until rising_edge(clk);
      end if;

      -- Stall downstream a couple of cycles after 12th consumed bus word
      if i = 11 then
        wait until rising_edge(clk);
        wait until rising_edge(clk);
        wait until rising_edge(clk);
        wait until rising_edge(clk);
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