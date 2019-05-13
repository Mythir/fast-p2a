# Fletcher files

${FLETCHER_HARDWARE_DIR}/utils/Utils.vhd
${FLETCHER_HARDWARE_DIR}/utils/SimUtils.vhd
${FLETCHER_HARDWARE_DIR}/utils/Ram1R1W.vhd

${FLETCHER_HARDWARE_DIR}/buffers/Buffers.vhd
${FLETCHER_HARDWARE_DIR}/interconnect/Interconnect.vhd

${FLETCHER_HARDWARE_DIR}/streams/Streams.vhd
${FLETCHER_HARDWARE_DIR}/streams/StreamArb.vhd
${FLETCHER_HARDWARE_DIR}/streams/StreamBuffer.vhd
${FLETCHER_HARDWARE_DIR}/streams/StreamFIFOCounter.vhd
${FLETCHER_HARDWARE_DIR}/streams/StreamFIFO.vhd
${FLETCHER_HARDWARE_DIR}/streams/StreamGearbox.vhd
${FLETCHER_HARDWARE_DIR}/streams/StreamNormalizer.vhd
${FLETCHER_HARDWARE_DIR}/streams/StreamParallelizer.vhd
${FLETCHER_HARDWARE_DIR}/streams/StreamPipelineBarrel.vhd
${FLETCHER_HARDWARE_DIR}/streams/StreamPipelineControl.vhd
${FLETCHER_HARDWARE_DIR}/streams/StreamSerializer.vhd
${FLETCHER_HARDWARE_DIR}/streams/StreamSlice.vhd
${FLETCHER_HARDWARE_DIR}/streams/StreamSync.vhd
${FLETCHER_HARDWARE_DIR}/streams/StreamElementCounter.vhd
${FLETCHER_HARDWARE_DIR}/streams/StreamReshaper.vhd

${FLETCHER_HARDWARE_DIR}/arrow/Arrow.vhd

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

${FLETCHER_HARDWARE_DIR}/arrays/ArrayConfigParse.vhd
${FLETCHER_HARDWARE_DIR}/arrays/ArrayConfig.vhd
${FLETCHER_HARDWARE_DIR}/arrays/Arrays.vhd
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

${FLETCHER_HARDWARE_DIR}/wrapper/Wrapper.vhd
${FLETCHER_HARDWARE_DIR}/wrapper/UserCoreController.vhd

${FLETCHER_HARDWARE_DIR}/axi/axi.vhd
${FLETCHER_HARDWARE_DIR}/axi/axi_mmio.vhd
${FLETCHER_HARDWARE_DIR}/axi/axi_read_converter.vhd
${FLETCHER_HARDWARE_DIR}/axi/axi_write_converter.vhd

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

${PTOA_HARDWARE_DIR}/vhdl/ptoa_wrapper.vhd
${PTOA_HARDWARE_DIR}/vhdl/axi_top.vhd
