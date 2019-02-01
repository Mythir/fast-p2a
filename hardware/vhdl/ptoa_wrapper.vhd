-- Copyright 2018 Delft University of Technology
--
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

-- This file was automatically generated by FletchGen. Modify this file
-- at your own risk.

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.all;

library work;
use work.Arrow.all;
use work.Columns.all;
use work.Interconnect.all;
use work.Wrapper.all;

entity ptoa_wrapper is
  generic(
    BUS_ADDR_WIDTH                             : natural;
    BUS_DATA_WIDTH                             : natural;
    BUS_STROBE_WIDTH                           : natural;
    BUS_LEN_WIDTH                              : natural;
    BUS_BURST_STEP_LEN                         : natural;
    BUS_BURST_MAX_LEN                          : natural;
    ---------------------------------------------------------------------------
    INDEX_WIDTH                                : natural;
    ---------------------------------------------------------------------------
    NUM_ARROW_BUFFERS                          : natural;
    NUM_REGS                                   : natural;
    NUM_USER_REGS                              : natural;
    REG_WIDTH                                  : natural;
    ---------------------------------------------------------------------------
    TAG_WIDTH                                  : natural
  );
  port(
    acc_reset                                  : in std_logic;
    bus_clk                                    : in std_logic;
    bus_reset                                  : in std_logic;
    acc_clk                                    : in std_logic;
    ---------------------------------------------------------------------------
    mst_rreq_valid                             : out std_logic;
    mst_rreq_ready                             : in std_logic;
    mst_rreq_addr                              : out std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
    mst_rreq_len                               : out std_logic_vector(BUS_LEN_WIDTH-1 downto 0);
    ---------------------------------------------------------------------------
    mst_rdat_valid                             : in std_logic;
    mst_rdat_ready                             : out std_logic;
    mst_rdat_data                              : in std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
    mst_rdat_last                              : in std_logic;
    ---------------------------------------------------------------------------
    mst_wreq_valid                             : out std_logic;
    mst_wreq_len                               : out std_logic_vector(BUS_LEN_WIDTH-1 downto 0);
    mst_wreq_addr                              : out std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
    mst_wreq_ready                             : in std_logic;
    ---------------------------------------------------------------------------
    mst_wdat_valid                             : out std_logic;
    mst_wdat_ready                             : in std_logic;
    mst_wdat_data                              : out std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
    mst_wdat_strobe                            : out std_logic_vector(BUS_STROBE_WIDTH-1 downto 0);
    mst_wdat_last                              : out std_logic;
    ---------------------------------------------------------------------------
    regs_in                                    : in std_logic_vector(NUM_REGS*REG_WIDTH-1 downto 0);
    regs_out                                   : out std_logic_vector(NUM_REGS*REG_WIDTH-1 downto 0);
    regs_out_en                                : out std_logic_vector(NUM_REGS-1 downto 0)
  );
end ptoa_wrapper;

architecture Implementation of ptoa_wrapper is

  component MetadataInterpreter is
    generic (
      METADATA_WIDTH                           : natural;
      BUS_ADDR_WIDTH                           : natural;
      BUS_DATA_WIDTH                           : natural;
      BUS_LEN_WIDTH                            : natural;
      NUM_REGS                                 : natural
    );             
    port (             
      clk                                      : in  std_logic;
      hw_reset                                 : in  std_logic;
      mst_rreq_valid                           : out std_logic;
      mst_rreq_ready                           : in  std_logic;
      mst_rreq_addr                            : out std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
      mst_rreq_len                             : out std_logic_vector(BUS_LEN_WIDTH-1 downto 0);
      mst_rdat_valid                           : in  std_logic;
      mst_rdat_ready                           : out std_logic;
      mst_rdat_data                            : in  std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
      mst_rdat_last                            : in  std_logic;
      ctrl_done                                : out std_logic;
      ctrl_busy                                : out std_logic;
      ctrl_idle                                : out std_logic;
      ctrl_reset                               : in std_logic;
      ctrl_stop                                : in std_logic;
      ctrl_start                               : in std_logic;
      md_uncomp_size                           : out std_logic_vector(31 downto 0);
      md_comp_size                             : out  std_logic_vector(31 downto 0);
      md_num_values                            : out std_logic_vector(31 downto 0);
      cycle_count                              : out std_logic_vector(31 downto 0);
      regs_out_en                              : out std_logic_vector(NUM_REGS-1 downto 0);
      md_addr                                  : in std_logic_vector(BUS_ADDR_WIDTH-1 downto 0)
  
    );
  end component;

  signal uctrl_done                            : std_logic;
  signal uctrl_busy                            : std_logic;
  signal uctrl_idle                            : std_logic;
  signal uctrl_reset                           : std_logic;
  signal uctrl_stop                            : std_logic;
  signal uctrl_start                           : std_logic;
  signal uctrl_control                         : std_logic_vector(REG_WIDTH-1 downto 0);
  signal uctrl_status                          : std_logic_vector(REG_WIDTH-1 downto 0);
  -----------------------------------------------------------------------------

begin

  -- Controller instance.
  UserCoreController_inst: UserCoreController
    generic map (
      REG_WIDTH                                => REG_WIDTH
    )
    port map (
      acc_clk                                  => acc_clk,
      acc_reset                                => acc_reset,
      bus_clk                                  => bus_clk,
      bus_reset                                => bus_reset,
      status                                   => regs_out(2*REG_WIDTH-1 downto REG_WIDTH),
      control                                  => regs_in(REG_WIDTH-1 downto 0),
      start                                    => uctrl_start,
      stop                                     => uctrl_stop,
      reset                                    => uctrl_reset,
      idle                                     => uctrl_idle,
      busy                                     => uctrl_busy,
      done                                     => uctrl_done
    );

  MetadataInterpreter_inst: MetadataInterpreter
    generic map(
        METADATA_WIDTH                         => 512,
        BUS_ADDR_WIDTH                         => BUS_ADDR_WIDTH,
        BUS_DATA_WIDTH                         => BUS_DATA_WIDTH,
        BUS_LEN_WIDTH                          => BUS_LEN_WIDTH,
        NUM_REGS                               => NUM_REGS
      )
    port map (
        clk                                    => bus_clk,
        hw_reset                               => bus_reset, 
        mst_rreq_valid                         => mst_rreq_valid,
        mst_rreq_ready                         => mst_rreq_ready,
        mst_rreq_addr                          => mst_rreq_addr,
        mst_rreq_len                           => mst_rreq_len,
        mst_rdat_valid                         => mst_rdat_valid,
        mst_rdat_ready                         => mst_rdat_ready,
        mst_rdat_data                          => mst_rdat_data,
        mst_rdat_last                          => mst_rdat_last,
        ctrl_done                              => uctrl_done,
        ctrl_busy                              => uctrl_busy,
        ctrl_idle                              => uctrl_idle,
        ctrl_reset                             => uctrl_reset,
        ctrl_stop                              => uctrl_stop,
        ctrl_start                             => uctrl_start,
        md_uncomp_size                         => regs_out(NUM_REGS*REG_WIDTH-1 downto (NUM_REGS-1)*REG_WIDTH),
        md_comp_size                           => regs_out((NUM_REGS-2)*REG_WIDTH-1 downto (NUM_REGS-3)*REG_WIDTH),
        md_num_values                          => regs_out((NUM_REGS-3)*REG_WIDTH-1 downto (NUM_REGS-4)*REG_WIDTH),
        cycle_count                            => open,
        regs_out_en                            => regs_out_en,
        md_addr                                => regs_in(8*REG_WIDTH-1 downto 6*REG_WIDTH)
      );

  -- Most registers don't need to be written to for now.
  regs_out((NUM_REGS-4)*REG_WIDTH-1 downto 2*REG_WIDTH) <= (others => '0');
  regs_out(REG_WIDTH-1 downto 0)  <= (others => '0');

  -- Same goes for memory
  mst_wreq_valid <= '0';            
  mst_wreq_len   <= (others => '0');
  mst_wreq_addr  <= (others => '0');
  ----------------------------------
  mst_wdat_valid <= '0';
  mst_wdat_data   <= (others => '0');
  mst_wdat_strobe <= (others => '0');
  mst_wdat_last  <= '0';

end architecture;