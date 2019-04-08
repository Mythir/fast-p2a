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
use ieee.std_logic_misc.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

library work;

package Ptoa_sim is
  -----------------------------------------------------------------------------
    -- Helper functions
  -----------------------------------------------------------------------------
  -- Waits for a random amount of clock cycles. Helps in simulating a non-continuous stream.
  -- p_wait is the probability of waiting any amount of clock cycles.
  procedure rand_wait_cycles(
    signal clk       : in std_logic;
    variable seed1   : inout positive;
    variable seed2   : inout positive;
    p_wait           : in real;
    min_cyc          : in positive;
    max_cyc          : in positive
  );
    
end Ptoa_sim;

package body Ptoa_sim is
  procedure rand_wait_cycles(
    signal clk       : in std_logic;
    variable seed1   : inout positive;
    variable seed2   : inout positive;
    p_wait           : in real;
    min_cyc          : in positive;
    max_cyc          : in positive
  ) is
    variable stream_stop        : real;
    variable num_stopped_cycles : real;
  begin
    uniform(seed1, seed2, stream_stop);
      if stream_stop < p_wait then
        uniform(seed1, seed2, num_stopped_cycles);
        for i in 0 to (integer(floor(num_stopped_cycles*real(max_cyc-min_cyc))) + min_cyc) loop
          wait until rising_edge(clk);
        end loop;
      end if;
  end rand_wait_cycles;
end Ptoa_sim;