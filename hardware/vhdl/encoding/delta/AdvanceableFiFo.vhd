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
use work.Utils.all;

entity AdvanceableFiFo is
  generic (
    -- Data width
    DATA_WIDTH              : natural;

    -- FIFO depth represented as log2(depth).
    DEPTH_LOG2              : natural;

    -- RAM configuration string
    RAM_CONFIG              : string := ""
  );
  port (
    -- Rising-edge sensitive clock.
    clk                         : in  std_logic;

    -- Active-high synchronous reset.
    reset                       : in  std_logic;

    -- Data in stream
    in_valid                    : in  std_logic;
    in_ready                    : out std_logic;
    in_data                     : in  std_logic_vector(DATA_WIDTH-1 downto 0);

    -- Data out stream
    out_valid                   : out std_logic;
    out_ready                   : in  std_logic;
    out_data                    : out std_logic_vector(DATA_WIDTH-1 downto 0);

    -- How many entries to delete
    adv_valid                   : in  std_logic;
    adv_ready                   : out std_logic := '1';
    adv_count                   : in  std_logic_vector(31 downto 0)
  );
end AdvanceableFiFo;

architecture behv of AdvanceableFiFo is

  constant CAPACITY             : natural := 2**DEPTH_LOG2;

  type reg_record is record
    write_ptr        : unsigned(DEPTH_LOG2 downto 0);
    read_ptr         : unsigned(DEPTH_LOG2 downto 0);
    entry_count      : signed(31 downto 0);
    read_valid       : std_logic;
  end record;

  signal r : reg_record;
  signal d : reg_record;

  signal write_enable           : std_logic;

  signal fifo_full              : std_logic;
  signal fifo_empty             : std_logic;

begin
  ram_inst: Ram1R1W
    generic map (
      WIDTH                     => DATA_WIDTH,
      DEPTH_LOG2                => DEPTH_LOG2,
      RAM_CONFIG                => RAM_CONFIG
    )
    port map (
      w_clk                     => clk,
      w_ena                     => write_enable,
      w_addr                    => std_logic_vector(r.write_ptr(DEPTH_LOG2-1 downto 0)),
      w_data                    => in_data,
      r_clk                     => clk,
      r_ena                     => '1',
      r_addr                    => std_logic_vector(d.read_ptr(DEPTH_LOG2-1 downto 0)),
      r_data                    => out_data
    );

  fifo_full <= '1' when
    (r.read_ptr(DEPTH_LOG2-1 downto 0) = r.write_ptr(DEPTH_LOG2-1 downto 0))
    and (r.read_ptr(DEPTH_LOG2) /= r.write_ptr(DEPTH_LOG2))
    else '0';

  fifo_empty <= '1' when r.write_ptr = r.read_ptr
    else '0';

  logic_p: process(r, in_valid, out_ready, adv_valid, adv_count, fifo_full, fifo_empty)
    variable v          : reg_record;
  begin
    v := r;

    in_ready  <= '0';
    out_valid <= '0';

    write_enable <= '0';

    if adv_valid = '1' then
      v.entry_count := signed(unsigned(r.entry_count) - unsigned(adv_count));

      if v.entry_count < 0 then
        v.read_ptr := r.write_ptr;
      else
        v.read_ptr := resize(r.read_ptr + unsigned(adv_count), v.read_ptr'length);
      end if;

    else
      in_ready <= not fifo_full;
      out_valid <= r.read_valid;
  
      if in_valid = '1' and fifo_full = '0' then
        if to_integer(r.entry_count) >= 0 then
          write_enable  <= '1';
          v.write_ptr   := r.write_ptr + 1;
        end if;
        v.entry_count := v.entry_count + 1;
      end if;
  
      if out_ready = '1' and r.read_valid = '1' then
        v.read_ptr    := r.read_ptr + 1;
        v.entry_count := v.entry_count - 1;
      end if;
    end if;

    if v.read_ptr /= r.write_ptr and fifo_empty = '0' then
      v.read_valid := '1';
    else
      v.read_valid := '0';
    end if;

    d <= v;
  end process;

  clk_p: process(clk)
  begin
    if rising_edge(clk) then
      if reset = '1' then
        r.write_ptr      <= (others => '0');
        r.read_ptr       <= (others => '0');
        r.entry_count    <= (others => '0');
        r.read_valid       <= '0';
      else
        r <= d;
      end if;
    end if;
  end process;

end architecture;