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
use work.UtilInt_pkg.all;
use work.Ptoa.all;

package Delta is

  component DeltaDecoder is
    generic (
      BUS_DATA_WIDTH              : natural;
      DEC_DATA_WIDTH              : natural := 64;
      PRIM_WIDTH                  : natural;
      ELEMENTS_PER_CYCLE          : natural;
      RAM_CONFIG                  : string := ""
    );
    port (
      clk                         : in  std_logic;
      reset                       : in  std_logic;
      ctrl_done                   : out std_logic;
      in_valid                    : in  std_logic;
      in_ready                    : out std_logic;
      in_data                     : in  std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
      new_page_valid              : in  std_logic;
      new_page_ready              : out std_logic;
      total_num_values            : in  std_logic_vector(31 downto 0);
      page_num_values             : in  std_logic_vector(31 downto 0);
      uncompressed_size           : in  std_logic_vector(31 downto 0);
      out_valid                   : out std_logic;
      out_ready                   : in  std_logic;
      out_last                    : out std_logic;
      out_dvalid                  : out std_logic := '1';
      out_data                    : out std_logic_vector(log2ceil(ELEMENTS_PER_CYCLE+1) + ELEMENTS_PER_CYCLE*PRIM_WIDTH - 1 downto 0)
    );
  end component;

  component DeltaLengthDecoder is
    generic (
      BUS_DATA_WIDTH              : natural;
      DEC_DATA_WIDTH              : natural;
      INDEX_WIDTH                 : natural := 32;
      CHARS_PER_CYCLE             : natural;
      LENGTHS_PER_CYCLE           : natural;
      RAM_CONFIG                  : string := ""
    );
    port (
      clk                         : in  std_logic;
      reset                       : in  std_logic;
      ctrl_done                   : out std_logic;
      in_valid                    : in  std_logic;
      in_ready                    : out std_logic;
      in_data                     : in  std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
      new_page_valid              : in  std_logic;
      new_page_ready              : out std_logic;
      total_num_values            : in  std_logic_vector(31 downto 0);
      page_num_values             : in  std_logic_vector(31 downto 0);
      uncompressed_size           : in  std_logic_vector(31 downto 0);
      out_valid                   : out std_logic_vector(1 downto 0);
      out_ready                   : in  std_logic_vector(1 downto 0);
      out_last                    : out std_logic_vector(1 downto 0);
      out_dvalid                  : out std_logic_vector(1 downto 0) := (others => '1');
      out_data                    : out std_logic_vector(log2ceil(CHARS_PER_CYCLE+1) + CHARS_PER_CYCLE*8 + log2ceil(LENGTHS_PER_CYCLE+1) + LENGTHS_PER_CYCLE*INDEX_WIDTH - 1 downto 0)
    );
  end component;

  component DeltaHeaderReader is
    generic (
      BUS_DATA_WIDTH              : natural;
      NUM_SHIFT_STAGES            : natural;
      BLOCK_SIZE                  : natural := 128;
      MINIBLOCKS_IN_BLOCK         : natural := 4;
      PRIM_WIDTH                  : natural
    );
    port (
      clk                         : in  std_logic;
      reset                       : in  std_logic;
      in_valid                    : in  std_logic;
      in_ready                    : out std_logic;
      in_last                     : in  std_logic;
      in_data                     : in  std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
      fv_valid                    : out std_logic;
      fv_ready                    : in  std_logic;
      first_value                 : out std_logic_vector(PRIM_WIDTH-1 downto 0);
      out_valid                   : out std_logic;
      out_ready                   : in  std_logic;
      out_last                    : out std_logic;
      out_data                    : out std_logic_vector(BUS_DATA_WIDTH-1 downto 0)
    );
  end component;

  component BlockValuesAligner is
    generic (
      DEC_DATA_WIDTH              : natural;
      BLOCK_SIZE                  : natural;
      MINIBLOCKS_IN_BLOCK         : natural;
      MAX_DELTAS_PER_CYCLE        : natural;
      BYTES_IN_BLOCK_WIDTH        : natural := 16;
      PRIM_WIDTH                  : natural;
      RAM_CONFIG                  : string := ""
    );
    port (
      clk                         : in  std_logic;
      reset                       : in  std_logic;
      done                        : out std_logic;
      in_valid                    : in  std_logic;
      in_ready                    : out std_logic;
      in_data                     : in  std_logic_vector(DEC_DATA_WIDTH-1 downto 0);
      page_num_values             : in  std_logic_vector(31 downto 0);
      md_valid                    : out std_logic;
      md_ready                    : in  std_logic;
      md_data                     : out std_logic_vector(PRIM_WIDTH-1 downto 0);
      bc_valid                    : out std_logic;
      bc_ready                    : in  std_logic;
      bc_data                     : out std_logic_vector(BYTES_IN_BLOCK_WIDTH-1 downto 0);
      out_valid                   : out std_logic;
      out_ready                   : in  std_logic;
      out_data                    : out std_logic_vector(DEC_DATA_WIDTH-1 downto 0);
      out_count                   : out std_logic_vector(log2floor(MAX_DELTAS_PER_CYCLE) downto 0);
      out_width                   : out std_logic_vector(log2floor(PRIM_WIDTH) downto 0)
    );
  end component;

  component BlockHeaderReader is
    generic (
      DEC_DATA_WIDTH              : natural;
      BLOCK_SIZE                  : natural;
      MINIBLOCKS_IN_BLOCK         : natural;
      BYTES_IN_BLOCK_WIDTH        : natural := 16;
      FIFO_DEPTH                  : natural;
      PRIM_WIDTH                  : natural
    );
    port (
      clk                         : in  std_logic;
      reset                       : in  std_logic;
      page_done                   : out std_logic;
      in_valid                    : in  std_logic;
      in_ready                    : out std_logic;
      in_data                     : in  std_logic_vector(DEC_DATA_WIDTH-1 downto 0);
      page_num_values             : in  std_logic_vector(31 downto 0);
      md_valid                    : out std_logic;
      md_ready                    : in  std_logic;
      md_data                     : out std_logic_vector(PRIM_WIDTH-1 downto 0);
      bw_valid                    : out std_logic;
      bw_ready                    : in  std_logic;
      bw_data                     : out std_logic_vector(7 downto 0);
      bl_valid                    : out std_logic;
      bl_ready                    : in  std_logic;
      bl_data                     : out std_logic_vector(log2floor(max_varint_bytes(PRIM_WIDTH)+MINIBLOCKS_IN_BLOCK) downto 0);
      bc_valid                    : out std_logic;
      bc_ready                    : in  std_logic;
      bc_data                     : out std_logic_vector(BYTES_IN_BLOCK_WIDTH-1 downto 0)
    );
  end component;

  component BlockShiftControl is
    generic (
      DEC_DATA_WIDTH              : natural;
      BLOCK_SIZE                  : natural;
      MINIBLOCKS_IN_BLOCK         : natural;
      MAX_DELTAS_PER_CYCLE        : natural;
      PRIM_WIDTH                  : natural;
      COUNT_WIDTH                 : natural;
      WIDTH_WIDTH                 : natural;
      AMOUNT_WIDTH                : natural
    );
    port (
      clk                         : in  std_logic;
      reset                       : in  std_logic;
      page_done                   : out std_logic;
      in_valid                    : in  std_logic;
      in_ready                    : out std_logic;
      in_data                     : in  std_logic_vector(DEC_DATA_WIDTH-1 downto 0);
      page_num_values             : in  std_logic_vector(31 downto 0);
      bw_valid                    : in  std_logic;
      bw_ready                    : out std_logic;
      bw_data                     : in  std_logic_vector(7 downto 0);
      bl_valid                    : in  std_logic;
      bl_ready                    : out std_logic;
      bl_data                     : in  std_logic_vector(log2floor(max_varint_bytes(PRIM_WIDTH)+MINIBLOCKS_IN_BLOCK) downto 0);
      out_valid                   : out std_logic;
      out_ready                   : in  std_logic;
      out_data                    : out std_logic_vector(2*DEC_DATA_WIDTH-1 downto 0);
      out_amount                  : out std_logic_vector(AMOUNT_WIDTH-1 downto 0);
      out_width                   : out std_logic_vector(WIDTH_WIDTH-1 downto 0);
      out_count                   : out std_logic_vector(COUNT_WIDTH-1 downto 0)
    );
  end component;

  component BitUnpacker is
    generic (
      DEC_DATA_WIDTH              : natural;
      MAX_DELTAS_PER_CYCLE        : natural;
      PRIM_WIDTH                  : natural
    );
    port (
      clk                         : in  std_logic;
      reset                       : in  std_logic;
      in_valid                    : in  std_logic;
      in_ready                    : out std_logic;
      in_data                     : in  std_logic_vector(DEC_DATA_WIDTH-1 downto 0);
      in_count                    : in  std_logic_vector(log2floor(MAX_DELTAS_PER_CYCLE) downto 0);
      in_width                    : in  std_logic_vector(log2floor(PRIM_WIDTH) downto 0);
      out_valid                   : out std_logic;
      out_ready                   : in  std_logic;
      out_count                   : out std_logic_vector(log2floor(MAX_DELTAS_PER_CYCLE) downto 0);
      out_data                    : out std_logic_vector(MAX_DELTAS_PER_CYCLE*PRIM_WIDTH-1 downto 0)
    );
  end component;

  component BitUnpackerShifter is
    generic (
      ID                          : natural;
      DEC_DATA_WIDTH              : natural;
      MAX_DELTAS_PER_CYCLE        : natural;
      WIDTH_WIDTH                 : natural;
      PRIM_WIDTH                  : natural;
      NUM_SHIFT_STAGES            : natural;
      RAM_CONFIG                  : string := ""
    );
    port (
      clk                         : in  std_logic;
      reset                       : in  std_logic;
      in_valid                    : in  std_logic;
      in_ready                    : out std_logic;
      in_data                     : in  std_logic_vector(DEC_DATA_WIDTH-1 downto 0);
      in_width                    : in  std_logic_vector(WIDTH_WIDTH-1 downto 0);
      out_valid                   : out std_logic;
      out_ready                   : in  std_logic;
      out_data                    : out std_logic_vector(PRIM_WIDTH-1 downto 0)
    );
  end component;

  component DeltaAccumulatorMD is
    generic (
      MAX_DELTAS_PER_CYCLE        : natural;
      BLOCK_SIZE                  : natural;
      MINIBLOCKS_IN_BLOCK         : natural;
      PRIM_WIDTH                  : natural
    );
    port (
      clk                         : in  std_logic;
      reset                       : in  std_logic;
      in_valid                    : in  std_logic;
      in_ready                    : out std_logic;
      in_data                     : in  std_logic_vector(MAX_DELTAS_PER_CYCLE*PRIM_WIDTH-1 downto 0);
      in_count                    : in  std_logic_vector(log2floor(MAX_DELTAS_PER_CYCLE) downto 0);
      md_valid                    : in  std_logic;
      md_ready                    : out std_logic;
      md_data                     : in  std_logic_vector(PRIM_WIDTH-1 downto 0);
      out_valid                   : out std_logic;
      out_ready                   : in  std_logic;
      out_count                   : out std_logic_vector(log2floor(MAX_DELTAS_PER_CYCLE) downto 0);
      out_data                    : out std_logic_vector(MAX_DELTAS_PER_CYCLE*PRIM_WIDTH-1 downto 0)
    );
  end component;

  component DeltaAccumulatorFV is
    generic (
      MAX_DELTAS_PER_CYCLE        : natural;
      BLOCK_SIZE                  : natural;
      PRIM_WIDTH                  : natural
    );
    port (
      clk                         : in  std_logic;
      reset                       : in  std_logic;
      ctrl_done                   : out std_logic;
      total_num_values            : in  std_logic_vector(31 downto 0);
      page_num_values             : in  std_logic_vector(31 downto 0);
      new_page_valid              : in  std_logic;
      new_page_ready              : out std_logic;
      in_valid                    : in  std_logic;
      in_ready                    : out std_logic;
      in_data                     : in  std_logic_vector(MAX_DELTAS_PER_CYCLE*PRIM_WIDTH-1 downto 0);
      in_count                    : in  std_logic_vector(log2floor(MAX_DELTAS_PER_CYCLE) downto 0);
      fv_valid                    : in  std_logic;
      fv_ready                    : out std_logic;
      fv_data                     : in  std_logic_vector(PRIM_WIDTH-1 downto 0);
      out_valid                   : out std_logic;
      out_ready                   : in  std_logic;
      out_last                    : out std_logic;
      out_count                   : out std_logic_vector(log2floor(MAX_DELTAS_PER_CYCLE) downto 0);
      out_data                    : out std_logic_vector(MAX_DELTAS_PER_CYCLE*PRIM_WIDTH-1 downto 0)
    );
  end component;

  component DeltaAccumulator is
    generic (
      MAX_DELTAS_PER_CYCLE        : natural;
      BLOCK_SIZE                  : natural;
      MINIBLOCKS_IN_BLOCK         : natural;
      DECODING_STRINGS            : boolean := false;
      PRIM_WIDTH                  : natural
    );
    port (
      clk                         : in  std_logic;
      reset                       : in  std_logic;
      total_num_values            : in  std_logic_vector(31 downto 0);
      page_num_values             : in  std_logic_vector(31 downto 0);
      new_page_valid              : in  std_logic;
      new_page_ready              : out std_logic;
      in_valid                    : in  std_logic;
      in_ready                    : out std_logic;
      in_data                     : in  std_logic_vector(MAX_DELTAS_PER_CYCLE*PRIM_WIDTH-1 downto 0);
      in_count                    : in  std_logic_vector(log2floor(MAX_DELTAS_PER_CYCLE) downto 0);
      fv_valid                    : in  std_logic;
      fv_ready                    : out std_logic;
      fv_data                     : in  std_logic_vector(PRIM_WIDTH-1 downto 0);
      md_valid                    : in  std_logic;
      md_ready                    : out std_logic;
      md_data                     : in  std_logic_vector(PRIM_WIDTH-1 downto 0);
      nc_valid                    : out std_logic;
      nc_ready                    : in  std_logic := '1';
      nc_last                     : out std_logic;
      nc_data                     : out std_logic_vector(31 downto 0);
      out_valid                   : out std_logic;
      out_ready                   : in  std_logic;
      out_last                    : out std_logic;
      out_count                   : out std_logic_vector(log2floor(MAX_DELTAS_PER_CYCLE) downto 0);
      out_data                    : out std_logic_vector(MAX_DELTAS_PER_CYCLE*PRIM_WIDTH-1 downto 0)
    );
  end component;

  component CharBuffer is
    generic (
      BUS_DATA_WIDTH              : natural;
      CHARS_PER_CYCLE             : natural;
      BYTES_IN_BLOCK_WIDTH        : natural;
      RAM_CONFIG                  : string := ""
    );
    port (
      clk                         : in  std_logic;
      reset                       : in  std_logic;
      lengths_processed           : in  std_logic;
      in_valid                    : in  std_logic;
      in_ready                    : out std_logic;
      in_last                     : in  std_logic;
      in_data                     : in  std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
      bc_valid                    : in  std_logic;
      bc_ready                    : out std_logic;
      bc_data                     : in  std_logic_vector(BYTES_IN_BLOCK_WIDTH-1 downto 0);
      nc_valid                    : in  std_logic;
      nc_ready                    : out std_logic;
      nc_last                     : in  std_logic;
      nc_data                     : in  std_logic_vector(31 downto 0);
      new_page_valid              : in  std_logic;
      new_page_ready              : out std_logic;
      out_valid                   : out std_logic;
      out_ready                   : in  std_logic;
      out_last                    : out std_logic;
      out_data                    : out std_logic_vector(log2ceil(CHARS_PER_CYCLE+1) + BUS_DATA_WIDTH - 1 downto 0)
    );
  end component;

  -----------------------------------------------------------------------------
  -- Helper functions
  -----------------------------------------------------------------------------
  type count_lut_64_t is array (0 to 64) of natural range 1 to 32;
  type count_lut_32_t is array (0 to 32) of natural range 1 to 32;

  type shift_lut_64_t is array (0 to 64) of natural;
  type shift_lut_32_t is array (0 to 32) of natural;

  type mask_lut_64_t is array (0 to 64) of std_logic_vector(63 downto 0);
  type mask_lut_32_t is array (0 to 32) of std_logic_vector(31 downto 0);

  -- These functions initialize the lut containing the amount of values to unpack per cycle for every bit packing width.
  -- For every bit width this amount needs to divide 32 (always a divisor of the amount of values in a miniblock) 
  -- without a remainder to ensure that after an x amount of cycles the entire miniblock has been unpacked without
  -- taking bits from the next miniblock.
  function init_count_lut_64(MAX_DELTAS_PER_CYCLE : natural; DEC_DATA_WIDTH : natural) return count_lut_64_t;
  function init_count_lut_32(MAX_DELTAS_PER_CYCLE : natural; DEC_DATA_WIDTH : natural) return count_lut_32_t;

  -- Initialize the luts containing the amount of bits to shift (count*width)
  function init_shift_lut_64(MAX_DELTAS_PER_CYCLE : natural; DEC_DATA_WIDTH : natural) return shift_lut_64_t;
  function init_shift_lut_32(MAX_DELTAS_PER_CYCLE : natural; DEC_DATA_WIDTH : natural) return shift_lut_32_t;

  -- Initialize the luts containing the masks for the BitUnpacker.
  function init_mask_lut_64 return mask_lut_64_t;
  function init_mask_lut_32 return mask_lut_32_t;

  -- Returns either a rounded down to the nearest power of 2 or 32 , whichever is smaller.
  function round_down_pow2(a : natural) return natural;

  -- Returns the amount of values unpacked per cycle for a certain width based on MAX_DELTAS and DATA_WIDTH
  function unpacking_count(width : natural; MAX_DELTAS_PER_CYCLE : natural; DEC_DATA_WIDTH : natural) return natural;
end Delta;

package body Delta is

  function round_down_pow2(a : natural) return natural is
  begin
    return imin(2 ** log2floor(a), 32);
  end function;

  function unpacking_count(width : natural; MAX_DELTAS_PER_CYCLE : natural; DEC_DATA_WIDTH : natural) return natural is
  begin
    if width = 0 then
      return MAX_DELTAS_PER_CYCLE;
    else
      return imin(MAX_DELTAS_PER_CYCLE, round_down_pow2(natural(FLOOR(real(DEC_DATA_WIDTH)/real(width)))));
    end if;
  end function;

  function init_count_lut_32(MAX_DELTAS_PER_CYCLE : natural; DEC_DATA_WIDTH : natural) return count_lut_32_t is
    variable result : count_lut_32_t;
  begin
    for i in 0 to 32 loop
      result(i) := unpacking_count(i, MAX_DELTAS_PER_CYCLE, DEC_DATA_WIDTH);
    end loop;

    return result;
  end function;

  function init_count_lut_64(MAX_DELTAS_PER_CYCLE : natural; DEC_DATA_WIDTH : natural) return count_lut_64_t is
    variable result : count_lut_64_t;
  begin
    for i in 0 to 64 loop
      result(i) := unpacking_count(i, MAX_DELTAS_PER_CYCLE, DEC_DATA_WIDTH);
    end loop;

    return result;
  end function;

  function init_shift_lut_32(MAX_DELTAS_PER_CYCLE : natural; DEC_DATA_WIDTH : natural) return shift_lut_32_t is
    variable result : shift_lut_32_t;
  begin
    for i in 0 to 32 loop
      result(i) := unpacking_count(i, MAX_DELTAS_PER_CYCLE, DEC_DATA_WIDTH) * i;
    end loop;

    return result;
  end function;

  function init_shift_lut_64(MAX_DELTAS_PER_CYCLE : natural; DEC_DATA_WIDTH : natural) return shift_lut_64_t is
    variable result : shift_lut_64_t;
  begin
    for i in 0 to 64 loop
      result(i) := unpacking_count(i, MAX_DELTAS_PER_CYCLE, DEC_DATA_WIDTH) * i;
    end loop;

    return result;
  end function;

  function init_mask_lut_64 return mask_lut_64_t is
    variable result : mask_lut_64_t;
  begin
    result(0) := (others => '0');
    for i in 0 to 63 loop
      result(i+1) := std_logic_vector(unsigned(result(i)) + shift_left(to_unsigned(1, 64), i));
    end loop;

    return result;
  end function;

  function init_mask_lut_32 return mask_lut_32_t is
    variable result : mask_lut_32_t;
  begin
    result(0) := (others => '0');
    for i in 0 to 31 loop
      result(i+1) := std_logic_vector(unsigned(result(i)) + shift_left(to_unsigned(1, 32), i));
    end loop;

    return result;
  end function;



end Delta;