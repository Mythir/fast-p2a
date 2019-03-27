// Licensed to the Apache Software Foundation (ASF) under one
// or more contributor license agreements. See the NOTICE file
// distributed with this work for additional information
// regarding copyright ownership. The ASF licenses this file
// to you under the Apache License, Version 2.0 (the
// "License"); you may not use this file except in compliance
// with the License. You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing,
// software distributed under the License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied. See the License for the
// specific language governing permissions and limitations
// under the License.

/*
 * Author: Lars van Leeuwen
 * Code for running a Parquet to Arrow converter for 64 bit primitives on FPGA.
 *
 * Inputs:
 *  parquet_hw_input_file_path: file_path to hardware compatible Parquet file
 *  reference_parquet_file_path: file_path to Parquet file compatible with the standard Arrow library Parquet reading functions. 
 *    This file should contain the same values as the first file and is used for verifying the hardware output.
 *  num_val: How many values to read.
 */

#include <chrono>
#include <memory>
#include <vector>
#include <iostream>
#include <fstream>
#include <iomanip>
#include <random>
#include <stdlib.h>
#include <unistd.h>

// Apache Arrow
#include <arrow/api.h>
#include <arrow/io/api.h>
#include <parquet/arrow/reader.h>

// Fletcher
#include "fletcher/api.h"

#define PRIM_WIDTH 64

std::shared_ptr<arrow::RecordBatch> prepareRecordBatch(uint32_t num_val) {
  std::shared_ptr<arrow::Buffer> values;

  if (!arrow::AllocateBuffer(arrow::default_memory_pool(), sizeof(int64_t)*num_val, &values).ok()) {
    throw std::runtime_error("Could not allocate values buffer.");
  }

  auto array = std::make_shared<arrow::Int64Array>(arrow::int64(), num_val, values);

  std::shared_ptr<arrow::Schema> schema = arrow::schema({arrow::field("int", arrow::int64(), false)});

  auto rb = arrow::RecordBatch::Make(schema, num_val, {array});

  return rb;
}

void setPtoaArguments(std::shared_ptr<fletcher::Platform> platform, uint32_t num_val, uint64_t max_size, da_t device_parquet_address, da_t device_arrow_address) {
  dau_t mmio64_writer;

  platform->writeMMIO(2, num_val);

  mmio64_writer.full = device_parquet_address;
  platform->writeMMIO(3, mmio64_writer.lo);
  platform->writeMMIO(4, mmio64_writer.hi);
  
  mmio64_writer.full = max_size;
  platform->writeMMIO(5, mmio64_writer.lo);
  platform->writeMMIO(6, mmio64_writer.hi);
  
  mmio64_writer.full = device_arrow_address;
  platform->writeMMIO(7, mmio64_writer.lo);
  platform->writeMMIO(8, mmio64_writer.hi);

  return;
}

void checkMMIO(std::shared_ptr<fletcher::Platform> platform, uint32_t num_val, uint64_t max_size, da_t device_parquet_address, da_t device_arrow_address) {
  uint64_t value64;
  uint32_t value32;

  platform->readMMIO(2, &value32);

  std::cout << "MMIO num_val=" << value32 << ", should be " << num_val << std::endl;

  platform->readMMIO64(3, &value64);

  std::cout << "MMIO dpa=" << value64 << ", should be " << device_parquet_address << std::endl;

  platform->readMMIO64(5, &value64);

  std::cout << "MMIO max_size=" << value64 << ", should be " << max_size << std::endl;

  platform->readMMIO64(7, &value64);

  std::cout << "MMIO daa=" << value64 << ", should be " << device_arrow_address << std::endl;

}

//Use standard Arrow library functions to read Arrow array from Parquet file
//Only works for Parquet version 1 style files.
std::shared_ptr<arrow::Array> readArray(std::string hw_input_file_path) {
  std::shared_ptr<arrow::io::ReadableFile> infile;
  PARQUET_THROW_NOT_OK(arrow::io::ReadableFile::Open(hw_input_file_path, arrow::default_memory_pool(), &infile));
  
  std::unique_ptr<parquet::arrow::FileReader> reader;
  PARQUET_THROW_NOT_OK(parquet::arrow::OpenFile(infile, arrow::default_memory_pool(), &reader));

  std::shared_ptr<arrow::Array> array;
  PARQUET_THROW_NOT_OK(reader->ReadColumn(0, &array));

  return array;
}

int main(int argc, char **argv) {

  std::shared_ptr<fletcher::Platform> platform;
  std::shared_ptr<fletcher::Context> context;
  std::shared_ptr<fletcher::UserCore> usercore;

  fletcher::Timer t;

  char* hw_input_file_path;
  char* reference_parquet_file_path;
  uint32_t num_val;
  uint64_t file_size;
  uint8_t* file_data;

  if (argc > 3) {
    hw_input_file_path = argv[1];
    reference_parquet_file_path = argv[2];
    num_val = (uint32_t) std::strtoul(argv[3], nullptr, 10);

  } else {
    std::cerr << "Usage: prim64 <parquet_hw_input_file_path> <reference_parquet_file_path> <num_values>" << std::endl;
    return 1;
  }

  /*************************************************************
  * Parquet file reading
  *************************************************************/

  //Open parquet file
  std::ifstream parquet_file;
  parquet_file.open(hw_input_file_path, std::ifstream::binary);

  if(!parquet_file.is_open()) {
    std::cerr << "Error opening Parquet file" << std::endl;
    return 1;
  }

  //Get filesize
  parquet_file.seekg (0, parquet_file.end);
  file_size = parquet_file.tellg();
  parquet_file.seekg (0, parquet_file.beg);

  //Read file data
  file_data = (uint8_t*)std::malloc(file_size);
  parquet_file.read((char *)file_data, file_size);


  /*************************************************************
  * FPGA RecordBatch preparation
  *************************************************************/

  t.start();
  auto arrow_rb_fpga = prepareRecordBatch(num_val);
  t.stop();
  std::cout << "Prepare FPGA RecordBatch         : "
            << t.seconds() << std::endl;

  /*************************************************************
  * FPGA Initilialization
  *************************************************************/

  t.start();
  // Create and intitialize platform
  fletcher::Platform::Make(&platform).ewf("Could not create platform.");
  platform->init();

  //Create context
  fletcher::Context::Make(&context, platform);

  //Create usercore and reset CL
  usercore = std::make_shared<fletcher::UserCore>(context);
  usercore->reset();

  //Setup destination recordbatch on device
  context->queueRecordBatch(arrow_rb_fpga);
  context->enable();

  //Malloc parquet file on device
  da_t device_parquet_address;
  platform->deviceMalloc(&device_parquet_address, file_size);

  // Set all the MMIO registers to their correct value
  // Add 4 to device_parquet_address to skip magic number
  setPtoaArguments(platform, num_val, file_size, device_parquet_address+4, context->device_arrays[0]->buffers[0].device_address);
  t.stop();
  std::cout << "FPGA Initialize                  : "
            << t.seconds() << std::endl;

  checkMMIO(platform, num_val, file_size, device_parquet_address, context->device_arrays[0]->buffers[0].device_address);

  /*************************************************************
  * FPGA host to device copy
  *************************************************************/

  t.start();
  platform->copyHostToDevice(file_data, device_parquet_address, file_size);
  t.stop();
  std::cout << "FPGA host to device copy         : "
            << t.seconds() << std::endl;

  /*************************************************************
  * FPGA processing
  *************************************************************/

  t.start();
  usercore->start();
  usercore->waitForFinish(100);
  t.stop();
  std::cout << "FPGA processing time             : "
            << t.seconds() << std::endl;

  /*************************************************************
  * FPGA device to host copy
  *************************************************************/

  t.start();
  auto result_array = std::dynamic_pointer_cast<arrow::Int64Array>(arrow_rb_fpga->column(0));
  auto result_buffer_raw_data = result_array->values()->mutable_data();
  platform->copyDeviceToHost(context->device_arrays[0]->buffers[0].device_address,
                             result_buffer_raw_data,
                             sizeof(int64_t) * (num_val));
  t.stop();
  std::cout << "FPGA device to host copy         : "
            << t.seconds() << std::endl;

  /*************************************************************
  * Check results
  *************************************************************/

  auto correct_array = std::dynamic_pointer_cast<arrow::Int64Array>(readArray(std::string(reference_parquet_file_path)));
  int error_count = 0;
  for(int i=0; i<result_array->length(); i++) {
    if(result_array->Value(i) != correct_array->Value(i)) {
      error_count++;
    }
    if(i<20) {
      std::cout << result_array->Value(i) << " " << correct_array->Value(i) << std::endl;
    }

  }

  if(error_count == 0) {
    std::cout << "Test passed!" << std::endl;
  } else {
    std::cout << "Test failed. Found " << error_count << " errors in the output Arrow array" << std::endl;
  }

  std::free(file_data);

  return 0;

}