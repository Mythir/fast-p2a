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
-- Fletcher utils for use of log2ceil and endian_swap functions
use work.UtilInt_pkg.all;
use work.UtilMisc_pkg.all;
use work.Interconnect_pkg.all;

-- The ingester is responsible for sending AXI compliant read requests and offering up the responses to the DataAligner for further processing.
-- AXI requires that a burst does not cross 4KB address boundaries. Logic for avoiding these boundaries is included in the ingester, inspired by
-- the Fletcher BufferReaders (https://github.com/johanpel/fletcher/blob/develop/hardware/vhdl/buffers/BufferReaderCmdGenBusReq.vhd).
--
-- This unit uses a Fletcher BusReadBuffer to ensure that a read request is only sent to the AXI bus if we can buffer the entire response.

entity Ingester is
  generic (
    -- Bus data width
    BUS_DATA_WIDTH              : natural := 512;

    -- Bus address width
    BUS_ADDR_WIDTH              : natural := 64;

    -- Bus length width
    BUS_LEN_WIDTH               : natural := 8;

    -- Number of beats in a burst.
    BUS_BURST_MAX_LEN           : natural := 16;

    -- Depth of the FiFo in the Fletcher BusReadBuffer used to buffer data read from memory.
    -- A larger FiFo allows for more outstanding read requests (approximately FIFO_DEPTH/BURST_MAX_LEN requests.)
    BUS_FIFO_DEPTH              : natural := 16;

    -- RAM configuration string for the Fletcher BusReadBuffer
    BUS_FIFO_RAM_CONFIG         : string := ""

  );
  port (

    -- Rising-edge sensitive clock.
    clk                         : in  std_logic;

    -- Active-high synchronous reset.
    reset                       : in  std_logic;

    -- Read address channel
    bus_rreq_valid              : out std_logic;
    bus_rreq_ready              : in  std_logic;
    bus_rreq_addr               : out std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
    bus_rreq_len                : out std_logic_vector(BUS_LEN_WIDTH-1 downto 0);

    -- Read data channel
    bus_rdat_valid              : in  std_logic;
    bus_rdat_ready              : out std_logic;
    bus_rdat_data               : in  std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
    bus_rdat_last               : in  std_logic;

    -- Data stream to DataAligner
    out_valid                   : out std_logic;
    out_ready                   : in  std_logic;
    out_data                    : out std_logic_vector(BUS_DATA_WIDTH-1 downto 0);

    -- Initial misalignment stream to DataAligner
    pa_valid                    : out std_logic;
    pa_ready                    : in  std_logic;
    pa_data                     : out std_logic_vector(log2ceil(BUS_DATA_WIDTH/8)-1 downto 0);

    start                       : in  std_logic;
    stop                        : in  std_logic;

    -- Pointer to start of data and size of data, received from host via MMIO
    base_address                : in  std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
    data_size                   : in  std_logic_vector(BUS_ADDR_WIDTH-1 downto 0)


  );
end Ingester;

architecture behv of Ingester is

  -- Top level state in the state machine
  type state_t is (IDLE, STEP, FULL_BURST, DONE);
      signal state, state_next : state_t;

  constant BYTE_ALIGN           : natural := imin(BUS_BURST_BOUNDARY, BUS_BURST_MAX_LEN * BUS_DATA_WIDTH / 8);
  constant BYTES_PER_STEP       : natural := BUS_DATA_WIDTH/8;
  constant BYTES_PER_BURST      : natural := BUS_DATA_WIDTH * BUS_BURST_MAX_LEN / 8;

  signal current_address        : std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
  signal current_address_next   : std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);

  -- Internal read request stream to BusReadBuffer
  signal ingester_req_valid     : std_logic;
  signal ingester_req_ready     : std_logic;
  signal ingester_req_len       : std_logic_vector(BUS_LEN_WIDTH-1 downto 0);
  signal ingester_req_addr      : std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);

  -- Base address aligned to bus width
  signal bus_aligned_base_addr  : std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);

  -- The first address that does not contain any data intended for this hardware
  signal end_address            : unsigned(BUS_ADDR_WIDTH-1 downto 0);

begin
  -- When doing an AXI unaligned transfer the DataAligner must know where in the first bus word the actual data starts
  pa_data <= base_address(log2ceil(BUS_DATA_WIDTH/8)-1 downto 0);

  bus_aligned_base_addr(BUS_ADDR_WIDTH-1 downto log2ceil(BUS_DATA_WIDTH/8)) <= base_address(BUS_ADDR_WIDTH-1 downto log2ceil(BUS_DATA_WIDTH/8));
  bus_aligned_base_addr(log2ceil(BUS_DATA_WIDTH/8)-1 downto 0) <= (others => '0');

  end_address <= unsigned(base_address) + unsigned(data_size);

  -- This unit comes from the Fletcher interconnect library and is used here to make sure that one Ingester cannot DOS the entire bus by spamming
  -- read requests without reading the responses from the bus. The BusReadBuffer only passes a request from this Ingester to the bus if it has room in its
  -- FiFo to buffer the response.
  buffer_inst: BusReadBuffer
    generic map (
      BUS_ADDR_WIDTH                    => BUS_ADDR_WIDTH,
      BUS_LEN_WIDTH                     => BUS_LEN_WIDTH,
      BUS_DATA_WIDTH                    => BUS_DATA_WIDTH,
      FIFO_DEPTH                        => imax(BUS_FIFO_DEPTH, BUS_BURST_MAX_LEN+1),
      RAM_CONFIG                        => BUS_FIFO_RAM_CONFIG,
      SLV_REQ_SLICE                     => false,
      MST_REQ_SLICE                     => true,
      MST_DAT_SLICE                     => false,
      SLV_DAT_SLICE                     => false
    )
    port map (
      clk                               => clk,
      reset                             => reset,

      slv_rreq_valid                    => ingester_req_valid,
      slv_rreq_ready                    => ingester_req_ready,
      slv_rreq_addr                     => ingester_req_addr,
      slv_rreq_len                      => ingester_req_len,
      slv_rdat_valid                    => out_valid,
      slv_rdat_ready                    => out_ready,
      slv_rdat_data                     => out_data,
      slv_rdat_last                     => open,

      mst_rreq_valid                    => bus_rreq_valid,
      mst_rreq_ready                    => bus_rreq_ready,
      mst_rreq_addr                     => bus_rreq_addr,
      mst_rreq_len                      => bus_rreq_len,
      mst_rdat_valid                    => bus_rdat_valid,
      mst_rdat_ready                    => bus_rdat_ready,
      mst_rdat_data                     => endianSwap(bus_rdat_data),
      mst_rdat_last                     => bus_rdat_last
    );


  logic_p: process (state, start, current_address, ingester_req_ready, bus_aligned_base_addr, end_address, pa_ready, stop)
    variable next_burst_address : unsigned(BUS_ADDR_WIDTH-1 downto 0);
  begin
    pa_valid <= '0';
    ingester_req_valid <= '0';
    ingester_req_addr <= (others => '0');
    ingester_req_len <= (others => '0');

    state_next <= state;
    current_address_next <= current_address;

    case state is
      when IDLE =>
        -- IDLE: Once start is asserted, transfer the initial misalignment to the data aligner and start requesting data in the next clock cycle.
        pa_valid <= start;
        current_address_next <= bus_aligned_base_addr;

        -- Transfer producer alignment (misalignment in starting address) to DataAligner
        if pa_ready = '1' and start = '1' then
          if isAligned(unsigned(bus_aligned_base_addr), log2floor(BYTE_ALIGN)) and ((unsigned(bus_aligned_base_addr) + BYTES_PER_BURST) <= end_address) then
            state_next <= FULL_BURST;
          else
            state_next <= STEP;
          end if;
        end if;

      when STEP =>
        -- STEP: Request data with one bus word per request (burst length = 1). If we have received all data (as dictated by data_size) proceed to DONE.
        -- Otherwise, if alignment and data_size allow, proceed to FULL_BURST to start requesting multiple bus words per request.

        next_burst_address := unsigned(current_address) + BYTES_PER_STEP;

        ingester_req_valid <= '1';
        ingester_req_len <= std_logic_vector(to_unsigned(1, BUS_LEN_WIDTH));
        ingester_req_addr <= current_address;

        if ingester_req_ready = '1' then
          -- If the next request would cause us to request memory that we are not supposed to access, we are done.
          if next_burst_address >= end_address then
            state_next <= DONE;
          end if;

          -- If the next request would be aligned to a burst boundary and we still have enough data left we proceed to FULL_BURST
          if isAligned(next_burst_address, log2floor(BYTE_ALIGN)) and next_burst_address + BYTES_PER_BURST <= end_address then
            state_next <= FULL_BURST;
          end if;
          
          current_address_next <= std_logic_vector(next_burst_address);
        end if;

      when FULL_BURST =>
        -- FULL_BURST: Request BUS_BURST_MAX_LEN bus words per request as long as data_size allows. Once we near the end of the data, start stepping again.
        next_burst_address := unsigned(current_address) + BYTES_PER_BURST;

        ingester_req_valid <= '1';
        ingester_req_len <= std_logic_vector(to_unsigned(BUS_BURST_MAX_LEN, BUS_LEN_WIDTH));
        ingester_req_addr <= current_address;

        if ingester_req_ready = '1' then
          -- If the next request would cause us to request memory that we are not supposed to access, we are done.
          if next_burst_address >= end_address then
            state_next <= DONE;
          end if;

          -- If we can't request a full burst without passing end_address we start stepping again
          if next_burst_address + BYTES_PER_BURST > end_address then
            state_next <= STEP;
          end if;

          current_address_next <= std_logic_vector(next_burst_address);
        end if;

      when DONE =>


      end case;

      -- If stop is asserted, stop requesting data from memory
      if stop = '1' then
        state_next <= DONE;
      end if;
  end process;

  state_p: process (clk)
  begin
    if rising_edge(clk) then
      if reset = '1' then
        state <= IDLE;
        current_address <= (others => '0');
      else
        state <= state_next;
        current_address <= current_address_next;
      end if;
    end if;
  end process;

end architecture;