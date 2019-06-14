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
use work.Delta.all;

entity BitUnpacker_tb is
end BitUnpacker_tb;

architecture tb of BitUnpacker_tb is
  constant DEC_DATA_WIDTH              : natural := 64;
  constant MAX_DELTAS_PER_CYCLE        : natural := 16;
  constant PRIM_WIDTH                  : natural := 32;
  constant BYTES_IN_BLOCK_WIDTH        : natural := 16;
  constant VALUES_TO_READ              : natural := 100000;
  constant clk_period                  : time := 10 ns;

  constant FIRST_VALUE                 : integer := 995964;
  constant BLOCK_SIZE                  : natural := 128;
  constant MINIBLOCKS_IN_BLOCK         : natural := 4;

  signal clk                           : std_logic;
  signal reset                         : std_logic;

  --BitUnpacker
  signal bu_in_valid                   : std_logic;
  signal bu_in_ready                   : std_logic;
  signal bu_in_data                    : std_logic_vector(DEC_DATA_WIDTH-1 downto 0);
  signal bu_in_count                   : std_logic_vector(log2floor(MAX_DELTAS_PER_CYCLE) downto 0);
  signal bu_in_width                   : std_logic_vector(log2floor(PRIM_WIDTH) downto 0);
  signal out_valid                     : std_logic;
  signal out_ready                     : std_logic;
  signal out_count                     : std_logic_vector(log2floor(MAX_DELTAS_PER_CYCLE) downto 0);
  signal out_data                      : std_logic_vector(MAX_DELTAS_PER_CYCLE*PRIM_WIDTH-1 downto 0);

  --BlockValuesAligner
  signal in_valid                    : std_logic;
  signal in_ready                    : std_logic;
  signal in_data                     : std_logic_vector(DEC_DATA_WIDTH-1 downto 0);
  signal page_num_values             : std_logic_vector(31 downto 0) := std_logic_vector(to_unsigned(VALUES_TO_READ, 32));
  signal md_valid                    : std_logic;
  signal md_ready                    : std_logic;
  signal md_data                     : std_logic_vector(PRIM_WIDTH-1 downto 0);
  signal bc_valid                    : std_logic;
  signal bc_ready                    : std_logic := '1';
  signal bc_data                     : std_logic_vector(BYTES_IN_BLOCK_WIDTH-1 downto 0);
  signal bva_out_valid               : std_logic;
  signal bva_out_ready               : std_logic;
  signal bva_out_data                : std_logic_vector(DEC_DATA_WIDTH-1 downto 0);
  signal bva_out_count               : std_logic_vector(log2floor(MAX_DELTAS_PER_CYCLE) downto 0);
  signal bva_out_width               : std_logic_vector(log2floor(PRIM_WIDTH) downto 0);

  signal consumed_md                 : std_logic_vector(md_data'length-1 downto 0);

  signal consumed_out_data           : std_logic_vector(out_data'length-1 downto 0);
  signal consumed_out_count          : std_logic_vector(out_count'length-1 downto 0);
begin

  bva: entity work.BlockValuesAligner
    generic map(
      -- Decoder data width
      DEC_DATA_WIDTH              => DEC_DATA_WIDTH,
      BLOCK_SIZE                  => BLOCK_SIZE,
      MINIBLOCKS_IN_BLOCK         => MINIBLOCKS_IN_BLOCK,
      MAX_DELTAS_PER_CYCLE        => MAX_DELTAS_PER_CYCLE,
      BYTES_IN_BLOCK_WIDTH        => BYTES_IN_BLOCK_WIDTH,
      PRIM_WIDTH                  => PRIM_WIDTH
    )
    port map(
      clk                         => clk,
      reset                       => reset,
      in_valid                    => in_valid,
      in_ready                    => in_ready,
      in_data                     => in_data,
      page_num_values             => page_num_values,
      md_valid                    => md_valid,
      md_ready                    => md_ready,
      md_data                     => md_data,
      bc_valid                    => bc_valid,
      bc_ready                    => bc_ready,
      bc_data                     => bc_data,
      out_valid                   => bva_out_valid,
      out_ready                   => bva_out_ready,
      out_data                    => bva_out_data,
      out_count                   => bva_out_count,
      out_width                   => bva_out_width
    );

  bu_in_data    <= bva_out_data;
  bu_in_valid   <= bva_out_valid;
  bva_out_ready <= bu_in_ready;
  bu_in_count   <= bva_out_count;
  bu_in_width   <= bva_out_width;

  dut: entity work.BitUnpacker
    generic map(
      DEC_DATA_WIDTH              => DEC_DATA_WIDTH,
      MAX_DELTAS_PER_CYCLE        => MAX_DELTAS_PER_CYCLE,
      PRIM_WIDTH                  => PRIM_WIDTH
    )
    port map(
      clk                         => clk,
      reset                       => reset,
      in_valid                    => bu_in_valid,
      in_ready                    => bu_in_ready,
      in_data                     => bu_in_data,
      in_count                    => bu_in_count,
      in_width                    => bu_in_width,
      out_valid                   => out_valid,
      out_ready                   => out_ready,
      out_count                   => out_count,
      out_data                    => out_data
    );



  upstream_p: process
    file input_data             : text;

    constant stream_stop_p      : real    := 0.001;
    constant max_stopped_cycles : real    := 30.0;

    variable input_line         : line;
    variable page_data          : std_logic_vector(DEC_DATA_WIDTH-1 downto 0);

    variable seed1              : positive := 1370;
    variable seed2              : positive := 442;

    variable stream_stop        : real;
    variable num_stopped_cycles : real;
  begin
    if DEC_DATA_WIDTH = 32 then
      file_open(input_data, "./test/encoding/delta/bva_tb_in.hex1", read_mode);
    elsif DEC_DATA_WIDTH = 64 then
      file_open(input_data, "./test/encoding/delta/bva_tb_in64.hex1", read_mode);
    end if;

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

    report "encoded.hex1 has been fully read" severity note;

    -- Keep in_valid high to simulate characters in the delta-length encoding
    in_valid <= '1';

    wait;
  end process;

  out_consumer_p: process
    file input_data             : text;

    constant stream_stop_p      : real    := 0.001;
    constant max_stopped_cycles : real    := 10.0;

    variable input_line         : line;
    variable decoded_int        : std_logic_vector(PRIM_WIDTH-1 downto 0);

    variable seed1              : positive := 137;
    variable seed2              : positive := 442;

    variable stream_stop        : real;
    variable num_stopped_cycles : real;

    variable unpacked_delta     : std_logic_vector(PRIM_WIDTH-1 downto 0);
    variable last_value         : integer;
    variable md_count           : unsigned(log2ceil(BLOCK_SIZE)-1 downto 0) := (others => '0');
    variable min_delta          : integer;
  begin
    -- File containing the correctly decoded integers
    if DEC_DATA_WIDTH = 32 then
      file_open(input_data, "./test/encoding/delta/bva_tb_check.hex1", read_mode);
    elsif DEC_DATA_WIDTH = 64 then
      file_open(input_data, "./test/encoding/delta/bva_tb_check64.hex1", read_mode);
    end if;

    out_ready <= '0';
    md_ready  <= '0';

    loop
      wait until rising_edge(clk);
      exit when reset = '0';
    end loop;

    readline(input_data, input_line);
    hread(input_line, decoded_int);

    assert to_integer(signed(decoded_int)) = FIRST_VALUE
      report "First value in output check file not equal to FIRST_VALUE constant." severity failure;

    last_value := FIRST_VALUE;

    while not endfile(input_data) loop
      if md_count = to_unsigned(0, md_count'length) then
        -- Consume a new min delta every time a full block is processed
        md_ready <= '1';

        loop
          wait until rising_edge(clk);
          exit when md_valid = '1';
        end loop;

        min_delta := to_integer(signed(md_data));
      end if;

      md_ready <= '0';

      out_ready <= '1';

      loop
        wait until rising_edge(clk);
        exit when out_valid = '1';
      end loop;

      out_ready <= '0';
      consumed_out_data  <= out_data;
      consumed_out_count <= out_count;

      wait for 0 ns;

      md_count := md_count + to_integer(unsigned(consumed_out_count));
      
      -- Loop to compare output with check file
      for i in 0 to to_integer(unsigned(consumed_out_count))-1 loop
        readline(input_data, input_line);
        hread(input_line, decoded_int);

        unpacked_delta := out_data(PRIM_WIDTH*(i+1)-1 downto PRIM_WIDTH*i);

        last_value := last_value + min_delta + to_integer(signed(unpacked_delta));

        report "Min delta: " & integer'image(min_delta) & ", Delta: " & integer'image(to_integer(signed(unpacked_delta))) & ", Decoded int: " & integer'image(last_value) & ", Count: " 
          & integer'image(to_integer(signed(consumed_out_count))) & ", i: " & integer'image(i) & ", md_count: " & integer'image(to_integer(md_count)) severity note;

        assert last_value = to_integer(signed(decoded_int))
          report "Unpacking and decoding aligned integer resulted in " & integer'image(last_value) & " instead of the correct value " & integer'image(to_integer(signed(decoded_int))) severity failure;
      end loop;

      -- Delay for a random amount of clock cycles to simulate a non-continuous stream
      uniform(seed1, seed2, stream_stop);
      if stream_stop < stream_stop_p then
        uniform(seed1, seed2, num_stopped_cycles);
        for i in 0 to integer(floor(num_stopped_cycles*max_stopped_cycles)) loop
          wait until rising_edge(clk);
        end loop;
      end if;
    end loop;

      report "decoded.hex1 has been fully read" severity note;
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