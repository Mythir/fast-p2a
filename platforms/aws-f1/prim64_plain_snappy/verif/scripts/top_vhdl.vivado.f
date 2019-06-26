# Fletcher files

${FLETCHER_HARDWARE_DIR}/vhlib/util/UtilInt_pkg.vhd
${FLETCHER_HARDWARE_DIR}/vhlib/util/UtilMisc_pkg.vhd
${FLETCHER_HARDWARE_DIR}/vhlib/util/UtilRam_pkg.vhd
${FLETCHER_HARDWARE_DIR}/vhlib/util/UtilRam1R1W.vhd
${FLETCHER_HARDWARE_DIR}/vhlib/util/UtilConv_pkg.vhd
${FLETCHER_HARDWARE_DIR}/vhlib/util/UtilStr_pkg.vhd

${FLETCHER_HARDWARE_DIR}/buffers/Buffer_pkg.vhd
${FLETCHER_HARDWARE_DIR}/interconnect/Interconnect_pkg.vhd

${FLETCHER_HARDWARE_DIR}/vhlib/stream/Stream_pkg.vhd
${FLETCHER_HARDWARE_DIR}/vhlib/stream/StreamArb.vhd
${FLETCHER_HARDWARE_DIR}/vhlib/stream/StreamBuffer.vhd
${FLETCHER_HARDWARE_DIR}/vhlib/stream/StreamFIFOCounter.vhd
${FLETCHER_HARDWARE_DIR}/vhlib/stream/StreamFIFO.vhd
${FLETCHER_HARDWARE_DIR}/vhlib/stream/StreamGearbox.vhd
${FLETCHER_HARDWARE_DIR}/vhlib/stream/StreamNormalizer.vhd
${FLETCHER_HARDWARE_DIR}/vhlib/stream/StreamGearboxParallelizer.vhd
${FLETCHER_HARDWARE_DIR}/vhlib/stream/StreamPipelineBarrel.vhd
${FLETCHER_HARDWARE_DIR}/vhlib/stream/StreamPipelineControl.vhd
${FLETCHER_HARDWARE_DIR}/vhlib/stream/StreamGearboxSerializer.vhd
${FLETCHER_HARDWARE_DIR}/vhlib/stream/StreamSlice.vhd
${FLETCHER_HARDWARE_DIR}/vhlib/stream/StreamSync.vhd
${FLETCHER_HARDWARE_DIR}/vhlib/stream/StreamElementCounter.vhd
${FLETCHER_HARDWARE_DIR}/vhlib/stream/StreamReshaper.vhd

${FLETCHER_HARDWARE_DIR}/arrow/Arrow_pkg.vhd

${FLETCHER_HARDWARE_DIR}/buffers/BufferReaderCmdGenBusReq.vhd
${FLETCHER_HARDWARE_DIR}/buffers/BufferReaderCmd.vhd
${FLETCHER_HARDWARE_DIR}/buffers/BufferReaderPost.vhd
${FLETCHER_HARDWARE_DIR}/buffers/BufferReaderRespCtrl.vhd
${FLETCHER_HARDWARE_DIR}/buffers/BufferReaderResp.vhd
${FLETCHER_HARDWARE_DIR}/buffers/BufferReader.vhd
${FLETCHER_HARDWARE_DIR}/buffers/BufferWriterCmdGenBusReq.vhd
${FLETCHER_HARDWARE_DIR}/buffers/BufferWriterPreCmdGen.vhd
${FLETCHER_HARDWARE_DIR}/buffers/BufferWriterPrePadder.vhd
${FLETCHER_HARDWARE_DIR}/buffers/BufferWriterPre.vhd
${FLETCHER_HARDWARE_DIR}/buffers/BufferWriter.vhd

${FLETCHER_HARDWARE_DIR}/interconnect/BusReadArbiter.vhd
${FLETCHER_HARDWARE_DIR}/interconnect/BusReadArbiterVec.vhd
${FLETCHER_HARDWARE_DIR}/interconnect/BusReadBuffer.vhd
${FLETCHER_HARDWARE_DIR}/interconnect/BusWriteArbiter.vhd
${FLETCHER_HARDWARE_DIR}/interconnect/BusWriteArbiterVec.vhd
${FLETCHER_HARDWARE_DIR}/interconnect/BusWriteBuffer.vhd

${FLETCHER_HARDWARE_DIR}/arrays/ArrayConfigParse_pkg.vhd
${FLETCHER_HARDWARE_DIR}/arrays/ArrayConfig_pkg.vhd
${FLETCHER_HARDWARE_DIR}/arrays/Array_pkg.vhd
${FLETCHER_HARDWARE_DIR}/arrays/ArrayReaderArb.vhd
${FLETCHER_HARDWARE_DIR}/arrays/ArrayReaderLevel.vhd
${FLETCHER_HARDWARE_DIR}/arrays/ArrayReaderListPrim.vhd
${FLETCHER_HARDWARE_DIR}/arrays/ArrayReaderListSyncDecoder.vhd
${FLETCHER_HARDWARE_DIR}/arrays/ArrayReaderListSync.vhd
${FLETCHER_HARDWARE_DIR}/arrays/ArrayReaderList.vhd
${FLETCHER_HARDWARE_DIR}/arrays/ArrayReaderNull.vhd
${FLETCHER_HARDWARE_DIR}/arrays/ArrayReaderStruct.vhd
${FLETCHER_HARDWARE_DIR}/arrays/ArrayReaderUnlockCombine.vhd
${FLETCHER_HARDWARE_DIR}/arrays/ArrayReader.vhd
${FLETCHER_HARDWARE_DIR}/arrays/ArrayWriterArb.vhd
${FLETCHER_HARDWARE_DIR}/arrays/ArrayWriterLevel.vhd
${FLETCHER_HARDWARE_DIR}/arrays/ArrayWriterListPrim.vhd
${FLETCHER_HARDWARE_DIR}/arrays/ArrayWriterListSync.vhd
${FLETCHER_HARDWARE_DIR}/arrays/ArrayWriter.vhd

${FLETCHER_HARDWARE_DIR}/wrapper/Wrapper_pkg.vhd
${FLETCHER_HARDWARE_DIR}/wrapper/UserCoreController.vhd

${FLETCHER_HARDWARE_DIR}/axi/Axi_pkg.vhd          
${FLETCHER_HARDWARE_DIR}/axi/AxiMmio.vhd          
${FLETCHER_HARDWARE_DIR}/axi/AxiReadConverter.vhd 
${FLETCHER_HARDWARE_DIR}/axi/AxiWriteConverter.vhd

# PTOA files

${PTOA_HARDWARE_DIR}/vhdl/ptoa/Ptoa.vhd
${PTOA_HARDWARE_DIR}/vhdl/encoding/Encoding.vhd

${PTOA_HARDWARE_DIR}/vhdl/encoding/delta/Delta.vhd
${PTOA_HARDWARE_DIR}/vhdl/encoding/delta/AdvanceableFiFo.vhd
${PTOA_HARDWARE_DIR}/vhdl/encoding/delta/BitUnpackerShifter.vhd
${PTOA_HARDWARE_DIR}/vhdl/encoding/delta/BitUnpacker.vhd
${PTOA_HARDWARE_DIR}/vhdl/encoding/delta/BlockValuesAligner.vhd
${PTOA_HARDWARE_DIR}/vhdl/encoding/delta/BlockHeaderReader.vhd
${PTOA_HARDWARE_DIR}/vhdl/encoding/delta/BlockShiftControl.vhd
${PTOA_HARDWARE_DIR}/vhdl/encoding/delta/DeltaAccumulatorFV.vhd
${PTOA_HARDWARE_DIR}/vhdl/encoding/delta/DeltaAccumulatorMD.vhd
${PTOA_HARDWARE_DIR}/vhdl/encoding/delta/DeltaAccumulator.vhd
${PTOA_HARDWARE_DIR}/vhdl/encoding/delta/DeltaHeaderReader.vhd
${PTOA_HARDWARE_DIR}/vhdl/encoding/delta/DeltaDecoder.vhd

${PTOA_HARDWARE_DIR}/vhdl/encoding/VarIntDecoder.vhd
${PTOA_HARDWARE_DIR}/vhdl/encoding/DecoderWrapper.vhd
${PTOA_HARDWARE_DIR}/vhdl/encoding/DecompressorWrapper.vhd
${PTOA_HARDWARE_DIR}/vhdl/encoding/PreDecBuffer.vhd
${PTOA_HARDWARE_DIR}/vhdl/encoding/ValBuffer.vhd
${PTOA_HARDWARE_DIR}/vhdl/encoding/PlainDecoder.vhd
${PTOA_HARDWARE_DIR}/vhdl/encoding/ValuesDecoder.vhd

${PTOA_HARDWARE_DIR}/vhdl/thrift/Thrift.vhd
${PTOA_HARDWARE_DIR}/vhdl/thrift/V2MetadataInterpreter.vhd

${PTOA_HARDWARE_DIR}/vhdl/alignment/Alignment.vhd
${PTOA_HARDWARE_DIR}/vhdl/alignment/DataAligner.vhd
${PTOA_HARDWARE_DIR}/vhdl/alignment/HistoryBuffer.vhd
${PTOA_HARDWARE_DIR}/vhdl/alignment/ShifterRecombiner.vhd

${PTOA_HARDWARE_DIR}/vhdl/ingestion/Ingestion.vhd
${PTOA_HARDWARE_DIR}/vhdl/ingestion/Ingester.vhd

${PTOA_HARDWARE_DIR}/vhdl/ptoa/ParquetReader.vhd

${PTOA_HARDWARE_DIR}/vhdl/compression/snappy/Snappy.vhd
${PTOA_HARDWARE_DIR}/vhdl/compression/snappy/SnappyDecompressor.vhd

${PTOA_DIR}/examples/prim64/hardware/ptoa_wrapper_plain_snappy.vhd
${PTOA_HARDWARE_DIR}/vhdl/axi_top.vhd


