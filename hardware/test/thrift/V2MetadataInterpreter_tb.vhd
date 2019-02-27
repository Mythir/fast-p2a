
-- Copyright 2018 Delft University of Technology
--
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

-- Todo: Description

entity V2MetadataInterpreter_tb is
end V2MetadataInterpreter_tb;

architecture tb of V2MetadataInterpreter_tb is
  constant clk_period                : time    := 10 ns;
  constant BUS_DATA_WIDTH            : natural := 512;
  constant CYCLE_COUNT_WIDTH         : natural := 8;

  signal clk                         : std_logic;
  signal hw_reset                    : std_logic;
  signal in_valid                    : std_logic;
  signal in_ready                    : std_logic;
  signal in_data                     : std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
  signal da_valid                    : std_logic;
  signal da_ready                    : std_logic;
  signal da_bytes_consumed           : std_logic_vector(log2ceil(BUS_DATA_WIDTH/8)+1 downto 0);
  signal rl_byte_length              : std_logic_vector(31 downto 0);
  signal dl_byte_length              : std_logic_vector(31 downto 0);
  signal dc_uncomp_size              : std_logic_vector(31 downto 0);
  signal dc_comp_size                : std_logic_vector(31 downto 0);
  signal dd_num_values               : std_logic_vector(31 downto 0);

begin
  dut : entity work.V2MetadataInterpreter
  generic map(
    BUS_DATA_WIDTH => BUS_DATA_WIDTH
  )
  port map(
    clk                 => clk,
    hw_reset            => hw_reset,
    in_valid            => in_valid,
    in_ready            => in_ready,
    in_data             => in_data,
    da_valid            => da_valid,
    da_ready            => da_ready,
    da_bytes_consumed   => da_bytes_consumed,
    rl_byte_length      => rl_byte_length,
    dl_byte_length      => dl_byte_length,
    dc_uncomp_size      => dc_uncomp_size,
    dc_comp_size        => dc_comp_size,
    dd_num_values       => dd_num_values
  );

  values_p: process is
  begin
    in_valid <= '0';
    da_ready <= '1';

    loop
      wait until rising_edge(clk);
      exit when hw_reset = '0';
    end loop;

    in_valid <= '1';
    -- Page header of a plain encoded uncompressed (size=81495) file with 10000 values, def_byte_length 4, rep_byte_length 1491
    in_data(BUS_DATA_WIDTH - 1 downto BUS_DATA_WIDTH - (72 * 4)) <= x"150615aef90915aef9095c15a09c011500159a201500150815a61700000bcee9efd3fd12";
    in_data(BUS_DATA_WIDTH - (72 * 4) -1 downto 0) <= (others => '0');

    loop
      wait until rising_edge(clk);
      exit when in_ready = '1';
    end loop;

    in_valid <= '0';

    loop
      wait until rising_edge(clk);
      exit when da_valid = '1';
    end loop;

    da_ready <= '0';
    in_data <= (others => '0');

    wait;
  end process;

  clk_p :process
  begin
    clk <= '0';
    wait for clk_period/2;
    clk <= '1';
    wait for clk_period/2;
  end process;

  reset_p: process is
  begin
    hw_reset <= '1';
    wait for 20 ns;
    wait until rising_edge(clk);
    hw_reset <= '0';
    wait;
  end process;
end architecture;
