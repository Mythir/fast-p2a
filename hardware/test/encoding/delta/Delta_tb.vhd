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
use work.Delta.all;

-- Small testbench file for testing the functions used to generate the tables containing the amount of values to unpack for each bit width.

entity Delta_tb is
end Delta_tb;

architecture tb of Delta_tb is
  constant MAX_DELTAS_PER_CYCLE : natural := 16;
  constant DEC_DATA_WIDTH       : natural := 64;

  constant count_lut_64 : count_lut_64_t := init_count_lut_64(MAX_DELTAS_PER_CYCLE, DEC_DATA_WIDTH);
  constant count_lut_32 : count_lut_32_t := init_count_lut_32(MAX_DELTAS_PER_CYCLE, DEC_DATA_WIDTH);

  constant shift_lut_64 : shift_lut_64_t := init_shift_lut_64(MAX_DELTAS_PER_CYCLE, DEC_DATA_WIDTH);
  constant shift_lut_32 : shift_lut_32_t := init_shift_lut_32(MAX_DELTAS_PER_CYCLE, DEC_DATA_WIDTH);

  constant mask_lut_64 : mask_lut_64_t := init_mask_lut_64;
  constant mask_lut_32 : mask_lut_32_t := init_mask_lut_32;
begin
  test: process
  begin
    for i in 0 to count_lut_64'length-1 loop
      report integer'image(i) & " => " & integer'image(count_lut_64(i)) severity note;
      wait for 1 ns;
    end loop;

    for i in 0 to count_lut_32'length-1 loop
      report integer'image(i) & " => " & integer'image(count_lut_32(i)) severity note;
      wait for 1 ns;
    end loop;

    for i in 0 to shift_lut_64'length-1 loop
      report integer'image(i) & " => " & integer'image(shift_lut_64(i)) severity note;
      wait for 1 ns;
    end loop;

    for i in 0 to shift_lut_32'length-1 loop
      report integer'image(i) & " => " & integer'image(shift_lut_32(i)) severity note;
      wait for 1 ns;
    end loop;

    for i in 0 to mask_lut_64'length-1 loop
      report integer'image(i) & " => " severity note;
      wait for 1 ns;
    end loop;

    for i in 0 to mask_lut_32'length-1 loop
      report integer'image(i) & " => " severity note;
      wait for 1 ns;
    end loop;
  wait;
  end process;
end architecture;