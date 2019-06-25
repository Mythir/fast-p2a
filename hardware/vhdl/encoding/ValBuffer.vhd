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
-- Fletcher utils for use of log2ceil function.
use work.UtilInt_pkg.all;

-- The ValBuffer can take a variable (determined by in_count) amount of values per cycle on its input. Once it has accumulated BUS_DATA_WIDTH/PRIM_WIDTH values
-- it will offer those values at its output. If in_last is ever asserted the ValBuffer will output all values it has stored (even if this requires sending an incomplete
-- final bus word). After this the ValBuffer will have to be reset if it needs to be used again. The ValBuffer can buffer a maximum of 4*BUS_DATA_WIDTH/PRIM_WIDTH
-- values at a time.

entity ValBuffer is
  generic (
    -- Bus data width
    BUS_DATA_WIDTH              : natural;

    -- Bit width of a single primitive value
    PRIM_WIDTH                  : natural
  );
  port (
    -- Rising-edge sensitive clock.
    clk                         : in  std_logic;

    -- Active-high synchronous reset.
    reset                       : in  std_logic;

    -- Data in stream from Decompressor
    in_valid                    : in  std_logic;
    in_ready                    : out std_logic;
    in_count                    : in  std_logic_vector(log2floor(BUS_DATA_WIDTH/PRIM_WIDTH) downto 0);
    in_last                     : in  std_logic;
    in_data                     : in  std_logic_vector(BUS_DATA_WIDTH-1 downto 0);

    --Data out stream
    out_valid                   : out std_logic;
    out_ready                   : in  std_logic;
    out_last                    : out std_logic;
    out_data                    : out std_logic_vector(BUS_DATA_WIDTH-1 downto 0)
  );
end ValBuffer;

architecture behv of ValBuffer is
  -- The amount of values in a full bus word
  constant ELEMENTS_PER_CYCLE   : natural := BUS_DATA_WIDTH/PRIM_WIDTH;
  -- Amount of values that can be in the buffer
  constant VAL_CAPACITY         : natural := ELEMENTS_PER_CYCLE*4;
  constant LOG2_VAL_CAPACITY    : natural := log2ceil(VAL_CAPACITY);

  type val_array is array (0 to VAL_CAPACITY-1) of std_logic_vector(PRIM_WIDTH-1 downto 0);
    signal mem : val_array;

  signal r_ptr        : unsigned(LOG2_VAL_CAPACITY downto 0);
  signal scaled_r_ptr : unsigned(1 downto 0);
  signal w_ptr        : unsigned(LOG2_VAL_CAPACITY downto 0);

  signal val_count          : unsigned(LOG2_VAL_CAPACITY downto 0);
  signal is_full            : std_logic;
  signal full_bw_available  : std_logic;
  signal final_bw_available : std_logic;
  signal r_out_last         : std_logic;

begin
  val_count           <=  w_ptr(LOG2_VAL_CAPACITY downto 0) - r_ptr(LOG2_VAL_CAPACITY downto 0);
  is_full             <= '1' when val_count > to_unsigned(VAL_CAPACITY-ELEMENTS_PER_CYCLE, val_count'length)
                             else '0';
  full_bw_available   <= '1' when val_count >= to_unsigned(ELEMENTS_PER_CYCLE, val_count'length)
                             else '0';
  final_bw_available  <= '1' when (val_count > to_unsigned(0, val_count'length)) and (r_out_last = '1') and (val_count <= to_unsigned(ELEMENTS_PER_CYCLE, val_count'length))
                             else '0';
  scaled_r_ptr <= r_ptr(log2ceil(ELEMENTS_PER_CYCLE)+1 downto log2ceil(ELEMENTS_PER_CYCLE));

  in_ready  <= not is_full;
  out_valid <= full_bw_available or final_bw_available;
  out_last  <= final_bw_available;

  out_data_p: process(mem, scaled_r_ptr)
  begin
    case scaled_r_ptr is
      when "00" =>
        for j in 0 to ELEMENTS_PER_CYCLE-1 loop
          out_data(PRIM_WIDTH*(j+1)-1 downto PRIM_WIDTH*j) <= mem(j);
        end loop;
      when "01" =>
        for j in 0 to ELEMENTS_PER_CYCLE-1 loop
          out_data(PRIM_WIDTH*(j+1)-1 downto PRIM_WIDTH*j) <= mem(j+ELEMENTS_PER_CYCLE);
        end loop;
      when "10" =>
        for j in 0 to ELEMENTS_PER_CYCLE-1 loop
          out_data(PRIM_WIDTH*(j+1)-1 downto PRIM_WIDTH*j) <= mem(j+ELEMENTS_PER_CYCLE*2);
        end loop;
      when "11" =>
        for j in 0 to ELEMENTS_PER_CYCLE-1 loop
          out_data(PRIM_WIDTH*(j+1)-1 downto PRIM_WIDTH*j) <= mem(j+ELEMENTS_PER_CYCLE*3);
        end loop;
      when others =>
        out_data <= (others => '0');
    end case;
  end process;


  write_p: process(clk)
  begin
    if rising_edge(clk) then
      if in_valid = '1' and is_full = '0' then
        for i in 0 to VAL_CAPACITY-1 loop
          for j in 0 to ELEMENTS_PER_CYCLE-1 loop
            if (w_ptr(LOG2_VAL_CAPACITY-1 downto 0) + j = i) and (j < unsigned(in_count)) then
              mem(i) <= in_data(PRIM_WIDTH*(j+1)-1 downto PRIM_WIDTH*j);
            end if;
          end loop;
        end loop;
        w_ptr <= w_ptr + unsigned(in_count);

        if in_last = '1' then
          r_out_last <= '1';
        end if;
      end if;

      if reset = '1' then
        w_ptr <= (others => '0');
        r_out_last <= '0';
      end if;
    end if;
  end process;

  read_p: process(clk)
  begin
    if rising_edge(clk) then
      if reset = '1' then
        r_ptr <= (others => '0');
      elsif full_bw_available = '1' and out_ready = '1' then
        r_ptr <= r_ptr + ELEMENTS_PER_CYCLE;
      elsif final_bw_available = '1' and out_ready = '1' then
        r_ptr <= w_ptr;
      end if;
    end if;
  end process;

end architecture;