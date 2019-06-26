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

# TODO:
# Add check if CL_DIR and HDK_SHELL_DIR directories exist
# Add check if /build and /build/src_port_encryption directories exist
# Add check if the vivado_keyfile exist

set HDK_SHELL_DIR $::env(HDK_SHELL_DIR)
set HDK_SHELL_DESIGN_DIR $::env(HDK_SHELL_DESIGN_DIR)
set CL_DIR $::env(CL_DIR)
set FLETCHER_HARDWARE_DIR $::env(FLETCHER_HARDWARE_DIR)
set FLETCHER_EXAMPLES_DIR $::env(FLETCHER_EXAMPLES_DIR)
set PTOA_HARDWARE_DIR $::env(PTOA_HARDWARE_DIR)
set PTOA_DIR $::env(PTOA_DIR)


set TARGET_DIR $CL_DIR/build/src_post_encryption
set UNUSED_TEMPLATES_DIR $HDK_SHELL_DESIGN_DIR/interfaces


# Remove any previously encrypted files, that may no longer be used
if {[llength [glob -nocomplain -dir $TARGET_DIR *]] != 0} {
  eval file delete -force [glob $TARGET_DIR/*]
}

#---- Developr would replace this section with design files ----

## Change file names and paths below to reflect your CL area.  DO NOT include AWS RTL files.

# Fletcher files:
file copy -force $FLETCHER_HARDWARE_DIR/vhlib/util/UtilInt_pkg.vhd                      $TARGET_DIR
file copy -force $FLETCHER_HARDWARE_DIR/vhlib/util/UtilMisc_pkg.vhd                      $TARGET_DIR
file copy -force $FLETCHER_HARDWARE_DIR/vhlib/util/UtilRam_pkg.vhd                      $TARGET_DIR
file copy -force $FLETCHER_HARDWARE_DIR/vhlib/util/UtilRam1R1W.vhd                      $TARGET_DIR
file copy -force $FLETCHER_HARDWARE_DIR/vhlib/util/UtilConv_pkg.vhd                      $TARGET_DIR
file copy -force $FLETCHER_HARDWARE_DIR/vhlib/util/UtilStr_pkg.vhd                      $TARGET_DIR

file copy -force $FLETCHER_HARDWARE_DIR/vhlib/stream/Stream_pkg.vhd                     $TARGET_DIR
file copy -force $FLETCHER_HARDWARE_DIR/vhlib/stream/StreamArb.vhd                   $TARGET_DIR
file copy -force $FLETCHER_HARDWARE_DIR/vhlib/stream/StreamBuffer.vhd                $TARGET_DIR
file copy -force $FLETCHER_HARDWARE_DIR/vhlib/stream/StreamFIFOCounter.vhd           $TARGET_DIR
file copy -force $FLETCHER_HARDWARE_DIR/vhlib/stream/StreamFIFO.vhd                  $TARGET_DIR
file copy -force $FLETCHER_HARDWARE_DIR/vhlib/stream/StreamGearbox.vhd               $TARGET_DIR
file copy -force $FLETCHER_HARDWARE_DIR/vhlib/stream/StreamNormalizer.vhd            $TARGET_DIR
file copy -force $FLETCHER_HARDWARE_DIR/vhlib/stream/StreamGearboxParallelizer.vhd          $TARGET_DIR
file copy -force $FLETCHER_HARDWARE_DIR/vhlib/stream/StreamPipelineControl.vhd       $TARGET_DIR
file copy -force $FLETCHER_HARDWARE_DIR/vhlib/stream/StreamPipelineBarrel.vhd        $TARGET_DIR
file copy -force $FLETCHER_HARDWARE_DIR/vhlib/stream/StreamGearboxSerializer.vhd            $TARGET_DIR
file copy -force $FLETCHER_HARDWARE_DIR/vhlib/stream/StreamSlice.vhd                 $TARGET_DIR
file copy -force $FLETCHER_HARDWARE_DIR/vhlib/stream/StreamSync.vhd                  $TARGET_DIR
file copy -force $FLETCHER_HARDWARE_DIR/vhlib/stream/StreamElementCounter.vhd        $TARGET_DIR
file copy -force $FLETCHER_HARDWARE_DIR/vhlib/stream/StreamPRNG.vhd                  $TARGET_DIR
file copy -force $FLETCHER_HARDWARE_DIR/vhlib/stream/StreamReshaper.vhd              $TARGET_DIR

file copy -force $FLETCHER_HARDWARE_DIR/arrays/ArrayConfigParse_pkg.vhd           $TARGET_DIR
file copy -force $FLETCHER_HARDWARE_DIR/arrays/ArrayConfig_pkg.vhd                $TARGET_DIR
file copy -force $FLETCHER_HARDWARE_DIR/arrays/Array_pkg.vhd                     $TARGET_DIR
file copy -force $FLETCHER_HARDWARE_DIR/arrow/Arrow_pkg.vhd                         $TARGET_DIR

file copy -force $FLETCHER_HARDWARE_DIR/buffers/Buffer_pkg.vhd                     $TARGET_DIR
file copy -force $FLETCHER_HARDWARE_DIR/buffers/BufferReaderCmdGenBusReq.vhd    $TARGET_DIR
file copy -force $FLETCHER_HARDWARE_DIR/buffers/BufferReaderCmd.vhd             $TARGET_DIR
file copy -force $FLETCHER_HARDWARE_DIR/buffers/BufferReaderPost.vhd            $TARGET_DIR
file copy -force $FLETCHER_HARDWARE_DIR/buffers/BufferReaderRespCtrl.vhd        $TARGET_DIR
file copy -force $FLETCHER_HARDWARE_DIR/buffers/BufferReaderResp.vhd            $TARGET_DIR
file copy -force $FLETCHER_HARDWARE_DIR/buffers/BufferReader.vhd                $TARGET_DIR

file copy -force $FLETCHER_HARDWARE_DIR/buffers/BufferWriterCmdGenBusReq.vhd    $TARGET_DIR
file copy -force $FLETCHER_HARDWARE_DIR/buffers/BufferWriterPreCmdGen.vhd       $TARGET_DIR
file copy -force $FLETCHER_HARDWARE_DIR/buffers/BufferWriterPrePadder.vhd       $TARGET_DIR
file copy -force $FLETCHER_HARDWARE_DIR/buffers/BufferWriterPre.vhd             $TARGET_DIR
file copy -force $FLETCHER_HARDWARE_DIR/buffers/BufferWriter.vhd                $TARGET_DIR

file copy -force $FLETCHER_HARDWARE_DIR/interconnect/Interconnect_pkg.vhd           $TARGET_DIR
file copy -force $FLETCHER_HARDWARE_DIR/interconnect/BusReadArbiter.vhd         $TARGET_DIR
file copy -force $FLETCHER_HARDWARE_DIR/interconnect/BusReadArbiterVec.vhd      $TARGET_DIR
file copy -force $FLETCHER_HARDWARE_DIR/interconnect/BusReadBuffer.vhd          $TARGET_DIR
file copy -force $FLETCHER_HARDWARE_DIR/interconnect/BusWriteArbiter.vhd        $TARGET_DIR
file copy -force $FLETCHER_HARDWARE_DIR/interconnect/BusWriteArbiterVec.vhd     $TARGET_DIR
file copy -force $FLETCHER_HARDWARE_DIR/interconnect/BusWriteBuffer.vhd         $TARGET_DIR

file copy -force $FLETCHER_HARDWARE_DIR/arrays/ArrayReaderArb.vhd             $TARGET_DIR
file copy -force $FLETCHER_HARDWARE_DIR/arrays/ArrayReaderLevel.vhd           $TARGET_DIR
file copy -force $FLETCHER_HARDWARE_DIR/arrays/ArrayReaderList.vhd            $TARGET_DIR
file copy -force $FLETCHER_HARDWARE_DIR/arrays/ArrayReaderListPrim.vhd        $TARGET_DIR
file copy -force $FLETCHER_HARDWARE_DIR/arrays/ArrayReaderListSync.vhd        $TARGET_DIR
file copy -force $FLETCHER_HARDWARE_DIR/arrays/ArrayReaderListSyncDecoder.vhd $TARGET_DIR
file copy -force $FLETCHER_HARDWARE_DIR/arrays/ArrayReaderNull.vhd            $TARGET_DIR
file copy -force $FLETCHER_HARDWARE_DIR/arrays/ArrayReaderStruct.vhd          $TARGET_DIR
file copy -force $FLETCHER_HARDWARE_DIR/arrays/ArrayReaderUnlockCombine.vhd   $TARGET_DIR
file copy -force $FLETCHER_HARDWARE_DIR/arrays/ArrayReader.vhd                $TARGET_DIR

file copy -force $FLETCHER_HARDWARE_DIR/arrays/ArrayWriter.vhd                $TARGET_DIR
file copy -force $FLETCHER_HARDWARE_DIR/arrays/ArrayWriterArb.vhd             $TARGET_DIR
file copy -force $FLETCHER_HARDWARE_DIR/arrays/ArrayWriterLevel.vhd           $TARGET_DIR
file copy -force $FLETCHER_HARDWARE_DIR/arrays/ArrayWriterListPrim.vhd        $TARGET_DIR
file copy -force $FLETCHER_HARDWARE_DIR/arrays/ArrayWriterListSync.vhd        $TARGET_DIR

file copy -force $FLETCHER_HARDWARE_DIR/wrapper/Wrapper_pkg.vhd                     $TARGET_DIR
file copy -force $FLETCHER_HARDWARE_DIR/wrapper/UserCoreController.vhd          $TARGET_DIR

file copy -force $FLETCHER_HARDWARE_DIR/axi/Axi_pkg.vhd                             $TARGET_DIR
file copy -force $FLETCHER_HARDWARE_DIR/axi/AxiMmio.vhd                        $TARGET_DIR
file copy -force $FLETCHER_HARDWARE_DIR/axi/AxiReadConverter.vhd              $TARGET_DIR
file copy -force $FLETCHER_HARDWARE_DIR/axi/AxiWriteConverter.vhd             $TARGET_DIR

# Snappy decompressor files:
file copy -force ${PTOA_HARDWARE_DIR}/vhdl/compression/snappy/FPGA-Snappy-Decompressor/hw/source/control.v              $TARGET_DIR
file copy -force ${PTOA_HARDWARE_DIR}/vhdl/compression/snappy/FPGA-Snappy-Decompressor/hw/source/copyread_selector.v    $TARGET_DIR
file copy -force ${PTOA_HARDWARE_DIR}/vhdl/compression/snappy/FPGA-Snappy-Decompressor/hw/source/copytoken_selector.v   $TARGET_DIR
file copy -force ${PTOA_HARDWARE_DIR}/vhdl/compression/snappy/FPGA-Snappy-Decompressor/hw/source/data_out.v             $TARGET_DIR
file copy -force ${PTOA_HARDWARE_DIR}/vhdl/compression/snappy/FPGA-Snappy-Decompressor/hw/source/decompressor.v         $TARGET_DIR
file copy -force ${PTOA_HARDWARE_DIR}/vhdl/compression/snappy/FPGA-Snappy-Decompressor/hw/source/decompressor_wrapper.v $TARGET_DIR
file copy -force ${PTOA_HARDWARE_DIR}/vhdl/compression/snappy/FPGA-Snappy-Decompressor/hw/source/distributor.v          $TARGET_DIR
file copy -force ${PTOA_HARDWARE_DIR}/vhdl/compression/snappy/FPGA-Snappy-Decompressor/hw/source/fifo.v                 $TARGET_DIR
file copy -force ${PTOA_HARDWARE_DIR}/vhdl/compression/snappy/FPGA-Snappy-Decompressor/hw/source/fifo_parser_copy.v     $TARGET_DIR
file copy -force ${PTOA_HARDWARE_DIR}/vhdl/compression/snappy/FPGA-Snappy-Decompressor/hw/source/fifo_parser_lit.v      $TARGET_DIR
file copy -force ${PTOA_HARDWARE_DIR}/vhdl/compression/snappy/FPGA-Snappy-Decompressor/hw/source/io_control.v           $TARGET_DIR
file copy -force ${PTOA_HARDWARE_DIR}/vhdl/compression/snappy/FPGA-Snappy-Decompressor/hw/source/lit_selector.v         $TARGET_DIR
file copy -force ${PTOA_HARDWARE_DIR}/vhdl/compression/snappy/FPGA-Snappy-Decompressor/hw/source/parser.v               $TARGET_DIR
file copy -force ${PTOA_HARDWARE_DIR}/vhdl/compression/snappy/FPGA-Snappy-Decompressor/hw/source/parser_sub.v           $TARGET_DIR
file copy -force ${PTOA_HARDWARE_DIR}/vhdl/compression/snappy/FPGA-Snappy-Decompressor/hw/source/preparser.v            $TARGET_DIR
file copy -force ${PTOA_HARDWARE_DIR}/vhdl/compression/snappy/FPGA-Snappy-Decompressor/hw/source/queue_token.v          $TARGET_DIR
file copy -force ${PTOA_HARDWARE_DIR}/vhdl/compression/snappy/FPGA-Snappy-Decompressor/hw/source/ram_block.v            $TARGET_DIR
file copy -force ${PTOA_HARDWARE_DIR}/vhdl/compression/snappy/FPGA-Snappy-Decompressor/hw/source/ram_module.v           $TARGET_DIR
file copy -force ${PTOA_HARDWARE_DIR}/vhdl/compression/snappy/FPGA-Snappy-Decompressor/hw/source/select.v               $TARGET_DIR

# PTOA specific files
file copy -force ${PTOA_DIR}/examples/prim64/hardware/ptoa_wrapper_plain_snappy.vhd            $TARGET_DIR
file copy -force ${PTOA_HARDWARE_DIR}/vhdl/axi_top.vhd                               $TARGET_DIR

file copy -force ${PTOA_HARDWARE_DIR}/vhdl/thrift/V2MetadataInterpreter.vhd          $TARGET_DIR
file copy -force ${PTOA_HARDWARE_DIR}/vhdl/thrift/Thrift.vhd                         $TARGET_DIR

file copy -force ${PTOA_HARDWARE_DIR}/vhdl/encoding/delta/Delta.vhd                  $TARGET_DIR
file copy -force ${PTOA_HARDWARE_DIR}/vhdl/encoding/delta/AdvanceableFiFo.vhd        $TARGET_DIR
file copy -force ${PTOA_HARDWARE_DIR}/vhdl/encoding/delta/BitUnpackerShifter.vhd     $TARGET_DIR
file copy -force ${PTOA_HARDWARE_DIR}/vhdl/encoding/delta/BitUnpacker.vhd            $TARGET_DIR
file copy -force ${PTOA_HARDWARE_DIR}/vhdl/encoding/delta/BlockValuesAligner.vhd     $TARGET_DIR
file copy -force ${PTOA_HARDWARE_DIR}/vhdl/encoding/delta/BlockHeaderReader.vhd      $TARGET_DIR
file copy -force ${PTOA_HARDWARE_DIR}/vhdl/encoding/delta/BlockShiftControl.vhd      $TARGET_DIR
file copy -force ${PTOA_HARDWARE_DIR}/vhdl/encoding/delta/DeltaAccumulatorFV.vhd     $TARGET_DIR
file copy -force ${PTOA_HARDWARE_DIR}/vhdl/encoding/delta/DeltaAccumulatorMD.vhd     $TARGET_DIR
file copy -force ${PTOA_HARDWARE_DIR}/vhdl/encoding/delta/DeltaAccumulator.vhd       $TARGET_DIR
file copy -force ${PTOA_HARDWARE_DIR}/vhdl/encoding/delta/DeltaHeaderReader.vhd      $TARGET_DIR
file copy -force ${PTOA_HARDWARE_DIR}/vhdl/encoding/delta/DeltaDecoder.vhd           $TARGET_DIR

file copy -force ${PTOA_HARDWARE_DIR}/vhdl/encoding/Encoding.vhd                     $TARGET_DIR
file copy -force ${PTOA_HARDWARE_DIR}/vhdl/encoding/VarIntDecoder.vhd                $TARGET_DIR
file copy -force ${PTOA_HARDWARE_DIR}/vhdl/encoding/DecoderWrapper.vhd               $TARGET_DIR
file copy -force ${PTOA_HARDWARE_DIR}/vhdl/encoding/DecompressorWrapper.vhd          $TARGET_DIR
file copy -force ${PTOA_HARDWARE_DIR}/vhdl/encoding/PlainDecoder.vhd                 $TARGET_DIR
file copy -force ${PTOA_HARDWARE_DIR}/vhdl/encoding/PreDecBuffer.vhd                 $TARGET_DIR
file copy -force ${PTOA_HARDWARE_DIR}/vhdl/encoding/ValBuffer.vhd                    $TARGET_DIR
file copy -force ${PTOA_HARDWARE_DIR}/vhdl/encoding/ValuesDecoder.vhd                $TARGET_DIR

file copy -force ${PTOA_HARDWARE_DIR}/vhdl/alignment/Alignment.vhd                   $TARGET_DIR
file copy -force ${PTOA_HARDWARE_DIR}/vhdl/alignment/DataAligner.vhd                 $TARGET_DIR
file copy -force ${PTOA_HARDWARE_DIR}/vhdl/alignment/HistoryBuffer.vhd               $TARGET_DIR
file copy -force ${PTOA_HARDWARE_DIR}/vhdl/alignment/ShifterRecombiner.vhd           $TARGET_DIR

file copy -force ${PTOA_HARDWARE_DIR}/vhdl/ingestion/Ingester.vhd                    $TARGET_DIR
file copy -force ${PTOA_HARDWARE_DIR}/vhdl/ingestion/Ingestion.vhd                   $TARGET_DIR

file copy -force ${PTOA_HARDWARE_DIR}/vhdl/ingestion/Snappy.vhd                      $TARGET_DIR
file copy -force ${PTOA_HARDWARE_DIR}/vhdl/ingestion/SnappyDecompressor.vhd          $TARGET_DIR

file copy -force ${PTOA_HARDWARE_DIR}/vhdl/ptoa/ParquetReader.vhd                    $TARGET_DIR
file copy -force ${PTOA_HARDWARE_DIR}/vhdl/ptoa/Ptoa.vhd                             $TARGET_DIR
file copy -force ${PTOA_HARDWARE_DIR}/vhdl/ptoa/Ptoa_sim.vhd                         $TARGET_DIR

# AWS EC2 F1 files:
file copy -force $CL_DIR/design/cl_arrow_defines.vh                                  $TARGET_DIR
file copy -force $CL_DIR/design/cl_id_defines.vh                                     $TARGET_DIR
file copy -force $CL_DIR/design/cl_arrow_pkg.sv                                      $TARGET_DIR
file copy -force $CL_DIR/design/cl_arrow.sv                                          $TARGET_DIR

#---- End of section replaced by Developr ---

# Make sure files have write permissions for the encryption

exec chmod +w {*}[glob $TARGET_DIR/*]

set TOOL_VERSION $::env(VIVADO_TOOL_VERSION)
set vivado_version [version -short]
set ver_2017_4 2017.4
puts "AWS FPGA: VIVADO_TOOL_VERSION $TOOL_VERSION"
puts "vivado_version $vivado_version"

# As we open-source everything, we don't care about encrypting the sources and
# skip the encryption step. Re-enable if you want your sources to become
# encrypted in the checkpoints.

# encrypt .v/.sv/.vh/inc as verilog files
# encrypt -k $HDK_SHELL_DIR/build/scripts/vivado_keyfile.txt -lang verilog  [glob -nocomplain -- $TARGET_DIR/*.{v,sv}] [glob -nocomplain -- $TARGET_DIR/*.vh] [glob -nocomplain -- $TARGET_DIR/*.inc]

# encrypt *vhdl files
# encrypt -k $HDK_SHELL_DIR/build/scripts/vivado_vhdl_keyfile.txt -lang vhdl -quiet [ glob -nocomplain -- $TARGET_DIR/*.vhd? ]

