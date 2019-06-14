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

-- Very simple testbench for DeltaHeaderReader. Does not verify the output, is simply meant as a tool for seeing how the DeltaHeaderReader reacts to different inputs.

entity DeltaHeaderReader_tb is
end DeltaHeaderReader_tb;

architecture tb of DeltaHeaderReader_tb is
  constant BUS_DATA_WIDTH      : natural := 512;
  constant NUM_SHIFT_STAGES    : natural := 2;
  constant BLOCK_SIZE          : natural := 128;
  constant MINIBLOCKS_IN_BLOCK : natural := 4;
  constant PRIM_WIDTH          : natural := 64;
  constant clk_period          : time    := 10 ns;

  signal clk                   : std_logic;
  signal reset                 : std_logic;
  signal in_valid              : std_logic;
  signal in_ready              : std_logic;
  signal in_last               : std_logic;
  signal in_data               : std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
  signal fv_valid              : std_logic;
  signal fv_ready              : std_logic;
  signal first_value           : std_logic_vector(PRIM_WIDTH-1 downto 0);
  signal out_valid             : std_logic;
  signal out_ready             : std_logic;
  signal out_data              : std_logic_vector(BUS_DATA_WIDTH-1 downto 0);

  signal consumed_word         : std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
  signal consumed_fv           : std_logic_vector(PRIM_WIDTH-1 downto 0);

  type mem_fv32 is array (0 to 3) of std_logic_vector(511 downto 0);
  constant DeltaHeader_fv : mem_fv32 := (
    0 => x"80010480800082828282828202111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111",
    1 => x"11111111111111111111111111222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222",
    2 => x"22222222222222222222222222333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333",
    3 => x"33333333333333333333333333444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444"
  );

begin
  
  in_last <= '0';

  dut: entity work.DeltaHeaderReader
    generic map(
      BUS_DATA_WIDTH             => BUS_DATA_WIDTH,
      NUM_SHIFT_STAGES           => NUM_SHIFT_STAGES,
      BLOCK_SIZE                 => BLOCK_SIZE,
      MINIBLOCKS_IN_BLOCK        => MINIBLOCKS_IN_BLOCK,
      PRIM_WIDTH                 => PRIM_WIDTH
    )
    port map(
      clk                        => clk,
      reset                      => reset,
      in_valid                   => in_valid,
      in_ready                   => in_ready,
      in_last                    => in_last,
      in_data                    => in_data,
      fv_valid                   => fv_valid,
      fv_ready                   => fv_ready,
      first_value                => first_value,
      out_valid                  => out_valid,
      out_ready                  => out_ready,
      out_data                   => out_data
    );

  upstream_p : process
  begin
    in_valid <= '0';
    loop
      wait until rising_edge(clk);
      exit when reset = '0';
    end loop;

    for i in 0 to DeltaHeader_fv'length-1 loop
      in_valid <= '1';
      in_data <= DeltaHeader_fv(i);

      loop
        wait until rising_edge(clk);
        exit when in_ready = '1';
      end loop;
      in_valid <= '0';
    end loop;
    wait;
  end process;

  downstream_p : process
  begin
    out_ready <= '0';
    loop
      wait until rising_edge(clk);
      exit when reset = '0';
    end loop;

    loop
      out_ready <= '1';
      loop
        wait until rising_edge(clk);
        exit when out_valid = '1';
      end loop;
      out_ready <= '0';
      consumed_word <= out_data;
    end loop;
  end process;

  first_value_p : process
  begin
    fv_ready <= '0';
    loop
      wait until rising_edge(clk);
      exit when reset = '0';
    end loop;

    loop
      fv_ready <= '1';
      loop
        wait until rising_edge(clk);
        exit when fv_valid = '1';
      end loop;
      fv_ready <= '0';
      consumed_fv <= first_value;
    end loop;

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