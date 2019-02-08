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

entity VarIntDecoder_tb is
end VarIntDecoder_tb;

architecture tb of VarIntDecoder_tb is
  constant INT_BIT_WIDTH         	   : natural := 32;
  constant ZIGZAG_ENCODED        	   : boolean := false;
  signal clk                         : std_logic;
  signal reset                       : std_logic;
  signal start                       : std_logic;
  signal in_data                     : std_logic_vector(7 downto 0);
  signal out_data                    : std_logic_vector(INT_BIT_WIDTH-1 downto 0);
  signal last_byte                   : std_logic;
begin
  dut: entity work.VarIntDecoder
  generic map(
    INT_BIT_WIDTH               <= INT_BIT_WIDTH,
    ZIGZAG_ENCODED              <= ZIGZAG_ENCODED
  )
  port map(
    clk                         <=clk,
    reset                       <=reset,
    start                       <=start,
    in_data                     <=in_data,
    out_data                    <=out_data,
    last_byte                   <=last_byte 
  );

  clk_p :process
  begin
    clk <= '0';
    wait for clk_period/2;
    clk <= '1';
    wait for clk_period/2;
  end process;

  reset_p: process is
  begin
    reset <= '1';
    wait for 10 ns;
    wait until rising_edge(clk);
    reset <= '0';
    wait;
  end process;

end architecture;