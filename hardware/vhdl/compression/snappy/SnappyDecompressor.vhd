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
use work.UtilInt_pkg.all;
use work.UtilMisc_pkg.all;
use work.Stream_pkg.all;
use work.Snappy.all;

-- This module is a wrapper for the FPGA-Snappy-Decompressor at https://github.com/ChenJianyunp/FPGA-Snappy-Decompressor.
-- The FPGA-Snappy-Decompressor only supports 512 bit wide in and out data ports, so this wrapper does too.
-- If you want to use this decompressor with a narrower bus you are going to need some StreamGearboxSerializers and StreamGearboxParallelizers.

entity SnappyDecompressor is
  generic (
    -- Bus data width
    BUS_DATA_WIDTH              : natural
  );
  port (
    -- Rising-edge sensitive clock.
    clk                         : in  std_logic;

    -- Active-high synchronous reset.
    reset                       : in  std_logic;

    -- Data in stream from PreDecBuffer
    in_valid                    : in  std_logic;
    in_ready                    : out std_logic;
    in_data                     : in  std_logic_vector(BUS_DATA_WIDTH-1 downto 0);

    -- Handshake signaling new page
    new_page_valid              : in  std_logic;
    new_page_ready              : out std_logic;

    -- Compressed and uncompressed size of values in page (from MetadataInterpreter)
    compressed_size             : in  std_logic_vector(31 downto 0);
    uncompressed_size           : in  std_logic_vector(31 downto 0);

    --Data out stream to Fletcher ArrayWriter
    out_valid                   : out std_logic;
    out_ready                   : in  std_logic;
    out_data                    : out std_logic_vector(BUS_DATA_WIDTH-1 downto 0)
  );
end SnappyDecompressor;

architecture behv of SnappyDecompressor is

  type state_t is (IDLE, STARTING, DECOMPRESSING);
  
  type reg_record is record
    state                : state_t;
    compression_length   : std_logic_vector(34 downto 0);
    decompression_length : std_logic_vector(31 downto 0);
    input_byte_counter   : unsigned(31 downto 0);
  end record;

  signal r : reg_record;
  signal d : reg_record;

  -- Data in stream to decompressor
  signal dec_in_valid           : std_logic;
  signal dec_in_ready           : std_logic;
  signal dec_in_data            : std_logic_vector(BUS_DATA_WIDTH-1 downto 0);

  signal dec_start              : std_logic;
  signal dec_done               : std_logic;
  signal dec_reset              : std_logic;

  signal dec_metadata_ready     : std_logic;
  signal dec_metadata_valid     : std_logic;

  signal dec_compression_length   : std_logic_vector(34 downto 0);
  signal dec_decompression_length : std_logic_vector(31 downto 0);

begin
  assert BUS_DATA_WIDTH = 512
    report "Only 512 bit BUS_DATA_WIDTH is supported when using the Snappy decompressor" severity failure;

  -- Active low reset on decompressor
  dec_reset    <= not reset;

  dec_in_data  <= in_data;

  snappy_inst: decompressor_wrapper
    port map(
      clk                         => clk,
      rst_n                       => dec_reset,
      last                        => open,
      done                        => dec_done,
      start                       => dec_start,
      in_data                     => dec_in_data,
      in_data_valid               => dec_in_valid,
      in_data_ready               => dec_in_ready,
      compression_length          => dec_compression_length,
      decompression_length        => dec_decompression_length,
      in_metadata_valid           => dec_metadata_valid,
      in_metadata_ready           => dec_metadata_ready,
      out_data                    => out_data,
      out_data_valid              => out_valid,
      out_data_byte_valid         => open,
      out_data_ready              => out_ready
    );

  -- Step 1 (IDLE): Stream metadata (uncompressed_size, decompressed_size) to decompressor (new page handshake unblocked)
  -- Step 2 (STARTING): Set start to '1' for one cycle
  -- Step 3 (DECOMPRESSING): Stream data to decompressor (input data unblocked conditionally)
  logic_p: process(dec_metadata_ready, dec_metadata_valid, new_page_valid, r, compressed_size, uncompressed_size, dec_in_ready, dec_in_valid, in_valid, dec_done)
    variable v : reg_record;
  begin
    v := r;
    dec_start  <= '0';

    -- Pass stored uncompressed and compressed size to decompressor
    dec_compression_length   <= r.compression_length;
    dec_decompression_length <= r.decompression_length;

    -- Block new_page handshake
    dec_metadata_valid <= '0';
    new_page_ready     <= '0';

    -- Block input data
    dec_in_valid <= '0';
    in_ready     <= '0';

    case r.state is
      when IDLE =>
        -- Unblock new page handshake
        dec_metadata_valid <= new_page_valid;
        new_page_ready     <= dec_metadata_ready;

        -- During handshaking pass new size/length values directly to decompressor
        dec_compression_length   <= std_logic_vector(resize(unsigned(compressed_size), dec_compression_length'length));
        dec_decompression_length <= uncompressed_size;

        if dec_metadata_valid = '1' and dec_metadata_ready = '1' then
          v.state                := STARTING;
          v.compression_length   := std_logic_vector(resize(unsigned(compressed_size), dec_compression_length'length));
          v.decompression_length := uncompressed_size;
        end if;

      when STARTING =>
        dec_start  <= '1';
        v.state := DECOMPRESSING;

      when DECOMPRESSING =>
        -- Unblock in data (conditionally)
        if r.input_byte_counter < unsigned(r.compression_length) then
          dec_in_valid <= in_valid;
          in_ready     <= dec_in_ready;
        end if;

        if dec_in_valid = '1' and dec_in_ready = '1' then
          v.input_byte_counter := r.input_byte_counter + BUS_DATA_WIDTH/8;
        end if;

        if dec_done = '1' then
          v.state              := IDLE;
          v.input_byte_counter := (others => '0');
        end if;

    end case;

    d <= v;
  end process;

  clk_p: process(clk)
  begin
    if rising_edge(clk) then
      if reset = '1' then
        r.state              <= IDLE;
        r.input_byte_counter <= (others => '0');
      else
        r <= d;
      end if;
    end if;
  end process;

end architecture;