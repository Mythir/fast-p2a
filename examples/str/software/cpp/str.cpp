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
 * Code for running a Parquet to Arrow converter for 32 bit primitives on FPGA.
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


std::shared_ptr<arrow::RecordBatch> prepareRecordBatch(uint32_t num_strings, uint32_t num_chars) {
  std::shared_ptr<arrow::Buffer> values;
  std::shared_ptr<arrow::Buffer> offsets;

  if (!arrow::AllocateBuffer(arrow::default_memory_pool(), num_chars, &values).ok()) {
    throw std::runtime_error("Could not allocate values buffer.");
  }

  if (!arrow::AllocateBuffer(arrow::default_memory_pool(), sizeof(int32_t)*(num_strings+1), &offsets).ok()) {
    throw std::runtime_error("Could not allocate offsets buffer.");
  }

  auto array = std::make_shared<arrow::StringArray>(num_strings, offsets, values);

  auto schema_meta = metaMode(fletcher::Mode::WRITE);

  std::shared_ptr<arrow::Schema> schema = arrow::schema({arrow::field("str", arrow::utf8(), false)}, schema_meta);

  auto rb = arrow::RecordBatch::Make(schema, num_strings, {array});

  return rb;
}

void setPtoaArguments(std::shared_ptr<fletcher::Platform> platform, uint32_t num_val, uint64_t max_size, da_t device_parquet_address, da_t device_arrow_offsets_address, da_t device_arrow_values_address) {
  dau_t mmio64_writer;

  platform->writeMMIO(2, num_val);

  mmio64_writer.full = device_parquet_address;
  platform->writeMMIO(3, mmio64_writer.lo);
  platform->writeMMIO(4, mmio64_writer.hi);
  
  mmio64_writer.full = max_size;
  platform->writeMMIO(5, mmio64_writer.lo);
  platform->writeMMIO(6, mmio64_writer.hi);
  
  mmio64_writer.full = device_arrow_values_address;
  platform->writeMMIO(7, mmio64_writer.lo);
  platform->writeMMIO(8, mmio64_writer.hi);
  
  mmio64_writer.full = device_arrow_offsets_address;
  platform->writeMMIO(9, mmio64_writer.lo);
  platform->writeMMIO(10, mmio64_writer.hi);

  return;
}

//Use standard Arrow library functions to read Arrow array from Parquet file
//Only works for Parquet version 1 style files.
std::shared_ptr<arrow::Array> readArray(std::string hw_input_file_path) {
  std::shared_ptr<arrow::io::ReadableFile> infile;
  arrow::io::ReadableFile::Open(hw_input_file_path, arrow::default_memory_pool(), &infile);
  
  std::unique_ptr<parquet::arrow::FileReader> reader;
  parquet::arrow::OpenFile(infile, arrow::default_memory_pool(), &reader);

  std::shared_ptr<arrow::Array> array;
  reader->ReadColumn(0, &array);

  return array;
}

int main(int argc, char **argv) {

  std::shared_ptr<fletcher::Platform> platform;
  std::shared_ptr<fletcher::Context> context;
  std::shared_ptr<fletcher::UserCore> usercore;

  fletcher::Timer t;

  char* hw_input_file_path;
  char* reference_parquet_file_path;
  uint32_t num_strings;
  uint32_t num_chars;
  uint64_t file_size;
  uint8_t* file_data;

  if (argc > 3) {
    hw_input_file_path = argv[1];
    reference_parquet_file_path = argv[2];
    num_strings = (uint32_t) std::strtoul(argv[3], nullptr, 10);

  } else {
    std::cerr << "Usage: prim32 <parquet_hw_input_file_path> <reference_parquet_file_path> <num_strings>" << std::endl;
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

  //Reference array
  auto correct_array = std::dynamic_pointer_cast<arrow::StringArray>(readArray(std::string(reference_parquet_file_path)));

  // Get total amount of characters from string array for buffer allocation
  num_chars = correct_array->value_offset(num_strings);

  //Get filesize
  parquet_file.seekg (0, parquet_file.end);
  file_size = parquet_file.tellg();
  parquet_file.seekg (0, parquet_file.beg);

  //Read file data
  //file_data = (uint8_t*)std::malloc(file_size);
  posix_memalign((void**)&file_data, 4096, file_size);
  parquet_file.read((char *)file_data, file_size);


  /*************************************************************
  * FPGA RecordBatch preparation
  *************************************************************/

  t.start();
  auto arrow_rb_fpga = prepareRecordBatch(num_strings, num_chars);
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
  setPtoaArguments(platform, num_strings, file_size, device_parquet_address+4, context->device_arrays[0]->buffers[0].device_address, context->device_arrays[0]->buffers[1].device_address);
  t.stop();
  std::cout << "FPGA Initialize                  : "
            << t.seconds() << std::endl;

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
  auto result_array = std::dynamic_pointer_cast<arrow::StringArray>(arrow_rb_fpga->column(0));
  auto result_buffer_raw_offsets = result_array->value_offsets()->mutable_data();
  auto result_buffer_raw_values = result_array->value_data()->mutable_data();

  platform->copyDeviceToHost(context->device_arrays[0]->buffers[0].device_address,
                             result_buffer_raw_offsets,
                             sizeof(int32_t) * (num_strings+1));

  platform->copyDeviceToHost(context->device_arrays[0]->buffers[1].device_address,
                             result_buffer_raw_values,
                             num_chars);
  t.stop();

  size_t total_arrow_size = sizeof(int32_t) * (num_strings+1) + num_chars;

  std::cout << "FPGA device to host copy         : "
            << t.seconds() << std::endl;
  std::cout << "Arrow buffers total size         : "
            << total_arrow_size << std::endl;

  /*************************************************************
  * Check results
  *************************************************************/
  int error_count = 0;
  for(int i=0; i<result_array->length(); i++) {
    if(result_array->GetString(i).compare(correct_array->GetString(i)) != 0) {
      error_count++;
    }

  }

  if(result_array->length() != num_strings){
    error_count++;
  }

  if(error_count == 0) {
    std::cout << "Test passed!" << std::endl;
  } else {
    std::cout << "Test failed. Found " << error_count << " errors in the output Arrow array" << std::endl;
    std::cout << "First values: " << std::endl;

    for(int i=0; i<20; i++) {
      std::cout << result_array->GetString(i) << " " << correct_array->GetString(i) << std::endl;
    }
  }

  std::free(file_data);

  return 0;

}