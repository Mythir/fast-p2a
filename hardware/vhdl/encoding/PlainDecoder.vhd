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
use work.Utils.all;

-- Todo: description
-- Todo: implement out_last

entity PlainDecoder is
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

    ctrl_done                   : out std_logic;

    -- Data in stream from Decompressor
    in_valid                    : in  std_logic;
    in_ready                    : out std_logic;
    in_data                     : in  std_logic_vector(BUS_DATA_WIDTH-1 downto 0);

    -- Handshake signaling start of new page
    new_page_valid              : in  std_logic;
    new_page_ready              : out std_logic;

    -- Total number of requested values (from host)
    total_num_values            : in  std_logic_vector(31 downto 0);

    -- Number of values in the page (from MetadataInterpreter)
    page_num_values             : in  std_logic_vector(31 downto 0);

    --Data out stream to Fletcher ColumnWriter
    out_valid                   : out std_logic;
    out_ready                   : in  std_logic;
    out_last                    : out std_logic;
    out_dvalid                  : out std_logic := '1';
    out_data                    : out std_logic_vector(BUS_DATA_WIDTH-1 downto 0)
  );
end PlainDecoder;

architecture behv of PlainDecoder is
  -- The amount of values transferred to the ColumnWriter every cycle
  constant ELEMENTS_PER_CYCLE : natural := BUS_DATA_WIDTH/PRIM_WIDTH;

  type state_t is (IDLE, IN_PAGE, PAGE_END, FINAL_TRANSFER, DONE);

  type reg_record is record 
    state             : state_t;
    page_val_counter  : unsigned(31 downto 0);
    total_val_counter : unsigned(31 downto 0);
    m_page_num_values : unsigned(31 downto 0);
    val_reg_count     : integer range 0 to ELEMENTS_PER_CYCLE-1;
    val_reg           : std_logic_vector((ELEMENTS_PER_CYCLE-1)*PRIM_WIDTH-1 downto 0);
  end record;

  signal r : reg_record;
  signal d : reg_record;

  -- Signal with in_data in correct byte order
  signal s_in_data : std_logic_vector(BUS_DATA_WIDTH-1 downto 0);

  -- Out_last internal copy
  signal s_out_last : std_logic;
begin

  s_in_data <= endian_swap(in_data);
  out_last <= s_out_last;

  logic_p: process(r, page_num_values, total_num_values, in_valid, out_ready, in_data, new_page_valid, s_out_last)
    variable v                      : reg_record;
    variable page_val_counter_inc   : unsigned(31 downto 0);
    variable new_val_reg_count      : unsigned(log2ceil((ELEMENTS_PER_CYCLE-1)*2) downto 0);
    variable new_total_val_counter  : unsigned (31 downto 0);
    variable new_state              : state_t;
    variable val_misalignment       : unsigned(log2ceil(ELEMENTS_PER_CYCLE)-1 downto 0);
  begin
    v := r;

    val_misalignment := r.m_page_num_values(log2ceil(ELEMENTS_PER_CYCLE)-1 downto 0);

    new_page_ready <= '0';
    in_ready <= '0';
    out_valid <= '0';
    out_data <= (others => '0');
    s_out_last <= '0';
    ctrl_done <= '0';

    page_val_counter_inc := r.page_val_counter + ELEMENTS_PER_CYCLE;

    case r.state is
      when IDLE =>
        new_page_ready <= '1';
        if new_page_valid = '1' then
          v.state             := IN_PAGE;
          v.m_page_num_values := unsigned(page_num_values);
          v.page_val_counter  := (others => '0');
        end if;

      when IN_PAGE =>
        if page_val_counter_inc > r.m_page_num_values then
          v.state := PAGE_END;
        else
          in_ready <= out_ready;
          out_valid <= in_valid;
          if page_val_counter_inc + r.total_val_counter > unsigned(total_num_values) then
            s_out_last <= '1';
          end if;


          if in_valid = '1' and out_ready = '1' then
            if r.val_reg_count = 0 then
              out_data <= in_data;
            else
              out_data <= in_data(PRIM_WIDTH*(ELEMENTS_PER_CYCLE-r.val_reg_count)-1 downto 0) & r.val_reg(PRIM_WIDTH*r.val_reg_count-1 downto 0);
              v.val_reg(PRIM_WIDTH*r.val_reg_count-1 downto 0) := in_data(BUS_DATA_WIDTH-1 downto PRIM_WIDTH*(ELEMENTS_PER_CYCLE-r.val_reg_count));
            end if;
  
            if s_out_last = '1' then
              v.state := DONE;
            else
              v.page_val_counter := page_val_counter_inc;
            end if;
          end if;
        end if;

      when PAGE_END =>
        new_val_reg_count     := to_unsigned(r.val_reg_count, new_val_reg_count'length) + resize(val_misalignment, new_val_reg_count'length);
        new_total_val_counter := r.total_val_counter + r.m_page_num_values;
        if new_total_val_counter >= unsigned(total_num_values) then
          if to_integer(new_val_reg_count(val_misalignment'length-1 downto 0)) = 0 then
            new_state := DONE;
          else
            new_state := FINAL_TRANSFER;
          end if;
        else
          new_state := IDLE;
        end if;

        if new_val_reg_count > (ELEMENTS_PER_CYCLE-1) then
          --report "Page end. Misalignment overflow" severity note;
          in_ready <= out_ready;
          out_valid <= in_valid;
          if new_state = DONE then
            s_out_last <= '1';
          end if;

          if in_valid = '1' and out_ready = '1' then
            v.val_reg_count     := to_integer(new_val_reg_count(val_misalignment'length-1 downto 0));
            v.total_val_counter := new_total_val_counter;
            out_data <= in_data(PRIM_WIDTH*(ELEMENTS_PER_CYCLE-r.val_reg_count)-1 downto 0) & r.val_reg(PRIM_WIDTH*r.val_reg_count-1 downto 0);
            v.val_reg(PRIM_WIDTH*v.val_reg_count-1 downto 0) := in_data(PRIM_WIDTH*to_integer(val_misalignment)-1 downto PRIM_WIDTH*(ELEMENTS_PER_CYCLE-r.val_reg_count));
            v.state := new_state;
          end if;
        elsif new_val_reg_count > r.val_reg_count then
          --report "Page end. Misalignment increased" severity note;
          in_ready <= '1';
          if in_valid = '1' then
            v.val_reg_count     := to_integer(new_val_reg_count(val_misalignment'length-1 downto 0));
            v.total_val_counter := new_total_val_counter;
            v.val_reg(PRIM_WIDTH*v.val_reg_count-1 downto PRIM_WIDTH*r.val_reg_count) := in_data(PRIM_WIDTH*to_integer(val_misalignment)-1 downto 0);
            v.state := new_state;
          end if;          
        else
          --report "Page end. Misalignment unchanged" severity note;
          v.val_reg_count     := to_integer(new_val_reg_count(val_misalignment'length-1 downto 0));
          v.total_val_counter := new_total_val_counter;
          v.state := new_state;
        end if;

      when FINAL_TRANSFER =>
        if r.val_reg_count > 0 then
          out_valid <= '1';
          s_out_last <= '1';
          out_data(r.val_reg'length-1 downto 0) <= r.val_reg;
          if out_ready = '1' then
            v.state := DONE;
          end if;
        else
          v.state := DONE;
        end if;

      when DONE =>
        ctrl_done <= '1';


    end case;

    d <= v;
  end process;

  clk_p: process (clk)
  begin
    if rising_edge(clk) then
      if reset = '1' then
        r.state             <= IDLE;
        r.page_val_counter  <= (others => '0');
        r.total_val_counter <= (others => '0');
        r.val_reg_count       <= 0;
      else
        r <= d;
      end if;
    end if;
  end process;

end architecture;