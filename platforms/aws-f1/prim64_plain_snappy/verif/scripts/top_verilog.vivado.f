# Amazon FPGA Hardware Development Kit
#
# Copyright 2016 Amazon.com, Inc. or its affiliates. All Rights Reserved.
#
# Licensed under the Amazon Software License (the "License"). You may not use
# this file except in compliance with the License. A copy of the License is
# located at
#
#    http://aws.amazon.com/asl/
#
# or in the "license" file accompanying this file. This file is distributed on
# an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, express or
# implied. See the License for the specific language governing permissions and
# limitations under the License.

--define VIVADO_SIM

--sourcelibext .v
--sourcelibext .sv
--sourcelibext .svh

# AWS EC2 F1 1.4.8 IP:
--sourcelibdir ${CL_ROOT}/design
--sourcelibdir ${SH_LIB_DIR}
--sourcelibdir ${SH_INF_DIR}
--sourcelibdir ${HDK_SHELL_DESIGN_DIR}/sh_ddr/sim

--include ${SH_LIB_DIR}
--include ${SH_INF_DIR}
--include ${HDK_COMMON_DIR}/verif/include

--include ${HDK_SHELL_DESIGN_DIR}/ip/cl_axi_interconnect/ipshared/7e3a/hdl
--include ${HDK_SHELL_DESIGN_DIR}/sh_ddr/sim
--include ${HDK_SHELL_DESIGN_DIR}/ip/axi_register_slice_light/hdl

${HDK_SHELL_DESIGN_DIR}/ip/axi_register_slice/sim/axi_register_slice.v
${HDK_SHELL_DESIGN_DIR}/ip/axi_register_slice_light/sim/axi_register_slice_light.v
${HDK_SHELL_DESIGN_DIR}/ip/dest_register_slice/hdl/axi_register_slice_v2_1_vl_rfs.v
${HDK_SHELL_DESIGN_DIR}/ip/axi_clock_converter_0/sim/axi_clock_converter_0.v
${HDK_SHELL_DESIGN_DIR}/ip/axi_clock_converter_0/hdl/axi_clock_converter_v2_1_vl_rfs.v
${HDK_SHELL_DESIGN_DIR}/ip/axi_clock_converter_0/hdl/fifo_generator_v13_2_rfs.v

# Fletcher IP:
# Top level interconnect between PCI Slave and DDR C
${CL_ROOT}/design/ip/axi_interconnect_top/sim/axi_interconnect_top.v

--define DISABLE_VJTAG_DEBUG
${CL_ROOT}/design/cl_arrow_defines.vh
${CL_ROOT}/design/cl_arrow_pkg.sv
${CL_ROOT}/design/cl_arrow.sv

# Snappy decompressor files
${PTOA_HARDWARE_DIR}/vhdl/compression/snappy/FPGA-Snappy-Decompressor/hw/source/control.v
${PTOA_HARDWARE_DIR}/vhdl/compression/snappy/FPGA-Snappy-Decompressor/hw/source/copyread_selector.v
${PTOA_HARDWARE_DIR}/vhdl/compression/snappy/FPGA-Snappy-Decompressor/hw/source/copytoken_selector.v
${PTOA_HARDWARE_DIR}/vhdl/compression/snappy/FPGA-Snappy-Decompressor/hw/source/data_out.v
${PTOA_HARDWARE_DIR}/vhdl/compression/snappy/FPGA-Snappy-Decompressor/hw/source/decompressor.v
${PTOA_HARDWARE_DIR}/vhdl/compression/snappy/FPGA-Snappy-Decompressor/hw/source/decompressor_wrapper.v
${PTOA_HARDWARE_DIR}/vhdl/compression/snappy/FPGA-Snappy-Decompressor/hw/source/distributor.v
${PTOA_HARDWARE_DIR}/vhdl/compression/snappy/FPGA-Snappy-Decompressor/hw/source/fifo.v
${PTOA_HARDWARE_DIR}/vhdl/compression/snappy/FPGA-Snappy-Decompressor/hw/source/fifo_parser_copy.v
${PTOA_HARDWARE_DIR}/vhdl/compression/snappy/FPGA-Snappy-Decompressor/hw/source/fifo_parser_lit.v
${PTOA_HARDWARE_DIR}/vhdl/compression/snappy/FPGA-Snappy-Decompressor/hw/source/io_control.v
${PTOA_HARDWARE_DIR}/vhdl/compression/snappy/FPGA-Snappy-Decompressor/hw/source/lit_selector.v
${PTOA_HARDWARE_DIR}/vhdl/compression/snappy/FPGA-Snappy-Decompressor/hw/source/parser.v
${PTOA_HARDWARE_DIR}/vhdl/compression/snappy/FPGA-Snappy-Decompressor/hw/source/parser_sub.v
${PTOA_HARDWARE_DIR}/vhdl/compression/snappy/FPGA-Snappy-Decompressor/hw/source/preparser.v
${PTOA_HARDWARE_DIR}/vhdl/compression/snappy/FPGA-Snappy-Decompressor/hw/source/queue_token.v
${PTOA_HARDWARE_DIR}/vhdl/compression/snappy/FPGA-Snappy-Decompressor/hw/source/ram_block.v
${PTOA_HARDWARE_DIR}/vhdl/compression/snappy/FPGA-Snappy-Decompressor/hw/source/ram_module.v
${PTOA_HARDWARE_DIR}/vhdl/compression/snappy/FPGA-Snappy-Decompressor/hw/source/select.v

${PTOA_HARDWARE_DIR}/vhdl/compression/snappy/FPGA-Snappy-Decompressor/ip/action_ip_prj/action_ip_prj.srcs/sources_1/ip/blockram/sim/blockram.v
${PTOA_HARDWARE_DIR}/vhdl/compression/snappy/FPGA-Snappy-Decompressor/ip/action_ip_prj/action_ip_prj.srcs/sources_1/ip/data_fifo/sim/data_fifo.v
${PTOA_HARDWARE_DIR}/vhdl/compression/snappy/FPGA-Snappy-Decompressor/ip/action_ip_prj/action_ip_prj.srcs/sources_1/ip/debugram/sim/debugram.v
${PTOA_HARDWARE_DIR}/vhdl/compression/snappy/FPGA-Snappy-Decompressor/ip/action_ip_prj/action_ip_prj.srcs/sources_1/ip/page_fifo/sim/page_fifo.v
${PTOA_HARDWARE_DIR}/vhdl/compression/snappy/FPGA-Snappy-Decompressor/ip/action_ip_prj/action_ip_prj.srcs/sources_1/ip/result_ram/sim/result_ram.v
${PTOA_HARDWARE_DIR}/vhdl/compression/snappy/FPGA-Snappy-Decompressor/ip/action_ip_prj/action_ip_prj.srcs/sources_1/ip/unsolved_fifo/sim/unsolved_fifo.v

-f ${HDK_COMMON_DIR}/verif/tb/filelists/tb.${SIMULATOR}.f

${TEST_NAME}