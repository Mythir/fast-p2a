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
use ieee.math_real.all;

library work;
use work.UtilInt_pkg.all;

entity AdvanceableFiFo_tb is
end AdvanceableFiFo_tb;

architecture tb of AdvanceableFiFo_tb is
  constant DATA_WIDTH                : natural := 32;
  constant ADV_COUNT_WIDTH           : natural := 16;
  constant DEPTH_LOG2                : natural := 4;
  constant clk_period                : time    := 10 ns;

  signal clk                         : std_logic;
  signal reset                       : std_logic;
  signal in_valid                    : std_logic;
  signal in_ready                    : std_logic;
  signal in_data                     : std_logic_vector(DATA_WIDTH-1 downto 0);
  signal out_valid                   : std_logic;
  signal out_ready                   : std_logic;
  signal out_data                    : std_logic_vector(DATA_WIDTH-1 downto 0);
  signal adv_valid                   : std_logic;
  signal adv_ready                   : std_logic;
  signal adv_count                   : std_logic_vector(ADV_COUNT_WIDTH-1 downto 0);
begin

  dut: entity work.AdvanceableFiFo
    generic map(
      DATA_WIDTH              => DATA_WIDTH,
      ADV_COUNT_WIDTH         => ADV_COUNT_WIDTH,
      DEPTH_LOG2              => DEPTH_LOG2
    )
    port map(
      clk                     => clk,
      reset                   => reset,
      in_valid                => in_valid,
      in_ready                => in_ready,
      in_data                 => in_data,
      out_valid               => out_valid,
      out_ready               => out_ready,
      out_data                => out_data,
      adv_valid               => adv_valid,
      adv_ready               => adv_ready,
      adv_count               => adv_count
    );

  upstream_p: process
    variable i : integer := 0;

    constant stream_stop_p      : real    := 0.05;
    constant max_stopped_cycles : real    := 50.0;

    variable seed1              : positive := 1337;
    variable seed2              : positive := 4242;

    variable stream_stop        : real;
    variable num_stopped_cycles : real;
  begin
    in_valid <= '0';
    loop
      wait until rising_edge(clk);
      exit when reset = '0';
    end loop;

    loop
      in_valid <= '1';
      in_data <= std_logic_vector(to_unsigned(i, DATA_WIDTH));

      loop
        wait until rising_edge(clk);
        exit when in_ready = '1';
      end loop;
      in_valid <= '0';

      -- Delay for a random amount of clock cycles to simulate a non-continuous stream
      uniform(seed1, seed2, stream_stop);
      if stream_stop < stream_stop_p then
        uniform(seed1, seed2, num_stopped_cycles);
        for j in 0 to integer(floor(num_stopped_cycles*max_stopped_cycles)) loop
          wait until rising_edge(clk);
        end loop;
      end if;
      i := i+1;
    end loop;
    wait;
  end process;

  downstream_p: process
    variable check : integer := 0;

    constant stream_stop_p      : real    := 0.20;
    constant max_stopped_cycles : real    := 25.0;

    variable seed1              : positive := 1337;
    variable seed2              : positive := 4242;

    variable adv_seed1          : positive := 21334;
    variable adv_seed2          : positive := 21341;

    variable stream_stop        : real;
    variable num_stopped_cycles : real;

    variable advance_fifo_p     : real := 0.05;
    variable advance_fifo       : real;

    variable max_advance        : real := real(2**DEPTH_LOG2 * 3);
    variable num_advance        : real;
  begin
    out_ready <= '0';
    adv_valid <= '0';
    loop
      wait until rising_edge(clk);
      exit when reset = '0';
    end loop;

    loop
      -- Random FiFo advancement
      uniform(adv_seed1, adv_seed2, advance_fifo);
      if advance_fifo < advance_fifo_p then
        uniform(adv_seed1, adv_seed2, num_advance);
        adv_count <= std_logic_vector(to_unsigned(integer(floor(num_advance*max_advance)), adv_count'length));
        check := check + integer(floor(num_advance*max_advance));
        adv_valid <= '1';
        loop
          wait until rising_edge(clk);
          exit when adv_ready = '1';
        end loop;
        adv_valid <= '0';
      end if;

      out_ready <= '1';
      loop
        wait until rising_edge(clk);
        exit when out_valid = '1';
      end loop;
      out_ready <= '0';
      assert check = to_integer(unsigned(out_data))
        report "Unexpected output from FiFo" severity failure;

      -- Delay for a random amount of clock cycles to simulate a non-continuous stream
      uniform(seed1, seed2, stream_stop);
      if stream_stop < stream_stop_p then
        uniform(seed1, seed2, num_stopped_cycles);
        for j in 0 to integer(floor(num_stopped_cycles*max_stopped_cycles)) loop
          wait until rising_edge(clk);
        end loop;
      end if;
      check := check + 1;

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