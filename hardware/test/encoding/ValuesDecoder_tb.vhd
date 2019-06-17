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
-- Fletcher utils for use of the log2ceil function
use work.UtilInt_pkg.all;
use work.ArrayConfig_pkg.all;
use work.ArrayConfigParse_pkg.all;

-- This testbench tests the ValuesDecoder in the case of a PLAIN encoding and UNCOMPRESSED compression_codec. Compatible testcase hex files are generated
-- by PlainDecoder_gen.py. The generated testcase simulates a Parquet file containing all integers 0 to total_num_values sorted from small to large.

entity ValuesDecoder_tb is
end ValuesDecoder_tb;

architecture tb of ValuesDecoder_tb is
  constant BUS_DATA_WIDTH       : natural := 512;
  constant PRIM_WIDTH           : natural := 64;
  constant TOTAL_NUM_VALUES     : natural := 9320;

  constant clk_period           : time    := 10 ns;

  constant BUS_ADDR_WIDTH            : natural := 64;
  constant INDEX_WIDTH               : natural := 32;
  constant MIN_INPUT_BUFFER_DEPTH    : natural := 32;
  constant CMD_TAG_WIDTH             : natural := 1;
  constant RAM_CONFIG                : string := "";
  constant CFG                       : string := "prim(64;epc=8)";
  constant ENCODING                  : string := "PLAIN";
  constant COMPRESSION_CODEC         : string := "UNCOMPRESSED";
  constant ELEMENTS_PER_CYCLE        : natural := parse_param(cfg, "epc", 1);
 
  signal clk                         : std_logic;
  signal reset                       : std_logic;
  signal ctrl_start                  : std_logic;
  signal ctrl_done                   : std_logic;
  signal in_valid                    : std_logic;
  signal in_ready                    : std_logic;
  signal in_data                     : std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
  signal compressed_size             : std_logic_vector(31 downto 0);
  signal uncompressed_size           : std_logic_vector(31 downto 0);
  signal page_num_values             : std_logic_vector(31 downto 0);
  signal values_buffer_addr          : std_logic_vector(BUS_ADDR_WIDTH-1 downto 0) := std_logic_vector(to_unsigned(42, BUS_ADDR_WIDTH));
  signal bc_data                     : std_logic_vector(log2ceil(BUS_DATA_WIDTH/8) downto 0);
  signal bc_ready                    : std_logic;
  signal bc_valid                    : std_logic;
  signal cmd_valid                   : std_logic;
  signal cmd_ready                   : std_logic;
  signal cmd_firstIdx                : std_logic_vector(INDEX_WIDTH-1 downto 0);
  signal cmd_lastIdx                 : std_logic_vector(INDEX_WIDTH-1 downto 0);
  signal cmd_ctrl                    : std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
  signal cmd_tag                     : std_logic_vector(CMD_TAG_WIDTH-1 downto 0) := (others => '0');
  signal unl_valid                   : std_logic;
  signal unl_ready                   : std_logic;
  signal unl_tag                     : std_logic_vector(CMD_TAG_WIDTH-1 downto 0);
  signal out_valid                   : std_logic_vector(arcfg_userCount(CFG)-1 downto 0);
  signal out_ready                   : std_logic_vector(arcfg_userCount(CFG)-1 downto 0);
  signal out_last                    : std_logic_vector(arcfg_userCount(CFG)-1 downto 0);
  signal out_dvalid                  : std_logic_vector(arcfg_userCount(CFG)-1 downto 0) := (others => '1');
  signal out_data                    : std_logic_vector(arcfg_userWidth(CFG, INDEX_WIDTH)-1 downto 0);
begin

  dut: entity work.ValuesDecoder
    generic map(
      BUS_DATA_WIDTH              => BUS_DATA_WIDTH,
      BUS_ADDR_WIDTH              => BUS_ADDR_WIDTH,
      INDEX_WIDTH                 => INDEX_WIDTH,
      MIN_INPUT_BUFFER_DEPTH      => 16,
      CMD_TAG_WIDTH               => CMD_TAG_WIDTH,
      CFG                         => CFG,
      ENCODING                    => ENCODING,
      COMPRESSION_CODEC           => COMPRESSION_CODEC,
      PRIM_WIDTH                  => PRIM_WIDTH
    )
    port map(
      clk                         => clk,
      reset                       => reset,
      ctrl_start                  => ctrl_start,
      ctrl_done                   => ctrl_done,
      in_valid                    => in_valid,
      in_ready                    => in_ready,
      in_data                     => in_data,
      compressed_size             => compressed_size,
      uncompressed_size           => uncompressed_size,
      total_num_values            => std_logic_vector(to_unsigned(TOTAL_NUM_VALUES, 32)),
      page_num_values             => page_num_values,
      values_buffer_addr          => values_buffer_addr,
      bc_data                     => bc_data,
      bc_ready                    => bc_ready,
      bc_valid                    => bc_valid,
      cmd_valid                   => cmd_valid,
      cmd_ready                   => cmd_ready,
      cmd_firstIdx                => cmd_firstIdx,
      cmd_lastIdx                 => cmd_lastIdx,
      cmd_ctrl                    => cmd_ctrl,
      cmd_tag                     => cmd_tag,
      unl_valid                   => unl_valid,
      unl_ready                   => unl_ready,
      unl_tag                     => unl_tag,
      out_valid                   => out_valid,
      out_ready                   => out_ready,
      out_last                    => out_last,
      out_dvalid                  => out_dvalid,
      out_data                    => out_data
    );

  dataaligner_p: process
    file input_data             : text;

    constant stream_stop_p      : real    := 0.05;
    constant max_stopped_cycles : real    := 50.0;

    variable input_line         : line;
    variable num_values         : std_logic_vector(31 downto 0);

    variable seed1              : positive := 1337;
    variable seed2              : positive := 4242;

    variable stream_stop        : real;
    variable num_stopped_cycles : real;

    variable bc_data_check      : natural;
  begin
    file_open(input_data, "./test/encoding/PageNumValues_input.hex", read_mode);
    page_num_values <= (others => '0');
    compressed_size <= (others => '0');
    uncompressed_size <= (others => '0');

    bc_ready <= '0';

    ctrl_start <= '0';

    loop
      wait until rising_edge(clk);
      exit when reset = '0';
    end loop;

    while not endfile(input_data) loop
      readline(input_data, input_line);
      hread(input_line, num_values);

      ctrl_start <= '1';
      bc_ready <= '1';
      page_num_values   <= num_values;
      compressed_size   <= std_logic_vector(resize(unsigned(num_values)*PRIM_WIDTH/8, compressed_size'length));
      uncompressed_size <= std_logic_vector(resize(unsigned(num_values)*PRIM_WIDTH/8, compressed_size'length));

      loop 
        wait until rising_edge(clk);
        exit when bc_valid = '1';
      end loop;

      bc_ready <= '0';

      bc_data_check := to_integer(unsigned(compressed_size) mod (BUS_DATA_WIDTH/8));
      if bc_data_check = 0 then
        bc_data_check := BUS_DATA_WIDTH/8;
      end if;

      assert to_integer(unsigned(bc_data)) = bc_data_check
        report "Incorrect bc_data from ValuesDecoder. Got " & integer'image(to_integer(unsigned(bc_data))) & " expected " & integer'image(bc_data_check) severity failure;
    end loop;

    report "All pages have been handshaked" severity note;

    wait;
  end process;

  data_p: process
    file input_data             : text;

    constant stream_stop_p      : real    := 0.05;
    constant max_stopped_cycles : real    := 10.0;

    variable input_line         : line;
    variable page_data          : std_logic_vector(BUS_DATA_WIDTH-1 downto 0);

    variable seed1              : positive := 137;
    variable seed2              : positive := 442;

    variable stream_stop        : real;
    variable num_stopped_cycles : real;
  begin
    file_open(input_data, "./test/encoding/PageData_input.hex", read_mode);
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

    report "PageData_input.hex has been fully read";

    wait;
  end process;

  check_p: process
    constant stream_stop_p      : real    := 0.05;
    constant max_stopped_cycles : real    := 10.0;

    variable counter            : natural := 0;
    variable read_data          : std_logic_vector(log2ceil(ELEMENTS_PER_CYCLE+1) + ELEMENTS_PER_CYCLE*PRIM_WIDTH - 1 downto 0);
    variable read_count         : unsigned(log2ceil(ELEMENTS_PER_CYCLE+1)-1 downto 0);
    variable read_values        : std_logic_vector(ELEMENTS_PER_CYCLE*PRIM_WIDTH - 1 downto 0);
    variable check_out_last     : std_logic;

    variable seed1              : positive := 1227;
    variable seed2              : positive := 4422;

    variable stream_stop        : real;
    variable num_stopped_cycles : real;
  begin
    cmd_ready <= '0';
    unl_valid <= '0';
    out_ready(0) <= '0';

    loop
      wait until rising_edge(clk);
      exit when reset = '0';
    end loop;

    cmd_ready <= '1';

    loop
      wait until rising_edge(clk);
      exit when cmd_valid = '1';
    end loop;

    cmd_ready <= '0';

    assert cmd_firstIdx = std_logic_vector(to_unsigned(0, cmd_firstIdx'length))
      report "cmd_firstIdx not 0" severity failure;

    assert cmd_lastIdx = std_logic_vector(to_unsigned(TOTAL_NUM_VALUES, 32))
      report "cmd_lastIdx not equal to total_num_values" severity failure;

    assert cmd_ctrl = values_buffer_addr
      report "cmd_ctrl not equal to values_buffer_addr" severity failure;

    loop
      out_ready(0) <= '1';
  
      loop
        wait until rising_edge(clk);
        exit when out_valid(0) = '1';
      end loop;
  
      out_ready(0) <= '0';

      read_data      := out_data;
      check_out_last := out_last(0);

      read_values    := read_data(ELEMENTS_PER_CYCLE*PRIM_WIDTH-1 downto 0);
      read_count     := unsigned(read_data(log2ceil(ELEMENTS_PER_CYCLE+1)+ELEMENTS_PER_CYCLE*PRIM_WIDTH-1 downto ELEMENTS_PER_CYCLE*PRIM_WIDTH));
  
      for i in 0 to to_integer(read_count)-1 loop
        assert read_values(PRIM_WIDTH*(i+1)-1 downto PRIM_WIDTH*i) = std_logic_vector(to_unsigned(counter, PRIM_WIDTH))
          report "Incorrect out_data. Read " & integer'image(to_integer(unsigned(read_values(PRIM_WIDTH*(i+1)-1 downto PRIM_WIDTH*i)))) & " expected " & integer'image(counter) severity failure;
  
        counter := counter + 1;

        if counter = TOTAL_NUM_VALUES then
          assert check_out_last = '1'
            report "Out_last not asserted on last transaction" severity failure;

          report "All values read" severity note;
          counter := 0;
          exit;
        end if;
        wait for 0 ns;
      end loop;
  
      -- Delay for a random amount of clock cycles to simulate a non-continuous stream
      uniform(seed1, seed2, stream_stop);
      if stream_stop < stream_stop_p then
        uniform(seed1, seed2, num_stopped_cycles);
        for i in 0 to integer(floor(num_stopped_cycles*max_stopped_cycles)) loop
          wait until rising_edge(clk);
        end loop;
      end if;

      -- Counter being reset to 0 means all values have been read
      exit when counter = 0;
    end loop;

    wait until rising_edge(clk);
    assert out_valid(0) = '0'
      report "ValBuffer offers data on its output despite all values having been read" severity failure;

    unl_valid <= '1';
    unl_tag <= (others => '0');

    loop
      wait until rising_edge(clk);
      exit when unl_ready = '1';
    end loop;

    unl_valid <= '0';

    wait until rising_edge(clk);
    assert ctrl_done = '1'
      report "ValuesDecoder not reporting it is done" severity failure;

    report "All checks completed" severity note;
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