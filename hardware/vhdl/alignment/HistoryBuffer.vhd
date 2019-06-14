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
-- Include Fletcher Utils for use of the 1-read 1-write RAM
use work.UtilInt_pkg.all;
use work.UtilRam_pkg.all;

-- Stream data into this buffer for possible later re-use. At any point the HistoryBuffer can be signaled to start rewind mode via start_rewind, in which case it will transmit
-- all of its content to the output stream. The end of rewind mode is signaled by asserting end_rewind when this unit has determined that there is nothing left to output.
-- If delete_oldest is high at the rising edge of clk the oldest entry in the history buffer will be invalidated.
--
-- Warning: this unit does not check for buffer overflow. Any hardware that uses the HistoryBuffer should make sure that it never streams more data into the HistoryBuffer than
-- the size of the buffer allows without deleting older entries.

entity HistoryBuffer is
  generic (
    -- Bus data width
    BUS_DATA_WIDTH              : natural := 512;

    -- Depth of RAM needed (as log2 of needed depth)
    DEPTH_LOG2                  : natural := 5
  );
  port (

    -- Rising-edge sensitive clock.
    clk                         : in  std_logic;

    -- Active-high synchronous reset.
    reset                       : in  std_logic;

    -- Stream data in
    in_valid                    : in  std_logic;
    in_ready                    : out std_logic;
    in_data                     : in  std_logic_vector(BUS_DATA_WIDTH-1 downto 0);

    -- Stream data out
    out_valid                   : out std_logic;
    out_ready                   : in  std_logic;
    out_data                    : out std_logic_vector(BUS_DATA_WIDTH-1 downto 0);

    -- Signals used to signal the start and end of a realignment phase
    start_rewind                : in  std_logic;
    end_rewind                  : out std_logic;

    -- Synchronous clear of the oldest record in the history buffer
    delete_oldest               : in  std_logic
  );
end HistoryBuffer;

architecture behv of HistoryBuffer is
  -- The buffer can work in two operational modes: standard or rewind
  type state_t is (STANDARD, REWIND);
      signal state, state_next : state_t;

  -- Points to RAM address that contains the oldest still valid entry (this is where we start reading in case of a rewind)
  signal oldest_valid_ptr       : std_logic_vector(DEPTH_LOG2-1 downto 0);
  signal oldest_valid_ptr_next  : std_logic_vector(DEPTH_LOG2-1 downto 0);

  signal write_ptr              : std_logic_vector(DEPTH_LOG2-1 downto 0);
  signal write_ptr_next         : std_logic_vector(DEPTH_LOG2-1 downto 0);

  -- Unlike write_ptr and oldest_valid_ptr, read_ptr is a combinatorial signal. This is to ensure we don't have to wait a clock cycle for the RAM to produce useful data.
  signal read_ptr               : std_logic_vector(DEPTH_LOG2-1 downto 0);
  -- This signal always contains the value read_ptr had the clock cycle before this one.
  signal read_ptr_prev          : std_logic_vector(DEPTH_LOG2-1 downto 0);

  -- This signal is always read_ptr_prev + 1
  signal read_ptr_prev_inc      : std_logic_vector(DEPTH_LOG2-1 downto 0);
  -- This signal is always oldest_valid_ptr + 1
  signal oldest_valid_ptr_inc   : std_logic_vector(DEPTH_LOG2-1 downto 0);

  signal write_enable           : std_logic;

  signal s_out_valid            : std_logic;  

  --pragma translate_off
  shared variable DEBUG_ENTRY_COUNT      : integer := 0;
  shared variable DEBUG_ENTRY_COUNT_INC  : boolean := false;
  shared variable DEBUG_ENTRY_COUNT_DEC  : boolean := false;
  --pragma translate_on

begin
  ram_inst: UtilRam1R1W
    generic map(
      WIDTH           => BUS_DATA_WIDTH,
      DEPTH_LOG2      => DEPTH_LOG2
    )
    port map(
      w_clk           => clk,
      w_ena           => write_enable,
      w_addr          => write_ptr,
      w_data          => in_data,
      r_clk           => clk,
      r_ena           => '1',
      r_addr          => read_ptr,
      r_data          => out_data
    );

  out_valid <= s_out_valid;
  read_ptr_prev_inc <= std_logic_vector(unsigned(read_ptr_prev) + 1);
  oldest_valid_ptr_inc <= std_logic_vector(unsigned(oldest_valid_ptr) + 1);

  logic_p: process(start_rewind, in_valid, in_data, delete_oldest, write_ptr, oldest_valid_ptr, state, read_ptr, s_out_valid, read_ptr_prev, 
                   read_ptr_prev_inc, oldest_valid_ptr_inc, out_ready)
  begin
    state_next <= state;
    write_ptr_next <= write_ptr;
    oldest_valid_ptr_next <= oldest_valid_ptr;
    
    -- End_rewind is only '0' when in the HistoryBuffer is in REWIND state in the current and the next cycle.
    end_rewind <= '1';
    write_enable <= '0';

    read_ptr <= oldest_valid_ptr;

    -- pragma translate_off
    DEBUG_ENTRY_COUNT_INC := false;
    DEBUG_ENTRY_COUNT_DEC := false;
    -- pragma translate_on
    
    -- No matter what state we are in, delete_oldest can always invalidate an entry in the RAM.
    if delete_oldest = '1' then
      oldest_valid_ptr_next <= oldest_valid_ptr_inc;

      --pragma translate_off
      DEBUG_ENTRY_COUNT_DEC := true;
      --pragma translate_on
    end if;

    case state is
      when STANDARD =>
        -- In standard mode, the history buffer will simply write data offered at its data_in port to the RAM
        -- If delete_oldest is '1' at the rising edge of clk, the oldest entry in the history buffer will be invalidated
        in_ready <= '1';
        s_out_valid <= '0';
  
        if in_valid = '1' then
          write_enable <= '1';
          write_ptr_next <= std_logic_vector(unsigned(write_ptr) + 1);

          --pragma translate_off
          DEBUG_ENTRY_COUNT_INC := true;
          --pragma translate_on
        end if;
  
        if start_rewind = '1' then
          state_next <= REWIND;

          -- If the oldest entry gets deleted in the same cycle as a switch to REWIND, we need to make sure that entry does not get read from RAM in the next cycle
          if delete_oldest = '1' then
            read_ptr <= oldest_valid_ptr_inc;

            -- Buffer is empty
            if oldest_valid_ptr_inc = write_ptr then
              state_next <= STANDARD;
            end if;
          end if;
        end if;
  
      when REWIND =>
        -- In rewind mode the history buffer will not write data to the RAM. Instead it will offer all its stored data on its data out port.
        -- Once the entire history buffer has been read it will revert to standard mode.
        in_ready <= '0';
        s_out_valid <= '1';
        end_rewind <= '0';

        if start_rewind = '1' then
          -- start_rewind signals a restart of the REWIND state, set read_ptr to oldest entry
          read_ptr <= oldest_valid_ptr;

          -- If the oldest entry gets deleted in the same cycle as a switch to REWIND, we need to make sure that entry does not get read from RAM in the next cycle
          if delete_oldest = '1' then
            read_ptr <= oldest_valid_ptr_inc;
          end if;
        elsif out_ready = '1' then
          -- The output is ready so next cycle we can present new data on the output
          read_ptr <= read_ptr_prev_inc;

          -- If the next read_ptr would be equal to the write_ptr the entire history has been read, so we return to standard operation.
          if read_ptr_prev_inc = write_ptr then
            end_rewind <= '1';
            state_next <= STANDARD;
          end if;
        else
          read_ptr <= read_ptr_prev;
        end if;
    end case;

  end process;

  state_p: process(clk)
  begin
    if rising_edge(clk) then
      if reset = '1' then
        oldest_valid_ptr <= (others => '0');
        write_ptr <= (others => '0');
        state <= STANDARD;

        --pragma translate_off
        DEBUG_ENTRY_COUNT     := 0;
        --pragma translate_on
      else
        state <= state_next;
        oldest_valid_ptr <= oldest_valid_ptr_next;
        write_ptr <= write_ptr_next;

        --pragma translate_off
        if DEBUG_ENTRY_COUNT_INC then
          DEBUG_ENTRY_COUNT := DEBUG_ENTRY_COUNT + 1;
        end if;

        if DEBUG_ENTRY_COUNT_DEC then
          DEBUG_ENTRY_COUNT := DEBUG_ENTRY_COUNT - 1;
        end if;
        --pragma translate_on
      end if;

      read_ptr_prev <= read_ptr;

      --pragma translate_off
      assert DEBUG_ENTRY_COUNT >= 0
        report "HistoryBuffer underflow." severity failure;
  
      assert DEBUG_ENTRY_COUNT <= 2**DEPTH_LOG2
        report "HistoryBuffer overflow." severity failure;
      --pragma translate_on
    end if;
  end process;

end architecture;