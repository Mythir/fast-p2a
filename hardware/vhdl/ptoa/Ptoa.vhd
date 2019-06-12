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
-- Use Fletcher ArrayConfig system for parsing the cfg strings
use work.ArrayConfig.all;
use work.ArrayConfigParse.all;
use work.Utils.all;

package Ptoa is

  component ParquetReader is
    generic(
      BUS_ADDR_WIDTH                             : natural;
      BUS_DATA_WIDTH                             : natural;
      BUS_STROBE_WIDTH                           : natural;
      BUS_LEN_WIDTH                              : natural;
      BUS_BURST_STEP_LEN                         : natural;
      BUS_BURST_MAX_LEN                          : natural;
      ---------------------------------------------------------------------------
      INDEX_WIDTH                                : natural;
      ---------------------------------------------------------------------------
      TAG_WIDTH                                  : natural;
      CFG                                        : string;
      ENCODING                                   : string;
      COMPRESSION_CODEC                          : string
    );
    port(
      clk                                        : in  std_logic;
      reset                                      : in  std_logic;
      ---------------------------------------------------------------------------
      bus_rreq_valid                             : out std_logic;
      bus_rreq_ready                             : in  std_logic;
      bus_rreq_addr                              : out std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
      bus_rreq_len                               : out std_logic_vector(BUS_LEN_WIDTH-1 downto 0);
      ---------------------------------------------------------------------------
      bus_rdat_valid                             : in  std_logic;
      bus_rdat_ready                             : out std_logic;
      bus_rdat_data                              : in  std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
      bus_rdat_last                              : in  std_logic;
      ---------------------------------------------------------------------------
      bus_wreq_valid                             : out std_logic;
      bus_wreq_len                               : out std_logic_vector(BUS_LEN_WIDTH-1 downto 0);
      bus_wreq_addr                              : out std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
      bus_wreq_ready                             : in  std_logic;
      ---------------------------------------------------------------------------
      bus_wdat_valid                             : out std_logic;
      bus_wdat_ready                             : in  std_logic;
      bus_wdat_data                              : out std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
      bus_wdat_strobe                            : out std_logic_vector(BUS_STROBE_WIDTH-1 downto 0);
      bus_wdat_last                              : out std_logic;
      ---------------------------------------------------------------------------
      base_pages_ptr                             : in  std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
      max_data_size                              : in  std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
      total_num_values                           : in  std_logic_vector(31 downto 0);
      values_buffer_addr                         : in  std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
      offsets_buffer_addr                        : in  std_logic_vector(BUS_ADDR_WIDTH-1 downto 0) := (others => '0');
      ---------------------------------------------------------------------------
      start                                      : in  std_logic;
      stop                                       : in  std_logic;
      ---------------------------------------------------------------------------
      done                                       : out std_logic
    );
  end component;

-----------------------------------------------------------------------------
  -- Helper functions
-----------------------------------------------------------------------------
-- Returns true if the Parquet pages described by the cfg string contain encoded definition levels
function definition_levels_encoded(cfg : in string) return boolean;
-- Returns true if the Parquet pages described by the cfg string contain encoded repetition levels
function repetition_levels_encoded(cfg : in string) return boolean;
-- Returns maximum length of a varint encoded from an integer of a certain width.
function max_varint_bytes(width : in natural) return natural;

function element_swap(a : in std_logic_vector; element_width : in natural) return std_logic_vector;
  
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

  function max_varint_bytes(width : in natural) return natural is
  begin
    return natural(CEIL(real(width)/real(7)));
  end function;

  function element_swap(a : in std_logic_vector; element_width : in natural) return std_logic_vector is
    constant elements_in_a : natural := a'length/element_width;
    variable result : std_logic_vector(a'length-1 downto 0);
  begin
    for i in 0 to elements_in_a-1 loop
      result(element_width*(i+1)-1 downto element_width*i) := a(element_width*(elements_in_a-i)-1 downto element_width*(elements_in_a-i-1));
    end loop;

    return result;
  end function;

end Ptoa;