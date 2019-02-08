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
use ieee.std_logic_misc.all;
use ieee.numeric_std.all;

library work;
use work.Utils.all;

package Encoding is

  component VarIntDecoder is
    generic (
      INT_BIT_WIDTH               : natural;
      ZIGZAG_ENCODED              : boolean
    );
    port (
      clk                         : in std_logic;
      reset                       : in std_logic;
      start                       : in std_logic;
      in_data                     : in std_logic_vector(7 downto 0);
      in_valid                    : in std_logic;
      out_data                    : out std_logic_vector(INT_BIT_WIDTH-1 downto 0)
    );
  end component;

  -----------------------------------------------------------------------------
  -- Helper functions
  -----------------------------------------------------------------------------
  -- Decodes zigzag encoded integers to correct integer value;
  function decode_zigzag(a : in std_logic_vector) return integer;
  -- Encodes integers to zigzag.
  function encode_zigzag(a : in std_logic_vector) return integer;

end Encoding;

package body Encoding is
  function encode_zigzag(a : in std_logic_vector) return integer is
    variable x : signed(a'length - 1 downto 0);
    variable y : signed(a'length - 1 downto 0);
  begin
    x := shift_right(signed(a), a'length - 1);
    y := shift_left(signed(a), 1);
    return to_integer(signed(x xor y));
  end function;

  function decode_zigzag(a : in std_logic_vector) return integer is
    variable x : std_logic_vector(a'length - 1 downto 0);
    variable y : std_logic_vector(a'length - 1 downto 0);
  begin
    x := std_logic_vector(shift_right(unsigned(a), 1));
    y := std_logic_vector(-signed(a and slv(1, a'length)));
    return to_integer(signed(x xor y));
  end function;
end Encoding;