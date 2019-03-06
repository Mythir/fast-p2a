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
-- Use Fletcher ColumnConfig system for parsing the cfg strings
use work.ColumnConfig.all;
use work.ColumnConfigParse.all;

package Ptoa is

-----------------------------------------------------------------------------
  -- Helper functions
-----------------------------------------------------------------------------
-- Returns true if the Parquet pages described by the cfg string contain encoded definition levels
function definition_levels_encoded(cfg : in string) return boolean;
-- Returns true if the Parquet pages described by the cfg string contain encoded repetition levels
function repetition_levels_encoded(cfg : in string) return boolean;
  
end Ptoa;

package body Ptoa is
  function definition_levels_encoded(cfg : in string) return boolean is
    constant cmd : string := parse_command(cfg);
  begin
    if cmd = "null" or cmd = "list" or cmd = "listprim" then
      return true;
    else
      return false;
    end if;
  end function;

  function repetition_levels_encoded(cfg : in string) return boolean is
    constant cmd : string := parse_command(cfg);
  begin
    if cmd = "list" or cmd = "listprim" then
      return true;
    else
      return false;
    end if;
  end function;

end Ptoa;