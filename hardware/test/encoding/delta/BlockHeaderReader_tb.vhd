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
-- Fletcher utils for use of log2ceil function.
use work.UtilInt_pkg.all;
use work.Ptoa.all;
use work.Encoding.all;

entity BlockHeaderReader_tb is
end BlockHeaderReader_tb;

architecture tb of BlockHeaderReader_tb is
  constant DEC_DATA_WIDTH            : natural := 32;
  constant BLOCK_SIZE                : natural := 128;
  constant MINIBLOCKS_IN_BLOCK       : natural := 4;
  constant BYTES_IN_BLOCK_WIDTH      : natural := 16;
  constant FIFO_DEPTH                : natural := 5; --log(32)
  constant PRIM_WIDTH                : natural := 32;
  constant VALUES_TO_READ            : natural := 5000;
  constant clk_period                : time := 10 ns;

  signal clk                         : std_logic;
  signal reset                       : std_logic;
  signal page_done                   : std_logic;
  signal in_valid                    : std_logic;
  signal in_ready                    : std_logic;
  signal in_data                     : std_logic_vector(DEC_DATA_WIDTH-1 downto 0);
  signal page_num_values             : std_logic_vector(31 downto 0) := std_logic_vector(to_unsigned(VALUES_TO_READ, 32));
  signal md_valid                    : std_logic;
  signal md_ready                    : std_logic;
  signal md_data                     : std_logic_vector(PRIM_WIDTH-1 downto 0);
  signal bw_valid                    : std_logic;
  signal bw_ready                    : std_logic;
  signal bw_data                     : std_logic_vector(7 downto 0);
  signal bl_valid                    : std_logic;
  signal bl_ready                    : std_logic;
  signal bl_data                     : std_logic_vector(log2floor(max_varint_bytes(PRIM_WIDTH)+MINIBLOCKS_IN_BLOCK) downto 0);
  signal bc_valid                    : std_logic;
  signal bc_ready                    : std_logic;
  signal bc_data                     : std_logic_vector(BYTES_IN_BLOCK_WIDTH-1 downto 0);

  -- Signals for checking the values read from these streams
  signal consumed_md                 : std_logic_vector(md_data'length-1 downto 0);
  signal consumed_bw                 : std_logic_vector(bw_data'length-1 downto 0);
  signal consumed_bl                 : std_logic_vector(bl_data'length-1 downto 0);
  signal consumed_bc                 : std_logic_vector(bc_data'length-1 downto 0);
begin
  dut: entity work.BlockHeaderReader
    generic map(
      DEC_DATA_WIDTH              => DEC_DATA_WIDTH,
      BLOCK_SIZE                  => BLOCK_SIZE,
      MINIBLOCKS_IN_BLOCK         => MINIBLOCKS_IN_BLOCK,
      BYTES_IN_BLOCK_WIDTH        => BYTES_IN_BLOCK_WIDTH,
      FIFO_DEPTH                  => FIFO_DEPTH,
      PRIM_WIDTH                  => PRIM_WIDTH
    )
    port map(
      clk                         => clk,
      reset                       => reset,
      page_done                   => page_done,
      in_valid                    => in_valid,
      in_ready                    => in_ready,
      in_data                     => in_data,
      page_num_values             => page_num_values,
      md_valid                    => md_valid,
      md_ready                    => md_ready,
      md_data                     => md_data,
      bw_valid                    => bw_valid,
      bw_ready                    => bw_ready,
      bw_data                     => bw_data,
      bl_valid                    => bl_valid,
      bl_ready                    => bl_ready,
      bl_data                     => bl_data,
      bc_valid                    => bc_valid,
      bc_ready                    => bc_ready,
      bc_data                     => bc_data
    );

  upstream_p: process
    file input_data             : text;

    constant stream_stop_p      : real    := 0.01;
    constant max_stopped_cycles : real    := 30.0;

    variable input_line         : line;
    variable page_data          : std_logic_vector(DEC_DATA_WIDTH-1 downto 0);

    variable seed1              : positive := 137;
    variable seed2              : positive := 442;

    variable stream_stop        : real;
    variable num_stopped_cycles : real;
  begin
    file_open(input_data, "./test/encoding/delta/full.hex1", read_mode);
    in_valid <= '0';

    loop
      wait until rising_edge(clk);
      exit when reset = '0';
    end loop;

    while not endfile(input_data) loop
      readline(input_data, input_line);
      hread(input_line, page_data);

      in_valid <= '1';
      in_data <= page_data;

      loop 
        wait until rising_edge(clk);
        exit when in_ready = '1';
      end loop;

      in_valid <= '0';

      -- Delay for a random amount of clock cycles to simulate a non-continuous stream
      uniform(seed1, seed2, stream_stop);
      if stream_stop < stream_stop_p then
        uniform(seed1, seed2, num_stopped_cycles);
        for i in 0 to integer(floor(num_stopped_cycles*max_stopped_cycles)) loop
          wait until rising_edge(clk);
        end loop;
      end if;
    end loop;

    report "full.hex1 has been fully read";

    wait;
  end process;

  -- Processes for checking the values read from the metadata
  md_consumer_p: process
    file input_data             : text;

    constant stream_stop_p      : real    := 0.05;
    constant max_stopped_cycles : real    := 10.0;

    variable input_line         : line;
    variable page_data          : std_logic_vector(DEC_DATA_WIDTH-1 downto 0);

    variable seed1              : positive := 137;
    variable seed2              : positive := 442;

    variable stream_stop        : real;
    variable num_stopped_cycles : real;
  begin
    md_ready <= '0';

    loop
      wait until rising_edge(clk);
      exit when reset = '0';
    end loop;

    loop
      md_ready <= '1';

      loop
        wait until rising_edge(clk);
        exit when md_valid = '1';
      end loop;

      md_ready <= '0';
      consumed_md <= md_data;

      -- Delay for a random amount of clock cycles to simulate a non-continuous stream
      uniform(seed1, seed2, stream_stop);
      if stream_stop < stream_stop_p then
        uniform(seed1, seed2, num_stopped_cycles);
        for i in 0 to integer(floor(num_stopped_cycles*max_stopped_cycles)) loop
          wait until rising_edge(clk);
        end loop;
      end if;
    end loop;
    wait;
  end process;

  bw_consumer_p: process
    file input_data             : text;

    constant stream_stop_p      : real    := 0.05;
    constant max_stopped_cycles : real    := 10.0;

    variable input_line         : line;
    variable page_data          : std_logic_vector(DEC_DATA_WIDTH-1 downto 0);

    variable seed1              : positive := 137;
    variable seed2              : positive := 442;

    variable stream_stop        : real;
    variable num_stopped_cycles : real;
  begin
    bw_ready <= '0';

    loop
      wait until rising_edge(clk);
      exit when reset = '0';
    end loop;

    loop
      bw_ready <= '1';

      loop
        wait until rising_edge(clk);
        exit when bw_valid = '1';
      end loop;

      bw_ready <= '0';
      consumed_bw <= bw_data;

      wait for 1 ns;
      assert unsigned(consumed_bw) <= PRIM_WIDTH
        report "Decoded bit width larger than provided PRIM_WIDTH" severity failure;

      -- Delay for a random amount of clock cycles to simulate a non-continuous stream
      uniform(seed1, seed2, stream_stop);
      if stream_stop < stream_stop_p then
        uniform(seed1, seed2, num_stopped_cycles);
        for i in 0 to integer(floor(num_stopped_cycles*max_stopped_cycles)) loop
          wait until rising_edge(clk);
        end loop;
      end if;
    end loop;
    wait;
  end process;

  bl_consumer_p: process
    file input_data             : text;

    constant stream_stop_p      : real    := 0.05;
    constant max_stopped_cycles : real    := 10.0;

    variable input_line         : line;
    variable page_data          : std_logic_vector(DEC_DATA_WIDTH-1 downto 0);

    variable seed1              : positive := 137;
    variable seed2              : positive := 442;

    variable stream_stop        : real;
    variable num_stopped_cycles : real;
  begin
    bl_ready <= '0';

    loop
      wait until rising_edge(clk);
      exit when reset = '0';
    end loop;

    loop
      bl_ready <= '1';

      loop
        wait until rising_edge(clk);
        exit when bl_valid = '1';
      end loop;

      bl_ready <= '0';
      consumed_bl <= bl_data;

      wait for 1 ns;
      assert unsigned(consumed_bl) = resize(unsigned(consumed_bc), consumed_bl'length)
        report "BL stream and BC stream disagree on block header length" severity failure;

      -- Delay for a random amount of clock cycles to simulate a non-continuous stream
      uniform(seed1, seed2, stream_stop);
      if stream_stop < stream_stop_p then
        uniform(seed1, seed2, num_stopped_cycles);
        for i in 0 to integer(floor(num_stopped_cycles*max_stopped_cycles)) loop
          wait until rising_edge(clk);
        end loop;
      end if;
    end loop;
    wait;
  end process;

  bc_consumer_p: process
    file input_data             : text;

    constant stream_stop_p      : real    := 0.05;
    constant max_stopped_cycles : real    := 10.0;

    variable input_line         : line;
    variable page_data          : std_logic_vector(DEC_DATA_WIDTH-1 downto 0);

    variable seed1              : positive := 137;
    variable seed2              : positive := 442;

    variable stream_stop        : real;
    variable num_stopped_cycles : real;
  begin
    bc_ready <= '0';

    loop
      wait until rising_edge(clk);
      exit when reset = '0';
    end loop;

    loop
      bc_ready <= '1';

      loop
        wait until rising_edge(clk);
        exit when bc_valid = '1';
      end loop;

      bc_ready <= '0';
      consumed_bc <= bc_data;

      -- Delay for a random amount of clock cycles to simulate a non-continuous stream
      uniform(seed1, seed2, stream_stop);
      if stream_stop < stream_stop_p then
        uniform(seed1, seed2, num_stopped_cycles);
        for i in 0 to integer(floor(num_stopped_cycles*max_stopped_cycles)) loop
          wait until rising_edge(clk);
        end loop;
      end if;
    end loop;
    wait;
  end process;

  clk_p : process
  begin
    clk <= '0';
    wait for clk_period/2;
    clk <= '1';
    wait for clk_period/2;
  end process;

  reset_p : process is
  begin
    reset <= '1';
    wait for 20 ns;
    wait until rising_edge(clk);
    reset <= '0';
    wait;
  end process;

end architecture;